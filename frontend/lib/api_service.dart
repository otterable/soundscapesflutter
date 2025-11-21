import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class SoundFile {
  final String name;
  final String url;

  SoundFile({required this.name, required this.url});

  factory SoundFile.fromJson(Map<String, dynamic> json) {
    return SoundFile(
      name: json['name'] as String,
      url: json['url'] as String,
    );
  }
}

class SoundCategory {
  final String name;
  final List<SoundFile> files;

  SoundCategory({required this.name, required this.files});

  factory SoundCategory.fromJson(Map<String, dynamic> json) {
    final filesJson = (json['files'] as List<dynamic>? ?? []);
    return SoundCategory(
      name: json['name'] as String,
      files:
          filesJson.map((e) => SoundFile.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ApiService {
  /// Original value you pass in (kept for reference).
  final String baseUrl;

  /// Normalized base (always absolute, with scheme, no trailing slash).
  final String _base;

  String? _token; // Admin Bearer token

  ApiService({required this.baseUrl}) : _base = _normalizeBase(baseUrl);

  static String _normalizeBase(String input) {
    var s = input.trim();
    if (s.isEmpty) return "";
    final lower = s.toLowerCase();
    if (!lower.startsWith("http://") && !lower.startsWith("https://")) {
      // Default to HTTP here because your backend is HTTP-only (port 8083).
      s = "http://$s";
    }
    if (s.endsWith("/")) s = s.substring(0, s.length - 1);
    return s;
  }

  /// Build absolute URL for any asset on the backend (e.g., /static/logo.png).
  String asset(String path) {
    final p = path.startsWith("/") ? path : "/$path";
    return "$_base$p";
  }

  /// Build the URL for an audio file in a given category.
  /// Used so the admin UI can update URLs instantly after renames/moves.
  String buildFileUrl(String category, String filename) {
    final cat = Uri.encodeComponent(category);
    final file = Uri.encodeComponent(filename);
    return "$_base/static/soundscapes/$cat/$file";
  }

  void setAuthToken(String? token) {
    _token = token;
  }

  bool get isAuthed => _token != null && _token!.isNotEmpty;

  Map<String, String> _authHeaders() {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (_token != null && _token!.isNotEmpty) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  Uri _uri(String path) {
    final p = path.startsWith("/") ? path : "/$path";
    return Uri.parse("$_base$p");
  }

  // ---------- Public endpoints ----------

  Future<List<SoundCategory>> fetchCategories() async {
    final res = await http.get(_uri("/api/soundscapes"));
    if (res.statusCode != 200) {
      throw Exception("Failed to load soundscapes: HTTP ${res.statusCode}");
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final cats = (data['categories'] as List<dynamic>? ?? []);
    return cats
        .map((e) => SoundCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SoundFile>> fetchAllFiles() async {
    final categories = await fetchCategories();
    final all = <SoundFile>[];
    for (final c in categories) {
      all.addAll(c.files);
    }
    return all;
  }

  // ---------- Admin: OTP Auth ----------

  Future<void> adminLoginStart(String phone) async {
    final res = await http.post(
      _uri("/api/admin/login_start"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    if (res.statusCode != 200) {
      throw Exception("OTP start failed: HTTP ${res.statusCode} ${res.body}");
    }
  }

  Future<String> adminLoginVerify(String phone, String code) async {
    final res = await http.post(
      _uri("/api/admin/login_verify"),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code}),
    );
    if (res.statusCode != 200) {
      throw Exception("OTP verify failed: HTTP ${res.statusCode} ${res.body}");
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final token = data['token'] as String? ?? "";
    if (token.isEmpty) {
      throw Exception("OTP verify failed: empty token");
    }
    _token = token;
    return token;
  }

  // ---------- Admin: Categories ----------

  Future<void> createCategory(String name) async {
    final res = await http.post(
      _uri("/api/admin/create_category"),
      headers: _authHeaders(),
      body: jsonEncode({'name': name}),
    );
    if (res.statusCode != 200) {
      throw Exception("Create category failed: ${res.body}");
    }
  }

  Future<void> renameCategory(String oldName, String newName) async {
    final res = await http.post(
      _uri("/api/admin/rename_category"),
      headers: _authHeaders(),
      body: jsonEncode({'old_name': oldName, 'new_name': newName}),
    );
    if (res.statusCode != 200) {
      throw Exception("Rename category failed: ${res.body}");
    }
  }

  Future<void> deleteCategory(String name, {bool force = false}) async {
    final res = await http.post(
      _uri("/api/admin/delete_category"),
      headers: _authHeaders(),
      body: jsonEncode({'name': name, 'force': force}),
    );
    if (res.statusCode != 200) {
      throw Exception("Delete category failed: ${res.body}");
    }
  }

  // ---------- Admin: Files ----------

  Future<void> uploadFile({
    required String category,
    required String filename,
    required Uint8List bytes,
  }) async {
    final req = http.MultipartRequest('POST', _uri("/api/admin/upload"));
    if (_token != null && _token!.isNotEmpty) {
      req.headers['Authorization'] = 'Bearer $_token';
    }
    // IMPORTANT: pass a clean filename; browsers (and some pickers) can include weird params
    // in display names. The server will still secure_filename() it, but we avoid surprises here.
    final clean = filename.trim().replaceAll(RegExp(r'[;\r\n]'), '_');
    req.fields['category'] = category;
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: clean));
    final res = await http.Response.fromStream(await req.send());
    if (res.statusCode != 200) {
      throw Exception("Upload failed: ${res.body}");
    }
  }

  Future<void> renameFile({
    required String category,
    required String oldName,
    required String newName,
  }) async {
    final res = await http.post(
      _uri("/api/admin/rename_file"),
      headers: _authHeaders(),
      body: jsonEncode({
        'category': category,
        'old_name': oldName,
        'new_name': newName,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception("Rename file failed: ${res.body}");
    }
  }

  Future<void> moveFile({
    required String oldCategory,
    required String filename,
    required String newCategory,
  }) async {
    final res = await http.post(
      _uri("/api/admin/move_file"),
      headers: _authHeaders(),
      body: jsonEncode({
        'old_category': oldCategory,
        'filename': filename,
        'new_category': newCategory,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception("Move file failed: ${res.body}");
    }
  }

  Future<void> deleteFile({
    required String category,
    required String filename,
  }) async {
    final res = await http.post(
      _uri("/api/admin/delete_file"),
      headers: _authHeaders(),
      body: jsonEncode({'category': category, 'filename': filename}),
    );
    if (res.statusCode != 200) {
      throw Exception("Delete file failed: ${res.body}");
    }
  }
}
