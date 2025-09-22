import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';

class AdminLoginScreen extends StatefulWidget {
  final ApiService api;
  const AdminLoginScreen({super.key, required this.api});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _phone = TextEditingController(text: "+436703596614");
  final TextEditingController _code = TextEditingController();
  bool _sending = false;
  bool _verifying = false;
  bool _stepCode = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // If already authenticated (token present), skip OTP screen.
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
      color: const Color(0xFF121212),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Admin Login (SMS OTP)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                enabled: !_stepCode && !_sending,
                decoration: const InputDecoration(
                  labelText: "Admin phone (+E.164)",
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _start(),
              ),
              const SizedBox(height: 12),
              if (_stepCode) ...[
                TextField(
                  controller: _code,
                  decoration: const InputDecoration(
                    labelText: "Code",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _stepCode ? _verify : _start,
                      child: _stepCode
                          ? (_verifying
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text("Verify"))
                          : (_sending
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text("Send Code")),
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
        title: const Text("Admin Login"),
        centerTitle: true,
        backgroundColor: Colors.black,
      ),
      body: Center(child: card),
    );
  }
}
