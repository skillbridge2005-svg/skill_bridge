import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _emailSent = true;
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      String message;

      switch (e.code) {
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'user-not-found':
          message = 'No account found with this email address.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;

        case 'too-many-requests':
          message = 'Too many requests. Please try again later.';
          break;

        default:
          message = e.message ?? 'Unable to send reset email.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF173B2B),
        elevation: 0,
        title: const Text(
          'Forgot Password',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_reset,
                      size: 80,
                      color: Color(0xFF249B50),
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'Reset your password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF173B2B),
                      ),
                    ),

                    const SizedBox(height: 12),

                    const Text(
                      'Enter the email address associated with your SkillBridge account. We will send you a link to reset your password.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 32),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      enabled: !_isLoading && !_emailSent,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF249B50),
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Please enter your email address.';
                        }

                        final emailRegex = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        );

                        if (!emailRegex.hasMatch(email)) {
                          return 'Please enter a valid email address.';
                        }

                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!_isLoading && !_emailSent) {
                          _sendResetLink();
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    if (_emailSent)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF249B50)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF249B50)),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Password reset link sent successfully. Please check your email inbox and follow the instructions.',
                                style: TextStyle(
                                  color: Color(0xFF173B2B),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!_emailSent)
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _sendResetLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF249B50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Send Reset Link',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Back to Login',
                        style: TextStyle(
                          color: Color(0xFF249B50),
                          fontWeight: FontWeight.bold,
                        ),
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
