import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../state/pos_store.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({required this.store});

  final PosStore store;

  @override
  State<LoginPage> createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController(text: 'owner@poskevin.local');
  final _passwordController = TextEditingController(text: 'password123');
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final hasError = store.status.contains('gagal') || store.status.contains('Gagal') || store.status.contains('Error');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F1E8),
      body: Stack(
        children: [
          // Background gradient circles
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E6F62).withOpacity(0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1E6F62).withOpacity(0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                position: _slideAnim,
                child: SizedBox(
                  width: 440,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFD3DBDB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 48,
                          offset: const Offset(0, 20),
                        ),
                        BoxShadow(
                          color: const Color(0xFF1E6F62).withOpacity(0.04),
                          blurRadius: 80,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 52),
                      child: Theme(
                        data: ThemeData.light().copyWith(
                          textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
                          inputDecorationTheme: InputDecorationTheme(
                            filled: true,
                            fillColor: const Color(0xFFF4F8F7),
                            hintStyle: const TextStyle(color: Color(0xFF6B7A7B)),
                            labelStyle: const TextStyle(color: Color(0xFF6B7A7B)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFD3DBDB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFD3DBDB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFF1E6F62), width: 1.5),
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo
                            Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF1E6F62), Color(0xFF3aa69b)],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF1E6F62).withOpacity(0.25),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: const Text('K', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Title
                            Text(
                              'POS Kevin',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1f2d2e),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Masuk ke dashboard kasir',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: const Color(0xFF6B7A7B),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Email
                            TextField(
                              controller: _emailController,
                              style: const TextStyle(color: Color(0xFF1f2d2e), fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6B7A7B), size: 20),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Password
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: const TextStyle(color: Color(0xFF1f2d2e), fontSize: 15),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6B7A7B), size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: const Color(0xFF6B7A7B),
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Sign In Button
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E6F62),
                                  foregroundColor: const Color(0xFFFFFFFF),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                  disabledBackgroundColor: const Color(0xFF1E6F62).withOpacity(0.5),
                                ),
                                onPressed: store.loading
                                    ? null
                                    : () => store.login(
                                          email: _emailController.text.trim(),
                                          password: _passwordController.text,
                                        ),
                                child: store.loading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Color(0xFFFFFFFF), strokeWidth: 2.5),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Text('Sign In', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded, size: 20),
                                        ],
                                      ),
                              ),
                            ),

                            // Status
                            if (store.status.isNotEmpty && store.status != 'Ready' && store.status != 'Silakan login') ...[
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: (hasError ? Colors.red : const Color(0xFF027a48)).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: (hasError ? Colors.red : const Color(0xFF027a48)).withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      hasError ? Icons.error_outline : Icons.check_circle_outline,
                                      color: hasError ? Colors.red.shade400 : const Color(0xFF027a48),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        store.status,
                                        maxLines: 5,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: hasError ? Colors.red.shade400 : const Color(0xFF027a48),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ),
              ),
            ),
          ),

          // Version tag
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'POS Kevin v1.0 • Coffee Shop Edition',
                style: TextStyle(
                  color: const Color(0xFF6B7A7B).withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
