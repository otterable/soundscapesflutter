import os
import shutil
import logging
import random
import string
from datetime import datetime, timedelta
from urllib.parse import quote, urlsplit

from flask import Flask, jsonify, send_from_directory, request, abort
from flask_cors import CORS
from werkzeug.utils import secure_filename
from itsdangerous import URLSafeTimedSerializer, BadSignature, SignatureExpired

# Optional: load .env if present
try:
    from dotenv import load_dotenv  # type: ignore
    load_dotenv()
except Exception:
    pass

# ---- Configuration ----
ADMIN_PASSWORD = os.environ.get("ADMIN_PASSWORD", "change-me-now")
ADMIN_E164 = os.environ.get("ADMIN_E164", "+436703596614")  # only allowed admin phone

# Twilio flags
TWILIO_ENABLED = os.environ.get("TWILIO_ENABLED", "1") == "1"
TWILIO_STRICT = os.environ.get("TWILIO_STRICT", "1") == "1"  # if true, disable password login
DEV_SHOW_CODE = os.environ.get("DEV_SHOW_CODE", "0") == "1"

TWILIO_ACCOUNT_SID = os.environ.get("TWILIO_ACCOUNT_SID", "")
TWILIO_AUTH_TOKEN = os.environ.get("TWILIO_AUTH_TOKEN", "")
TWILIO_PHONE_NUMBER = os.environ.get("TWILIO_PHONE_NUMBER", "")

ADMIN_TOKEN_SECRET = os.environ.get("ADMIN_TOKEN_SECRET", "changeme-secret")
TOKEN_TTL_SECONDS = int(os.environ.get("TOKEN_TTL_SECONDS", str(24 * 3600)))
EXTERNAL_BASE_URL = os.environ.get("EXTERNAL_BASE_URL", "").strip().rstrip("/")
ALLOWED_EXTS = {".mp3", ".wav"}

# OTP settings
OTP_TTL_SECONDS = int(os.environ.get("OTP_TTL_SECONDS", "600"))  # 10 minutes

# ---- Logging ----
gunicorn_logger = logging.getLogger("gunicorn.error")
if gunicorn_logger.handlers:
    logging.basicConfig(handlers=gunicorn_logger.handlers, level=gunicorn_logger.level)
else:
    logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("soundscapes")
logger.setLevel(logging.INFO)

# Twilio client (lazy)
_twilio_client = None
if TWILIO_ENABLED:
    try:
        from twilio.rest import Client  # type: ignore
        _twilio_client = Client(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)
        logger.info("Twilio enabled: True | strict=%s | from=%s", TWILIO_STRICT, TWILIO_PHONE_NUMBER)
    except Exception as e:
        logger.error("Failed to initialize Twilio client: %s", e)
        TWILIO_ENABLED = False

app = Flask(__name__, static_url_path="/static", static_folder="static")
# CORS (explicitly allow Authorization for admin routes)
CORS(
    app,
    resources={
        r"/api/*": {
            "origins": "*",
            "allow_headers": ["Authorization", "Content-Type"],
            "methods": ["GET", "POST", "OPTIONS"],
        },
        r"/static/*": {"origins": "*"},
    },
)
serializer = URLSafeTimedSerializer(ADMIN_TOKEN_SECRET, salt="admin-login")

# In-memory OTP store: { phone: {"code": "123456", "exp": datetime} }
OTP_STORE = {}

def _soundscapes_root() -> str:
    root = os.path.join(app.static_folder, "soundscapes")
    os.makedirs(root, exist_ok=True)
    return root

def _is_audio(fname: str) -> bool:
    f = fname.lower()
    return f.endswith(".mp3") or f.endswith(".wav")

def _client_ip() -> str:
    fwd = request.headers.get("X-Forwarded-For", "")
    if fwd:
        return fwd.split(",")[0].strip()
    return request.remote_addr or "-"

def _base_url() -> str:
    """
    Build an absolute base URL for static file links.
    If EXTERNAL_BASE_URL is set, keep its host:port but force the scheme to match the current request
    (prevents HTTPS ClientHello on an HTTP-only port).
    Otherwise, honor proxy headers or fall back to request scheme/host.
    """
    req_scheme = request.headers.get("X-Forwarded-Proto") or request.scheme
    if EXTERNAL_BASE_URL:
        try:
            parsed = urlsplit(EXTERNAL_BASE_URL)
            hostport = parsed.netloc or (request.headers.get("X-Forwarded-Host") or request.host)
            url = f"{req_scheme}://{hostport}"
            if parsed.scheme != req_scheme:
                logger.info("BASE_URL: forcing scheme %s for %s", req_scheme, EXTERNAL_BASE_URL)
            return url
        except Exception as e:
            logger.warning("BASE_URL parse failed (%s), falling back: %s", EXTERNAL_BASE_URL, e)
    host = request.headers.get("X-Forwarded-Host") or request.host
    return f"{req_scheme}://{host}"

def _url_for_file(category: str, filename: str) -> str:
    # URL-encode pieces for safety (spaces, UTF-8, etc.)
    return f"{_base_url()}/static/soundscapes/{quote(category)}/{quote(filename)}"

def _ensure_category_dir(cat: str) -> str:
    base = _soundscapes_root()
    path = os.path.join(base, cat)
    os.makedirs(path, exist_ok=True)
    return path

def _ext_of(name: str) -> str:
    return os.path.splitext(name)[1].lower()

@app.before_request
def _log_connect():
    logger.info(
        "CONNECT | ip=%s | %s %s | ua=%s | referer=%s",
        _client_ip(),
        request.method,
        request.path,
        request.headers.get("User-Agent", "-"),
        request.headers.get("Referer", "-"),
    )

@app.after_request
def _nocache(resp):
    # prevent stale dev caches
    resp.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
    resp.headers["Pragma"] = "no-cache"
    # Make streaming friendlier for audio across origins
    resp.headers.setdefault("Access-Control-Expose-Headers", "Content-Length, Content-Range, Accept-Ranges")
    if request.path.startswith("/static/"):
        resp.headers.setdefault("Accept-Ranges", "bytes")
    logger.info(
        "RESPONSE | ip=%s | %s %s | status=%s | length=%s",
        _client_ip(),
        request.method,
        request.path,
        resp.status_code,
        resp.calculate_content_length(),
    )
    return resp

# ---- Root + Health ----
@app.route("/")
def root():
    return jsonify({
        "ok": True,
        "service": "soundscapes-backend",
        "time": datetime.utcnow().isoformat() + "Z",
        "twilio_enabled": TWILIO_ENABLED,
        "docs": "/api/health, /api/soundscapes, /api/admin/*"
    })

@app.route("/api/health")
def health():
    return jsonify({"ok": True, "time": datetime.utcnow().isoformat() + "Z"})

# ---- Public API ----
@app.route("/api/soundscapes")
def api_soundscapes():
    base = _soundscapes_root()
    cats = []
    total_files = 0
    if os.path.isdir(base):
        for folder in sorted(os.listdir(base)):
            cat_path = os.path.join(base, folder)
            if os.path.isdir(cat_path):
                files = [
                    {"name": f, "url": _url_for_file(folder, f)}
                    for f in sorted(os.listdir(cat_path))
                    if _is_audio(f)
                ]
                total_files += len(files)
                cats.append({"name": folder, "files": files})
    empty = len(cats) == 0
    if empty:
        logger.info("No soundscapes found on server")
    else:
        logger.info("SOUNDSCAPES | cats=%d | files=%d", len(cats), total_files)
    payload = {"categories": cats, "empty": empty}
    if empty:
        payload["message"] = "No soundscapes on the server. Admins: create a category and upload files."
    return jsonify(payload)

@app.route("/static/<path:filename>")
def static_file(filename):
    # conditional=True enables Range requests (partial content) in Werkzeug
    return send_from_directory(app.static_folder, filename, conditional=True)

# ---- Admin Auth (Twilio OTP) ----
def _clean_phone(p: str) -> str:
    return p.strip().replace(" ", "")

def _generate_code() -> str:
    return ''.join(random.choices(string.digits, k=6))

@app.route("/api/admin/login_start", methods=["POST"])
def admin_login_start():
    data = request.get_json(silent=True) or {}
    phone = _clean_phone(str(data.get("phone", "")))
    if not phone:
        abort(400, description="Missing phone")
    if phone != ADMIN_E164:
        logger.warning("OTP start rejected for phone=%s (not allowed)", phone)
        abort(401, description="Unauthorized phone")
    code = _generate_code()
    exp = datetime.utcnow() + timedelta(seconds=OTP_TTL_SECONDS)
    OTP_STORE[phone] = {"code": code, "exp": exp}
    logger.info("OTP generated for %s exp=%s", phone, exp.isoformat() + "Z")
    if TWILIO_ENABLED and _twilio_client is not None and TWILIO_PHONE_NUMBER:
        try:
            _twilio_client.messages.create(
                to=phone,
                from_=TWILIO_PHONE_NUMBER,
                body=f"Ermine Soundscapes admin code: {code} (valid {OTP_TTL_SECONDS//60} min)"
            )
            logger.info("OTP sent via Twilio to %s", phone)
        except Exception as e:
            logger.error("Twilio send failed: %s", e)
            abort(500, description="Failed to send OTP")
    else:
        logger.warning("Twilio disabled or not configured; OTP not sent")
    resp = {"ok": True}
    if DEV_SHOW_CODE:
        resp["dev_code"] = code
    return jsonify(resp)

@app.route("/api/admin/login_verify", methods=["POST"])
def admin_login_verify():
    data = request.get_json(silent=True) or {}
    phone = _clean_phone(str(data.get("phone", "")))
    code = str(data.get("code", "")).strip()
    rec = OTP_STORE.get(phone)
    if not phone or not code or rec is None:
        abort(401, description="Invalid phone or code")
    if datetime.utcnow() > rec["exp"]:
        del OTP_STORE[phone]
        abort(401, description="Code expired")
    if code != rec["code"]:
        abort(401, description="Invalid code")
    del OTP_STORE[phone]
    token = serializer.dumps({"role": "admin", "phone": phone})
    logger.info("Admin token issued for %s", phone)
    return jsonify({"token": token})

# ---- Legacy password login (disabled if TWILIO_STRICT) ----
@app.route("/api/admin/login", methods=["POST"])
def admin_login_legacy():
    if TWILIO_STRICT:
        abort(403, description="Password login disabled; use SMS OTP")
    data = request.get_json(silent=True) or {}
    password = data.get("password", "")
    if not password or password != ADMIN_PASSWORD:
        abort(401, description="Invalid credentials")
    token = serializer.dumps({"role": "admin"})
    logger.info("Legacy admin token issued")
    return jsonify({"token": token})

def _require_admin():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        abort(401, description="Missing token")
    token = auth.removeprefix("Bearer ").strip()
    try:
        serializer.loads(token, max_age=TOKEN_TTL_SECONDS)
    except SignatureExpired:
        abort(401, description="Token expired")
    except BadSignature:
        abort(401, description="Invalid token")

# ---- Admin: Categories (folders) ----
@app.route("/api/admin/create_category", methods=["POST"])
def create_category():
    _require_admin()
    data = request.get_json(silent=True) or {}
    name = str(data.get("name", "")).strip()
    if not name:
        abort(400, description="Missing category name")
    path = _ensure_category_dir(name)
    if not os.path.isdir(path):
        abort(500, description="Failed to create category")
    logger.info("CATEGORY CREATE | name=%s | path=%s", name, path)
    return jsonify({"ok": True})

@app.route("/api/admin/rename_category", methods=["POST"])
def rename_category():
    _require_admin()
    data = request.get_json(silent=True) or {}
    old_name = str(data.get("old_name", "")).strip()
    new_name = str(data.get("new_name", "")).strip()
    if not old_name or not new_name:
        abort(400, description="Missing names")
    base = _soundscapes_root()
    src = os.path.join(base, old_name)
    dst = os.path.join(base, new_name)
    if not os.path.isdir(src):
        abort(404, description="Source category not found")
    if os.path.exists(dst):
        abort(409, description="Target category exists")
    os.rename(src, dst)
    logger.info("CATEGORY RENAME | %s -> %s", old_name, new_name)
    return jsonify({"ok": True})

@app.route("/api/admin/delete_category", methods=["POST"])
def delete_category():
    _require_admin()
    data = request.get_json(silent=True) or {}
    name = str(data.get("name", "")).strip()
    force = bool(data.get("force", False))
    if not name:
        abort(400, description="Missing category name")
    base = _soundscapes_root()
    path = os.path.join(base, name)
    if not os.path.isdir(path):
        abort(404, description="Category not found")
    if force:
        shutil.rmtree(path)
        logger.info("CATEGORY DELETE (force) | %s", name)
    else:
        if os.listdir(path):
            abort(409, description="Category not empty")
        os.rmdir(path)
        logger.info("CATEGORY DELETE | %s", name)
    return jsonify({"ok": True})

# ---- Admin: Files ----
@app.route("/api/admin/upload", methods=["POST"])
def admin_upload():
    _require_admin()
    category = request.form.get("category", "").strip()
    if not category:
        abort(400, description="Missing category")
    _ensure_category_dir(category)
    if "file" not in request.files:
        abort(400, description="Missing file")
    file = request.files["file"]
    if file.filename == "":
        abort(400, description="Empty filename")
    filename = secure_filename(file.filename)
    ext = _ext_of(filename)
    if ext not in ALLOWED_EXTS:
        abort(400, description="Unsupported extension")
    save_path = os.path.join(_soundscapes_root(), category, filename)
    file.save(save_path)
    logger.info("FILE UPLOAD | cat=%s | name=%s | path=%s", category, filename, save_path)
    return jsonify({"ok": True, "filename": filename})

@app.route("/api/admin/rename_file", methods=["POST"])
def admin_rename_file():
    _require_admin()
    data = request.get_json(silent=True) or {}
    category = str(data.get("category", "")).strip()
    old_name = str(data.get("old_name", "")).strip()
    new_name = secure_filename(str(data.get("new_name", "")).strip())
    if not category or not old_name or not new_name:
        abort(400, description="Missing fields")
    if _ext_of(new_name) not in ALLOWED_EXTS:
        abort(400, description="Unsupported extension for new name")
    base = os.path.join(_soundscapes_root(), category)
    src = os.path.join(base, old_name)
    dst = os.path.join(base, new_name)
    if not os.path.isfile(src):
        abort(404, description="File not found")
    if os.path.exists(dst):
        abort(409, description="Target filename exists")
    os.rename(src, dst)
    logger.info("FILE RENAME | cat=%s | %s -> %s", category, old_name, new_name)
    return jsonify({"ok": True})

@app.route("/api/admin/move_file", methods=["POST"])
def admin_move_file():
    _require_admin()
    data = request.get_json(silent=True) or {}
    old_category = str(data.get("old_category", "")).strip()
    filename = str(data.get("filename", "")).strip()
    new_category = str(data.get("new_category", "")).strip()
    if not old_category or not filename or not new_category:
        abort(400, description="Missing fields")
    src_dir = os.path.join(_soundscapes_root(), old_category)
    dst_dir = _ensure_category_dir(new_category)
    src = os.path.join(src_dir, filename)
    dst = os.path.join(dst_dir, filename)
    if not os.path.isfile(src):
        abort(404, description="Source file not found")
    if os.path.exists(dst):
        abort(409, description="File already exists in destination")
    os.rename(src, dst)
    logger.info("FILE MOVE | %s/%s -> %s/%s", old_category, filename, new_category, filename)
    return jsonify({"ok": True})

@app.route("/api/admin/delete_file", methods=["POST"])
def admin_delete_file():
    _require_admin()
    data = request.get_json(silent=True) or {}
    category = str(data.get("category", "")).strip()
    filename = str(data.get("filename", "")).strip()
    if not category or not filename:
        abort(400, description="Missing fields")
    path = os.path.join(_soundscapes_root(), category, filename)
    if not os.path.isfile(path):
        abort(404, description="File not found")
    os.remove(path)
    logger.info("FILE DELETE | cat=%s | name=%s | path=%s", category, filename, path)
    return jsonify({"ok": True})

# ---- JSON error responses ----
@app.errorhandler(400)
@app.errorhandler(401)
@app.errorhandler(404)
@app.errorhandler(409)
@app.errorhandler(500)
def _json_errors(err):
    code = getattr(err, "code", 500)
    msg = getattr(err, "description", str(err))
    logger.warning("ERROR | status=%s | %s %s | msg=%s", code, request.method, request.path, msg)
    return jsonify({"ok": False, "error": msg, "status": code}), code

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8083"))
    logger.info(
        "Starting Soundscapes backend on port %s | admin phone=%s | twilio_enabled=%s strict=%s",
        port, ADMIN_E164, TWILIO_ENABLED, TWILIO_STRICT
    )
    app.run(host="0.0.0.0", port=port, debug=True, threaded=True)
