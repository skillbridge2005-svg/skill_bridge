import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  static const Color _primaryColor = Color(0xFF2563EB);
  static const Color _darkColor = Color(0xFF0F172A);
  static const Color _greyColor = Color(0xFF64748B);
  static const Color _backgroundColor = Color(0xFFF8FAFC);

  bool _isChecking = false;
  bool _isResending = false;
  int _resendCountdown = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _timer?.cancel();

    setState(() {
      _resendCountdown = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendCountdown <= 1) {
        timer.cancel();

        setState(() {
          _resendCountdown = 0;
        });
      } else {
        setState(() {
          _resendCountdown--;
        });
      }
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? Colors.red.shade700
              : Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _checkVerification() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showMessage(
          'Your registration session has expired. Please sign in again.',
          isError: true,
        );
        return;
      }

      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        _showMessage('Email verified successfully!');

        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        // Return to RegisterScreen and tell it verification succeeded.
        Navigator.pop(context, true);
      } else {
        _showMessage(
          'Email not verified yet. Please check your inbox and click '
          'the verification link.',
          isError: true,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'network-request-failed':
          message = 'Network error. Check your internet connection.';
          break;
        case 'user-token-expired':
          message = 'Your session expired. Please sign in again.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        default:
          message = e.message ?? 'Could not check email verification.';
      }

      _showMessage(message, isError: true);
    } catch (_) {
      _showMessage('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (_isResending || _resendCountdown > 0) return;

    setState(() {
      _isResending = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _showMessage(
          'Your registration session has expired. Please sign in again.',
          isError: true,
        );
        return;
      }

      await user.reload();

      final refreshedUser = FirebaseAuth.instance.currentUser;

      if (refreshedUser == null) {
        _showMessage('Please sign in again to continue.', isError: true);
        return;
      }

      if (refreshedUser.emailVerified) {
        _showMessage('Your email is already verified.');
        Navigator.pop(context, true);
        return;
      }

      await refreshedUser.sendEmailVerification();

      _showMessage('Verification email sent. Please check your inbox.');

      _startResendCountdown();
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'too-many-requests':
          message = 'Too many attempts. Please wait before trying again.';
          break;
        case 'network-request-failed':
          message = 'Network error. Check your internet connection.';
          break;
        case 'user-not-found':
          message = 'Account not found. Please register again.';
          break;
        default:
          message = e.message ?? 'Could not resend verification email.';
      }

      _showMessage(message, isError: true);
    } catch (_) {
      _showMessage(
        'Could not resend the email. Please try again later.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          backgroundColor: _backgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Verify Your Email',
            style: TextStyle(color: _darkColor, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        size: 64,
                        color: _primaryColor,
                      ),
                    ),

                    const SizedBox(height: 32),

                    const Text(
                      'Check Your Inbox',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _darkColor,
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'We have sent a verification link to:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: _greyColor),
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.email_outlined,
                            color: _primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.email,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _darkColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Open the email from SkillBridge and click the '
                      'verification link. After that, return here and '
                      'tap the button below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: _greyColor,
                      ),
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isChecking ? null : _checkVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _primaryColor.withValues(
                            alpha: 0.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isChecking
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                "I've Verified My Email",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextButton(
                      onPressed: _resendCountdown > 0 || _isResending
                          ? null
                          : _resendVerificationEmail,
                      child: _isResending
                          ? const Text('Sending email...')
                          : Text(
                              _resendCountdown > 0
                                  ? 'Resend email in $_resendCountdown seconds'
                                  : 'Resend Verification Email',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: _primaryColor,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Can't find the email? Check your spam or "
                              "junk folder. Make sure you have an "
                              "internet connection.",
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: _darkColor,
                              ),
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
        ),
      ),
    );
  }
}
