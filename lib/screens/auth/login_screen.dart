import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.role = 'developer'});

  final String role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ------------------------------------------------------------
  // COLORS
  // ------------------------------------------------------------

  static const Color primary = Color(0xFF2563EB);
  static const Color dark = Color(0xFF0F172A);
  static const Color grey = Color(0xFF64748B);
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  // ------------------------------------------------------------
  // DISPOSE
  // ------------------------------------------------------------

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // LOGIN
  // ------------------------------------------------------------

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      /*
       * We don't manually navigate to ClientHome or DeveloperHome.
       *
       * AuthWrapper will detect the logged-in user and read
       * the role from Firestore.
       */

      Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Login failed.';

      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;

        case 'wrong-password':
        case 'invalid-credential':
          message = 'Email or password is incorrect.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-disabled':
          message = 'This account has been disabled.';
          break;

        case 'too-many-requests':
          message = 'Too many attempts. Please try again later.';
          break;

        case 'network-request-failed':
          message = 'Please check your internet connection.';
          break;

        default:
          message = e.message ?? 'Unable to login.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $e'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _normalizedRoleLabel(String role) {
    return role == 'client' ? 'Client' : 'Developer';
  }

  // ------------------------------------------------------------
  // INPUT DECORATION
  // ------------------------------------------------------------

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,

      prefixIcon: Icon(icon, color: grey),

      suffixIcon: suffixIcon,

      filled: true,
      fillColor: const Color(0xFFF8FAFC),

      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),

      labelStyle: const TextStyle(color: grey, fontWeight: FontWeight.w500),

      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: borderColor),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.8),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBackground,

      body: SafeArea(
        child: Stack(
          children: [
            // ====================================================
            // BACKGROUND DECORATION
            // ====================================================

            Positioned(
              top: -100,
              right: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.10),
                ),
              ),
            ),

            Positioned(
              top: 180,
              left: -120,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.06),
                ),
              ),
            ),

            // ====================================================
            // MAIN CONTENT
            // ====================================================
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),

              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),

              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),

                  child: Column(
                    children: [
                      // =================================================
                      // SKILLBRIDGE BRANDING
                      // =================================================

                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ------------------------------------------------
                          // DEVELOPER GIF
                          // ------------------------------------------------

                          SizedBox(
                            height: 90,
                            child: Image.asset(
                              'assets/images/developer.gif',
                              width: 135,
                              fit: BoxFit.contain,
                            ),
                          ),

                          // ------------------------------------------------
                          // SKILLBRIDGE LOGO
                          // ------------------------------------------------
                          Transform.translate(
                            offset: const Offset(0, -15),

                            child: Image.asset(
                              'assets/images/skillbridge_logo.png',
                              width: 220,
                              height: 90,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 1),

                      // =================================================
                      // LOGIN CARD
                      // =================================================
                      Container(
                        padding: const EdgeInsets.all(24),

                        decoration: BoxDecoration(
                          color: Colors.white,

                          borderRadius: BorderRadius.circular(28),

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],

                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),

                        child: Form(
                          key: _formKey,

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,

                            children: [
                              // ----------------------------------------
                              // TITLE
                              // ----------------------------------------

                              Text(
                                'Welcome back 👋',
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w800,
                                  color: dark,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                'Login as ${_normalizedRoleLabel(widget.role)} to continue.',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: grey,
                                ),
                              ),

                              const SizedBox(height: 26),

                              // ----------------------------------------
                              // EMAIL
                              // ----------------------------------------
                              const Text(
                                'Email Address',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: dark,
                                ),
                              ),

                              const SizedBox(height: 8),

                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,

                                decoration: _inputDecoration(
                                  label: 'Email',
                                  hint: 'you@example.com',
                                  icon: Icons.email_outlined,
                                ),

                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter your email';
                                  }

                                  final emailRegex = RegExp(
                                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                  );

                                  if (!emailRegex.hasMatch(value.trim())) {
                                    return 'Enter a valid email';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 18),

                              // ----------------------------------------
                              // PASSWORD
                              // ----------------------------------------
                              const Text(
                                'Password',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: dark,
                                ),
                              ),

                              const SizedBox(height: 8),

                              TextFormField(
                                controller: _passwordController,

                                obscureText: _obscurePassword,

                                textInputAction: TextInputAction.done,

                                onFieldSubmitted: (_) {
                                  if (!_isLoading) {
                                    _login();
                                  }
                                },

                                decoration: _inputDecoration(
                                  label: 'Password',
                                  hint: 'Enter your password',
                                  icon: Icons.lock_outline_rounded,

                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },

                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: grey,
                                    ),
                                  ),
                                ),

                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Enter your password';
                                  }

                                  return null;
                                },
                              ),

                              // ----------------------------------------
                              // FORGOT PASSWORD
                              // ----------------------------------------
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isLoading
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const ForgotPasswordScreen(),
                                            ),
                                          );
                                        },
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: Color(0xFF249B50),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // ----------------------------------------
                              // LOGIN BUTTON
                              // ----------------------------------------
                              SizedBox(
                                height: 56,

                                child: FilledButton(
                                  onPressed: _isLoading ? null : _login,

                                  style: FilledButton.styleFrom(
                                    backgroundColor: primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),

                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,

                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,

                                          children: [
                                            Text(
                                              'Login',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),

                                            SizedBox(width: 10),

                                            Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              // ----------------------------------------
                              // DIVIDER
                              // ----------------------------------------
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: Colors.grey.shade200),
                                  ),

                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),

                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: grey,
                                      ),
                                    ),
                                  ),

                                  Expanded(
                                    child: Divider(color: Colors.grey.shade200),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // ----------------------------------------
                              // REGISTER
                              // ----------------------------------------
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,

                                children: [
                                  const Text(
                                    "Don't have an account?",
                                    style: TextStyle(color: grey, fontSize: 14),
                                  ),

                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    RegisterScreen(
                                                      initialRole: widget.role,
                                                    ),
                                              ),
                                            );
                                          },

                                    child: const Text(
                                      'Create Account',
                                      style: TextStyle(
                                        color: primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // =================================================
                      // SECURITY MESSAGE
                      // =================================================
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 15,
                            color: Colors.green.shade600,
                          ),

                          const SizedBox(width: 6),

                          const Text(
                            'Your account is securely protected',
                            style: TextStyle(fontSize: 12, color: grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
