import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.initialRole = 'developer'});

  final String initialRole;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRole = 'developer';

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // ------------------------------------------------------------
  // COLORS
  // ------------------------------------------------------------

  static const Color primary = Color(0xFF2563EB);
  static const Color dark = Color(0xFF0F172A);
  static const Color grey = Color(0xFF64748B);
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole == 'client' ? 'client' : 'developer';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // REGISTER
  // ------------------------------------------------------------

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = credential.user;

      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-created',
          message: 'User account could not be created.',
        );
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'role': _selectedRole,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await user.updateDisplayName(name);

      if (!mounted) return;

      Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message = 'Registration failed.';

      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'weak-password':
          message = 'Password must be at least 6 characters.';
          break;

        case 'operation-not-allowed':
          message = 'Email/Password authentication is not enabled in Firebase.';
          break;

        case 'network-request-failed':
          message = 'Please check your internet connection.';
          break;

        default:
          message = e.message ?? 'Registration failed.';
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
    } on FirebaseException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firestore error: ${e.code}\n${e.message ?? ''}'),
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
          content: Text('Error: $e'),
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
  // ROLE CARD
  // ------------------------------------------------------------

  Widget _roleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool selected = _selectedRole == role;

    return Expanded(
      child: GestureDetector(
        onTap: _isLoading
            ? null
            : () {
                setState(() {
                  _selectedRole = role;
                });
              },

        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,

          padding: const EdgeInsets.all(14),

          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.08)
                : const Color(0xFFF8FAFC),

            borderRadius: BorderRadius.circular(18),

            border: Border.all(
              color: selected ? primary : borderColor,
              width: selected ? 1.8 : 1,
            ),
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ----------------------------------------------
              // ICON + SELECTION
              // ----------------------------------------------

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),

                    width: 44,
                    height: 44,

                    decoration: BoxDecoration(
                      color: selected ? primary : Colors.white,

                      borderRadius: BorderRadius.circular(13),

                      border: Border.all(
                        color: selected ? primary : borderColor,
                      ),
                    ),

                    child: Icon(
                      icon,

                      color: selected ? Colors.white : grey,

                      size: 22,
                    ),
                  ),

                  if (selected)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: primary,
                      size: 22,
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ----------------------------------------------
              // TITLE
              // ----------------------------------------------
              Text(
                title,

                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: dark,
                ),
              ),

              const SizedBox(height: 4),

              // ----------------------------------------------
              // SUBTITLE
              // ----------------------------------------------
              Text(
                subtitle,

                maxLines: 2,
                overflow: TextOverflow.ellipsis,

                style: const TextStyle(fontSize: 11, height: 1.3, color: grey),
              ),
            ],
          ),
        ),
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
            // ==================================================
            // BACKGROUND DECORATION
            // ==================================================

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
              top: 300,
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

            // ==================================================
            // MAIN CONTENT
            // ==================================================
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),

              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),

              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),

                  child: Column(
                    children: [
                      // =================================================
                      // SKILLBRIDGE BRANDING
                      // =================================================

                      Column(
                        mainAxisSize: MainAxisSize.min,

                        children: [
                          // ---------------------------------------------
                          // DEVELOPER GIF
                          // ---------------------------------------------

                          SizedBox(
                            height: 70,

                            child: Image.asset(
                              'assets/images/developer.gif',

                              width: 115,

                              fit: BoxFit.contain,
                            ),
                          ),

                          // ---------------------------------------------
                          // SKILLBRIDGE LOGO
                          // ---------------------------------------------
                          Transform.translate(
                            offset: const Offset(0, -12),

                            child: Image.asset(
                              'assets/images/skillbridge_logo.png',

                              width: 190,
                              height: 80,

                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 1),

                      // =================================================
                      // REGISTER CARD
                      // =================================================
                      Container(
                        padding: const EdgeInsets.all(24),

                        decoration: BoxDecoration(
                          color: Colors.white,

                          borderRadius: BorderRadius.circular(28),

                          border: Border.all(color: const Color(0xFFF1F5F9)),

                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),

                              blurRadius: 30,

                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),

                        child: Form(
                          key: _formKey,

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,

                            children: [
                              // =========================================
                              // TITLE
                              // =========================================

                              const Text(
                                'Create your account',

                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: dark,
                                ),
                              ),

                              const SizedBox(height: 6),

                              const Text(
                                'Tell us a little about yourself to get started.',

                                style: TextStyle(
                                  fontSize: 14,
                                  color: grey,
                                  height: 1.4,
                                ),
                              ),

                              const SizedBox(height: 25),

                              // =========================================
                              // NAME
                              // =========================================
                              const Text(
                                'Full Name',

                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: dark,
                                ),
                              ),

                              const SizedBox(height: 8),

                              TextFormField(
                                controller: _nameController,

                                textInputAction: TextInputAction.next,

                                decoration: _inputDecoration(
                                  label: 'Full Name',
                                  hint: 'Enter your full name',
                                  icon: Icons.person_outline_rounded,
                                ),

                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter your name';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 18),

                              // =========================================
                              // EMAIL
                              // =========================================
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

                              // =========================================
                              // PASSWORD
                              // =========================================
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

                                textInputAction: TextInputAction.next,

                                decoration: _inputDecoration(
                                  label: 'Password',
                                  hint: 'Create a password',
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

                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 18),

                              // =========================================
                              // CONFIRM PASSWORD
                              // =========================================
                              const Text(
                                'Confirm Password',

                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: dark,
                                ),
                              ),

                              const SizedBox(height: 8),

                              TextFormField(
                                controller: _confirmPasswordController,

                                obscureText: _obscureConfirmPassword,

                                textInputAction: TextInputAction.done,

                                decoration: _inputDecoration(
                                  label: 'Confirm Password',
                                  hint: 'Re-enter your password',
                                  icon: Icons.lock_reset_outlined,

                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },

                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,

                                      color: grey,
                                    ),
                                  ),
                                ),

                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Confirm your password';
                                  }

                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 25),

                              // =========================================
                              // ROLE
                              // =========================================
                              const Text(
                                'How will you use SkillBridge?',

                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: dark,
                                ),
                              ),

                              const SizedBox(height: 5),

                              const Text(
                                'Choose your role to personalize your experience.',

                                style: TextStyle(fontSize: 12, color: grey),
                              ),

                              const SizedBox(height: 14),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,

                                children: [
                                  // CLIENT
                                  _roleCard(
                                    role: 'client',

                                    title: 'Client',

                                    subtitle:
                                        'Post projects and find developers.',

                                    icon: Icons.business_center_outlined,
                                  ),

                                  const SizedBox(width: 12),

                                  // DEVELOPER
                                  _roleCard(
                                    role: 'developer',

                                    title: 'Developer',

                                    subtitle:
                                        'Find projects and showcase skills.',

                                    icon: Icons.code_rounded,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 26),

                              // =========================================
                              // CREATE ACCOUNT BUTTON
                              // =========================================
                              SizedBox(
                                height: 56,

                                child: FilledButton(
                                  onPressed: _isLoading ? null : _register,

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
                                              'Create Account',

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

                              const SizedBox(height: 22),

                              // =========================================
                              // LOGIN
                              // =========================================
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,

                                children: [
                                  const Text(
                                    'Already have an account?',

                                    style: TextStyle(color: grey, fontSize: 14),
                                  ),

                                  TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            Navigator.pushReplacement(
                                              context,

                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    LoginScreen(
                                                      role: _selectedRole,
                                                    ),
                                              ),
                                            );
                                          },

                                    child: const Text(
                                      'Login',

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

                      const SizedBox(height: 22),

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
                            'Your information is securely protected',

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
