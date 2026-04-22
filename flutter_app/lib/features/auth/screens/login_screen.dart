import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../shared/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final error = await authService.signInWithGoogle();

    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEEF2FF), Colors.white, Color(0xFFF5F3FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 120,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryGold.withAlpha(38),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Image.network(
                        'https://mandalikaperfume.co.id/wp-content/uploads/2025/02/GOLD-Tanpa-Text-Bawah.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.storefront,
                          size: 48,
                          color: AppTheme.primaryGold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'Mandalika',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Your Scent, Your Statement — Point of Sale',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Gold divider
                    Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Login card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(15),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          // Error message
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppTheme.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Google Sign-In button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSignIn,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Google G logo
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: Text(
                                              'G',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        const Text('Masuk dengan Google'),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Hanya akun yang terdaftar dapat masuk',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'Mandalika POS v2.0 · Flutter + Go',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}