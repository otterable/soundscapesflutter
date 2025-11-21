// lib/screens/admin_login_screen.dart

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';

// brand palette
const Color kNavy = Color(0xFF003056);
const Color kNavySoft = Color(0xFF00213C);
const Color kAccent = Color(0xFFFF5C00);
const Color kDanger = Color(0xFF9A031E);
const Color kFieldBorder = Color(0xFF1E3C57);
const Color kOk = Color(0xFF1C5434);
const Color kRulesBeige = Color(0xFFF5E9DA);
const Color kErrorVivid = Color(0xFFEF233C);

class AdminLoginScreen extends StatefulWidget {
  final ApiService api;
  const AdminLoginScreen({super.key, required this.api});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _phone = TextEditingController(text: "");
  final TextEditingController _code = TextEditingController();

  bool _sending = false;
  bool _verifying = false;
  bool _stepCode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.api.isAuthed && mounted) {
        debugPrint("AdminLogin: already authed, redirecting to /admin");
        Navigator.pushReplacementNamed(context, "/admin");
      }
    });
  }

  Future<void> _start() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final phone = _phone.text.trim();
      debugPrint("AdminLogin: starting OTP for $phone");
      await widget.api.adminLoginStart(phone);
      debugPrint("AdminLogin: OTP sent");
      setState(() => _stepCode = true);
    } catch (e) {
      debugPrint("AdminLogin: start error: $e");
      setState(() => _error = "$e");
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final phone = _phone.text.trim();
      final code = _code.text.trim();
      debugPrint("AdminLogin: verifying OTP for $phone");
      final token = await widget.api.adminLoginVerify(phone, code);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('admin_token', token);
      debugPrint("AdminLogin: verified, token saved");
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, "/admin");
    } catch (e) {
      debugPrint("AdminLogin: verify error: $e");
      setState(() => _error = "$e");
    } finally {
      setState(() => _verifying = false);
    }
  }

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = Card(
      color: kNavy.withOpacity(0.92),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: const [
                  Icon(Icons.admin_panel_settings, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Admin login",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                enabled: !_stepCode && !_sending,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Login",
                  prefixIcon: Icon(Icons.donut_large, color: Colors.white70),
                ),
                keyboardType: TextInputType.phone,
                onSubmitted: (_) => _start(),
              ),
              const SizedBox(height: 12),
              if (_stepCode) ...[
                TextField(
                  controller: _code,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: "Code",
                    prefixIcon: Icon(Icons.sms, color: Colors.white70),
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: kErrorVivid,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _stepCode ? _verify : _start,
                      icon: _stepCode
                          ? const Icon(Icons.lock_open, color: Colors.white)
                          : const Icon(Icons.send, color: Colors.white),
                      label: _stepCode
                          ? (_verifying
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text("Verify"))
                          : (_sending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text("Login")),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin login"),
        centerTitle: true,
        backgroundColor: kNavy.withOpacity(0.95),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/molen.png',
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withOpacity(0.30)),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: card,
            ),
          ),
        ],
      ),
    );
  }
}
