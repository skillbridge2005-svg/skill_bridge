import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/presence_service.dart';
import '../client/client_home.dart';
import '../developer/developer_home.dart';
import '../landing_page.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    unawaited(PresenceService.instance.start());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.idTokenChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        final user = authSnapshot.data;

        if (user == null) {
          return const SkillBridgeLandingPage();
        }

        return _SupabaseRoleGate(key: ValueKey(user.uid), user: user);
      },
    );
  }
}

class _SupabaseRoleGate extends StatefulWidget {
  final User user;

  const _SupabaseRoleGate({super.key, required this.user});

  @override
  State<_SupabaseRoleGate> createState() => _SupabaseRoleGateState();
}

class _SupabaseRoleGateState extends State<_SupabaseRoleGate> {
  late Future<void> _roleSetup;

  @override
  void initState() {
    super.initState();
    _roleSetup = _configureSupabaseRole();
  }

  Future<void> _configureSupabaseRole() async {
    debugPrint('AUTH DEBUG: Skipping ensureSupabaseRole Cloud Function.');

    // Firebase authentication is already handled by AuthWrapper.
    // Refresh the token without requiring a Cloud Function.
    await widget.user.getIdToken(true);

    debugPrint('AUTH DEBUG: Firebase ID token refreshed.');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _roleSetup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingScreen();
        }

        if (snapshot.hasError) {
          return _ErrorScreen(
            message:
                'Supabase authentication setup failed.\n'
                '${snapshot.error}',
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            if (userSnapshot.hasError) {
              return _ErrorScreen(
                message: 'Profile loading failed.\n${userSnapshot.error}',
              );
            }

            if (!userSnapshot.hasData) {
              return const _LoadingScreen();
            }

            final document = userSnapshot.data!;

            if (!document.exists) {
              return const _LoadingScreen();
            }

            final data = document.data();

            if (data == null) {
              return const _ErrorScreen(message: 'User profile is empty.');
            }

            final role = data['role']?.toString().trim().toLowerCase();

            if (role == 'client') {
              return const ClientHome();
            }

            if (role == 'developer') {
              return const DeveloperHome();
            }

            return const _ErrorScreen(message: 'Invalid user role.');
          },
        );
      },
    );
  }
}

class _EmailVerificationRequiredScreen extends StatelessWidget {
  const _EmailVerificationRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 72,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please verify ${FirebaseAuth.instance.currentUser?.email ?? 'your email address'} before accessing SkillBridge.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);

                      try {
                        final user = FirebaseAuth.instance.currentUser;

                        if (user == null) {
                          return;
                        }

                        await user.reload();

                        final refreshedUser = FirebaseAuth.instance.currentUser;

                        if (refreshedUser?.emailVerified == true) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Email verified! Please wait...'),
                            ),
                          );
                        } else {
                          await refreshedUser?.sendEmailVerification();

                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Email is not verified yet. A verification email has been sent.',
                              ),
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              e.message ??
                                  'Unable to check email verification.',
                            ),
                          ),
                        );
                      }
                    },
                    child: const Text('Check Verification Status'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                  child: const Text('Back to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;

  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.red),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
