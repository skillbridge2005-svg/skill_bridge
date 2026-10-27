import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:url_launcher/url_launcher.dart';

import '../../localization/app_localizations.dart';
import '../shared/leaderboard_screen.dart';
import 'client_payments_screen.dart';

class ClientProfileScreen extends StatelessWidget {
  const ClientProfileScreen({super.key});

  Future<void> _uploadProfilePhoto(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    final l10n = AppLocalizations.of(context);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.loginAgain),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    const defineSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const defineSupabasePublishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    );
    final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim().isNotEmpty == true
        ? dotenv.env['SUPABASE_URL']!.trim()
        : defineSupabaseUrl;
    final supabasePublishableKey =
        dotenv.env['SUPABASE_PUBLISHABLE_KEY']?.trim().isNotEmpty == true
        ? dotenv.env['SUPABASE_PUBLISHABLE_KEY']!.trim()
        : defineSupabasePublishableKey;
    if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile photo upload is not configured. Set the Supabase '
            'URL and publishable key in the root .env file or with '
            '--dart-define.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final storage = Supabase.instance.client.storage;
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image == null || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Uploading profile picture...'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );

      final Uint8List bytes = await image.readAsBytes();
      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';
      const allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};

      if (!allowedExtensions.contains(extension)) {
        throw const FormatException(
          'Please select a JPG, JPEG, PNG, or WebP image.',
        );
      }

      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
      final path =
          '${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await storage
          .from('profile-photos')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

      final imageUrl = storage.from('profile-photos').getPublicUrl(path);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profileImageUrl': imageUrl,
        'profileImagePath': path,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updatePhotoURL(imageUrl);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile picture updated successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update profile picture: '
            '${error.message ?? error.code}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      final message = error is FormatException
          ? error.message
          : 'Could not update profile picture: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _editProfile(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    final l10n = AppLocalizations.of(context);

    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditProfileDialog(data: data),
    );

    if (!context.mounted || result == null) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.loginAgain),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    try {
      final updatedName = result['name']!.trim();
      if (updatedName.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name must contain at least 2 characters.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': updatedName,
        'phoneNumber': result['phoneNumber']!.trim(),
        'companyName': result['companyName']!.trim(),
        'jobTitle': result['jobTitle']!.trim(),
        'location': result['location']!.trim(),
        'bio': result['bio']!.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await user.updateDisplayName(updatedName);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.update),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.somethingWentWrong}\n'
            '${e.message ?? e.code}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.somethingWentWrong}\n$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatRole(BuildContext context, String role) {
    final l10n = AppLocalizations.of(context);

    if (role.trim().isEmpty) {
      return l10n.client;
    }

    final value = role.trim().toLowerCase();

    if (value == 'client') {
      return l10n.client;
    }

    return value.replaceFirst(value[0], value[0].toUpperCase());
  }

  String _initial(String name) {
    if (name.trim().isEmpty) {
      return 'C';
    }

    return name.trim()[0].toUpperCase();
  }

  Future<void> _openInstagram(BuildContext context) async {
    final uri = Uri.parse('https://www.instagram.com/skillbridge_9t9');

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open Instagram.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Instagram.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openYouTube(BuildContext context) async {
    final uri = Uri.parse('https://www.youtube.com/@SkillBridge-nt9');

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open YouTube.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open YouTube.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'skillbridge2005@gmail.com',
      queryParameters: {'subject': 'SkillBridge Support'},
    );

    try {
      final launched = await launchUrl(uri);

      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No email app is available.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open email app.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showInformationDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Text(
              content,
              style: const TextStyle(fontSize: 13.5, height: 1.55),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showHelpAndSupport(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Help & Support',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Need help with SkillBridge?\n\n'
            'For support, questions, or reporting an issue, '
            'contact us through email.\n\n'
            'Email: skillbridge2005@gmail.com',
            style: TextStyle(fontSize: 13.5, height: 1.55),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Close'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openEmail(context);
              },
              child: const Text('Contact Us'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: Text(
          l10n.loginAgain,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF6F8FC),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ProfileAmbientPainter()),
            ),
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: _ProfileLoader());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _ProfileErrorCard(
                      message:
                          '${l10n.somethingWentWrong}\n'
                          '${snapshot.error}',
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Center(
                  child: Text(
                    l10n.projectNotFound,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              final data = snapshot.data!.data();

              if (data == null) {
                return Center(
                  child: Text(
                    l10n.noData,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              final name = data['name']?.toString() ?? '';
              final email = data['email']?.toString() ?? user.email ?? '';
              final role = data['role']?.toString() ?? '';
              final savedImageUrl = data['profileImageUrl']?.toString().trim();
              final imageUrl = savedImageUrl != null && savedImageUrl.isNotEmpty
                  ? savedImageUrl
                  : user.photoURL ?? '';

              String profileValue(String key) {
                final value = data[key]?.toString().trim() ?? '';
                return value.isEmpty ? l10n.noData : value;
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ProfileHero(
                          name: name,
                          email: email,
                          role: role,
                          initial: _initial(name),
                          imageUrl: imageUrl,
                          onChangePhoto: () => _uploadProfilePhoto(context),
                        ),
                        const SizedBox(height: 18),
                        _ProfileActionCard(
                          onEdit: () => _editProfile(context, data),
                          onPayments: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ClientPaymentsScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _ProfileLinkCard(
                          icon: Icons.emoji_events_rounded,
                          title: 'Leaderboard',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) => const LeaderboardScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        const _ProfileSectionHeading(),
                        const SizedBox(height: 14),
                        _ProfileInfoCard(
                          icon: Icons.person_outline_rounded,
                          title: 'Full Name',
                          value: name.isEmpty ? l10n.noData : name,
                        ),
                        const SizedBox(height: 12),
                        _ProfileInfoCard(
                          icon: Icons.email_outlined,
                          title: 'Email Address',
                          value: email.isEmpty ? l10n.noData : email,
                        ),
                        const SizedBox(height: 12),
                        _ProfileInfoCard(
                          icon: Icons.badge_outlined,
                          title: 'Account Type',
                          value: _formatRole(context, role),
                        ),
                        const SizedBox(height: 12),
                        _ProfileInfoCard(
                          icon: Icons.phone_outlined,
                          title: 'Phone Number',
                          value: profileValue('phoneNumber'),
                        ),
                        const SizedBox(height: 12),
                        _ProfileInfoCard(
                          icon: Icons.business_outlined,
                          title: 'Company Name',
                          value: profileValue('companyName'),
                        ),
                        const SizedBox(height: 12),
                        _ProfileInfoCard(
                          icon: Icons.work_outline_rounded,
                          title: 'Job Title',
                          value: profileValue('jobTitle'),
                        ),
                        const SizedBox(height: 12),
                        _ProfileInfoCard(
                          icon: Icons.location_on_outlined,
                          title: 'Location',
                          value: profileValue('location'),
                        ),
                        const SizedBox(height: 12),
                        _ProfileInfoCard(
                          icon: Icons.info_outline_rounded,
                          title: 'About Me',
                          value: profileValue('bio'),
                        ),
                        const SizedBox(height: 30),

                        const _ProfileSectionTitle(title: 'SUPPORT & LEGAL'),
                        const SizedBox(height: 12),

                        _ProfileLinkCard(
                          icon: Icons.description_outlined,
                          title: 'Terms & Conditions',
                          onTap: () {
                            _showInformationDialog(
                              context,
                              title: 'Terms & Conditions',
                              content:
                                  'By using SkillBridge, you agree to use '
                                  'the platform responsibly and provide '
                                  'accurate information.\n\n'
                                  'Users are responsible for their '
                                  'projects, communication, agreements, '
                                  'and activities performed through the '
                                  'platform.\n\n'
                                  'SkillBridge may update these terms '
                                  'when necessary to improve the service '
                                  'or comply with applicable requirements.',
                            );
                          },
                        ),

                        const SizedBox(height: 10),

                        _ProfileLinkCard(
                          icon: Icons.privacy_tip_outlined,
                          title: 'Privacy Policy',
                          onTap: () {
                            _showInformationDialog(
                              context,
                              title: 'Privacy Policy',
                              content:
                                  'SkillBridge may collect information '
                                  'such as your name, email address, '
                                  'profile information, project-related '
                                  'information, and other data required '
                                  'to provide the platform services.\n\n'
                                  'This information is used to provide '
                                  'authentication, project services, '
                                  'communication, payments, and platform '
                                  'functionality.\n\n'
                                  'We aim to protect user information '
                                  'and do not use personal information '
                                  'for purposes unrelated to providing '
                                  'the service without appropriate '
                                  'authorization.',
                            );
                          },
                        ),

                        const SizedBox(height: 10),

                        _ProfileLinkCard(
                          icon: Icons.help_outline_rounded,
                          title: 'Help & Support',
                          onTap: () {
                            _showHelpAndSupport(context);
                          },
                        ),

                        const SizedBox(height: 30),

                        const _ProfileSectionTitle(title: 'FOLLOW US'),
                        const SizedBox(height: 14),

                        _FollowUsCard(
                          onInstagram: () {
                            _openInstagram(context);
                          },
                          onYouTube: () {
                            _openYouTube(context);
                          },
                          onEmail: () {
                            _openEmail(context);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final String name;
  final String email;
  final String role;
  final String initial;
  final String imageUrl;
  final VoidCallback onChangePhoto;

  const _ProfileHero({
    required this.name,
    required this.email,
    required this.role,
    required this.initial,
    required this.imageUrl,
    required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 25,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x304F46E5),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            initial,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
              Material(
                color: Colors.white,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onChangePhoto,
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.client.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Color(0xFFA5B4FC),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  name.isEmpty ? l10n.client : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email.isEmpty ? l10n.noData : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFD1D5DB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Text(
              role.isEmpty ? l10n.client.toUpperCase() : role.toUpperCase(),
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
                color: Color(0xFFA5B4FC),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileActionCard extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onPayments;

  const _ProfileActionCard({required this.onEdit, required this.onPayments});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Row(
      children: [
        Expanded(
          child: _ProfileActionButton(
            icon: Icons.edit_rounded,
            title: l10n.edit,
            onTap: onEdit,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ProfileActionButton(
            icon: Icons.account_balance_wallet_rounded,
            title: l10n.payments,
            onTap: onPayments,
          ),
        ),
      ],
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF344054),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_outward_rounded,
                size: 16,
                color: Color(0xFF98A2B3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSectionHeading extends StatelessWidget {
  const _ProfileSectionHeading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.client.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.25,
            color: Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.myProfile,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.clientAccount,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  final String title;

  const _ProfileSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: Color(0xFF4F46E5),
      ),
    );
  }
}

class _ProfileLinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileLinkCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF4F46E5), size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF344054),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: Color(0xFF98A2B3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowUsCard extends StatelessWidget {
  final VoidCallback onInstagram;
  final VoidCallback onYouTube;
  final VoidCallback onEmail;

  const _FollowUsCard({
    required this.onInstagram,
    required this.onYouTube,
    required this.onEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _SocialIconButton(icon: FontAwesomeIcons.instagram, onTap: onInstagram),
        const SizedBox(width: 18),
        _SocialIconButton(icon: FontAwesomeIcons.youtube, onTap: onYouTube),
        const SizedBox(width: 18),
        _SocialIconButton(icon: FontAwesomeIcons.envelope, onTap: onEmail),
      ],
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final FaIconData icon;
  final VoidCallback onTap;

  const _SocialIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF292929),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Center(child: FaIcon(icon, size: 22, color: Colors.white)),
        ),
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ProfileInfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLoader extends StatelessWidget {
  const _ProfileLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Color(0xFF4F46E5),
      ),
    );
  }
}

class _ProfileErrorCard extends StatelessWidget {
  final String message;

  const _ProfileErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1C2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAmbientPainter extends CustomPainter {
  const _ProfileAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0x0B4F46E5);

    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.12),
      190,
      paint,
    );

    paint.color = const Color(0x087C3AED);

    canvas.drawCircle(
      Offset(size.width * 0.05, size.height * 0.78),
      155,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProfileAmbientPainter oldDelegate) {
    return false;
  }
}

class _EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic> data;

  const _EditProfileDialog({required this.data});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _companyController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _locationController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();

    String value(String key) => widget.data[key]?.toString() ?? '';

    _nameController = TextEditingController(text: value('name'));
    _phoneController = TextEditingController(text: value('phoneNumber'));
    _companyController = TextEditingController(text: value('companyName'));
    _jobTitleController = TextEditingController(text: value('jobTitle'));
    _locationController = TextEditingController(text: value('location'));
    _bioController = TextEditingController(text: value('bio'));
  }

  void _save() {
    if (_nameController.text.trim().length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid name.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Navigator.of(context).pop({
      'name': _nameController.text,
      'phoneNumber': _phoneController.text,
      'companyName': _companyController.text,
      'jobTitle': _jobTitleController.text,
      'location': _locationController.text,
      'bio': _bioController.text,
    });
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF4F46E5)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.4),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    _jobTitleController.dispose();
    _locationController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 450),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Color(0xFF4F46E5),
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Profile',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF667085),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _field(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                      ),
                      _field(
                        controller: _phoneController,
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      _field(
                        controller: _companyController,
                        label: 'Company Name',
                        icon: Icons.business_outlined,
                      ),
                      _field(
                        controller: _jobTitleController,
                        label: 'Job Title',
                        icon: Icons.work_outline_rounded,
                      ),
                      _field(
                        controller: _locationController,
                        label: 'Location',
                        icon: Icons.location_on_outlined,
                      ),
                      _field(
                        controller: _bioController,
                        label: 'About / Bio',
                        icon: Icons.info_outline_rounded,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      l10n.cancel,
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Text(
                      l10n.save,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
