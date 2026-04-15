import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/admin_auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() => _loading = true);
    final auth = context.read<AdminAuthProvider>();
    await auth.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AdminAuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: Color(0xFFD4AF37), size: 36),
                ),
                const SizedBox(height: 20),
                Text('LookMaxing',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFFD4AF37),
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                Text('Admin Dashboard',
                    style: GoogleFonts.poppins(
                        color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 40),

                // Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!auth.isAdmin && auth.user != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'This account is not authorised as admin.',
                            style: TextStyle(color: Colors.red, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      Text('Email',
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDeco('admin@example.com'),
                      ),
                      const SizedBox(height: 16),
                      Text('Password',
                          style: GoogleFonts.poppins(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _signIn(),
                        decoration: _inputDeco('••••••••').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                                _obscure ? Icons.visibility_off : Icons.visibility,
                                color: Colors.white38, size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 12),
                        Text(auth.error!,
                            style: const TextStyle(color: Colors.red, fontSize: 12),
                            textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _loading ? null : _signIn,
                          child: _loading
                              ? const SizedBox(
                                  height: 18, width: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.black, strokeWidth: 2))
                              : Text('Sign In',
                                  style: GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: const Color(0xFF0E0E0E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
      );
}
