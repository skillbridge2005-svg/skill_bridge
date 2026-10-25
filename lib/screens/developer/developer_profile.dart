import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../client/how_to_use_skillbridge_screen.dart';
import 'developer_reviews_screen.dart';

// ---------------------------------------------------------------- THEME
const Color _primary = Color(0xFF4F46E5);
const Color _violet = Color(0xFF7C3AED);
const Color _ink = Color(0xFF111827);
const Color _muted = Color(0xFF6B7280);
const Color _border = Color(0xFFE5E7EB);
const Color _bg = Color(0xFFF6F8FC);

// -------------------------------------------------------------- HELPERS
List<String> _stringList(dynamic value, {List<String> fallback = const []}) {
  if (value is! List) return List<String>.from(fallback);
  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

/// One completion formula used by both the profile view and the edit screen
/// so the percentage is always the same.
int _completion({
  required String name,
  required String headline,
  required String bio,
  required String location,
  required List<String> skills,
  required List<String> technologies,
  required String experience,
  required String education,
  required String github,
  required String resume,
  required String availability,
  required String projectType,
}) {
  const total = 12;
  var done = 0;

  if (name.trim().isNotEmpty) done++;
  if (headline.trim().isNotEmpty) done++;
  if (bio.trim().isNotEmpty) done++;
  if (location.trim().isNotEmpty) done++;
  if (skills.isNotEmpty) done++;
  if (technologies.isNotEmpty) done++;
  if (experience.trim().isNotEmpty) done++;
  if (education.trim().isNotEmpty) done++;
  if (github.trim().isNotEmpty) done++;
  if (resume.trim().isNotEmpty) done++;
  if (availability.isNotEmpty) done++;
  if (projectType.isNotEmpty) done++;

  return ((done / total) * 100).round();
}

Color _availabilityColor(String value) {
  switch (value) {
    case 'Available':
      return const Color(0xFF059669);
    case 'Part-time':
      return const Color(0xFF0EA5E9);
    case 'Busy':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFFDC2626);
  }
}

void _snack(BuildContext context, String message) {
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

Future<void> _openUrl(BuildContext context, String raw) async {
  var url = raw.trim();
  if (url.isEmpty) return;

  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'https://$url';
  }

  final uri = Uri.tryParse(url);

  if (uri == null) {
    _snack(context, 'This link is not valid.');
    return;
  }

  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) _snack(context, 'Could not open the link.');
  } catch (_) {
    _snack(context, 'Could not open the link.');
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
    if (!launched) _snack(context, 'No email app is available.');
  } catch (_) {
    _snack(context, 'Could not open email app.');
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Text(
            content,
            style: const TextStyle(fontSize: 13.5, height: 1.55),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
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
            onPressed: () => Navigator.pop(dialogContext),
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

// =====================================================================
//                         PROFILE (VIEW) SCREEN
// =====================================================================
class DeveloperProfile extends StatelessWidget {
  const DeveloperProfile({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text(
            'Please log in again.',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ProfileAmbientPainter()),
            ),
          ),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, userSnap) {
                if (userSnap.hasError) {
                  return const _CenterMessage(
                    icon: Icons.warning_amber_rounded,
                    message: 'Something went wrong while loading your profile.',
                  );
                }

                if (userSnap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _primary),
                  );
                }

                final userData = userSnap.data?.data() ?? {};

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('developerProfiles')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, profileSnap) {
                    if (profileSnap.hasError) {
                      return const _CenterMessage(
                        icon: Icons.warning_amber_rounded,
                        message:
                            'Something went wrong while loading your profile.',
                      );
                    }

                    if (profileSnap.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _primary),
                      );
                    }

                    final profile = profileSnap.data?.data() ?? {};

                    return _ProfileBody(
                      uid: user.uid,
                      name: userData['name']?.toString() ?? '',
                      email: userData['email']?.toString() ?? user.email ?? '',
                      profile: profile,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final String uid;
  final String name;
  final String email;
  final Map<String, dynamic> profile;

  const _ProfileBody({
    required this.uid,
    required this.name,
    required this.email,
    required this.profile,
  });

  String _text(String key) => profile[key]?.toString().trim() ?? '';

  String _orDash(String value) => value.isEmpty ? 'Not added yet' : value;

  @override
  Widget build(BuildContext context) {
    final skills = _stringList(profile['skills']);
    final technologies = _stringList(profile['technologies']);
    final languages = _stringList(profile['languages']);

    final availability = _text('availability').isEmpty
        ? 'Available'
        : _text('availability');

    final completion = _completion(
      name: name,
      headline: _text('headline'),
      bio: _text('bio'),
      location: _text('location'),
      skills: skills,
      technologies: technologies,
      experience: _text('experience'),
      education: _text('education'),
      github: _text('githubUrl'),
      resume: _text('resumeUrl'),
      availability: availability,
      projectType: _text('projectType').isEmpty ? 'Both' : _text('projectType'),
    );

    final hours = (profile['hoursPerWeek'] as num?)?.toInt() ?? 20;
    final profileVisible = profile['profileVisible'] is bool
        ? profile['profileVisible'] as bool
        : true;
    final openToTeams = profile['openToTeams'] is bool
        ? profile['openToTeams'] as bool
        : true;

    final links = <(IconData, String, String)>[
      (Icons.code_rounded, 'GitHub', _text('githubUrl')),
      (Icons.business_center_outlined, 'LinkedIn', _text('linkedinUrl')),
      (Icons.language_rounded, 'Portfolio Website', _text('portfolioUrl')),
      (Icons.description_outlined, 'Resume', _text('resumeUrl')),
    ].where((l) => l.$3.isNotEmpty).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Navigator.of(context).canPop())
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              _ProfileHero(
                name: name,
                email: email,
                headline: _text('headline'),
                photoUrl: _text('photoUrl'),
                availability: availability,
                location: _text('location'),
              ),
              const SizedBox(height: 18),

              // Edit + Reviews
              Row(
                children: [
                  Expanded(
                    child: _ProfileActionButton(
                      icon: Icons.edit_rounded,
                      title: 'Edit Profile',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DeveloperProfileEditScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProfileActionButton(
                      icon: Icons.rate_review_rounded,
                      title: 'My Reviews',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DeveloperReviewsScreen(developerId: uid),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              _CompletionCard(percentage: completion),

              const SizedBox(height: 28),
              const _ProfileSectionHeading(),
              const SizedBox(height: 14),

              _ProfileInfoCard(
                icon: Icons.person_outline_rounded,
                title: 'Full Name',
                value: name.isEmpty ? 'Not added yet' : name,
              ),
              const SizedBox(height: 12),
              _ProfileInfoCard(
                icon: Icons.email_outlined,
                title: 'Email Address',
                value: email.isEmpty ? 'Not added yet' : email,
              ),
              const SizedBox(height: 12),
              _ProfileInfoCard(
                icon: Icons.work_outline_rounded,
                title: 'Professional Headline',
                value: _orDash(_text('headline')),
              ),
              const SizedBox(height: 12),
              _ProfileInfoCard(
                icon: Icons.location_on_outlined,
                title: 'Location',
                value: _orDash(_text('location')),
              ),
              const SizedBox(height: 12),
              _ProfileInfoCard(
                icon: Icons.notes_rounded,
                title: 'About Me',
                value: _orDash(_text('bio')),
                maxLines: 8,
              ),
              const SizedBox(height: 12),
              _ProfileInfoCard(
                icon: Icons.timeline_rounded,
                title: 'Experience',
                value: _orDash(_text('experience')),
                maxLines: 6,
              ),
              const SizedBox(height: 12),
              _ProfileInfoCard(
                icon: Icons.school_outlined,
                title: 'Education',
                value: _orDash(_text('education')),
                maxLines: 4,
              ),

              const SizedBox(height: 30),
              const _ProfileSectionTitle(title: 'WORK PREFERENCES'),
              const SizedBox(height: 12),
              _pairs([
                _MiniInfoCard(
                  icon: Icons.circle,
                  title: 'Availability',
                  value: availability,
                  color: _availabilityColor(availability),
                ),
                _MiniInfoCard(
                  icon: Icons.laptop_mac_rounded,
                  title: 'Work Mode',
                  value: _text('workMode').isEmpty
                      ? 'Remote'
                      : _text('workMode'),
                ),
                _MiniInfoCard(
                  icon: Icons.layers_outlined,
                  title: 'Project Type',
                  value: _text('projectType').isEmpty
                      ? 'Both'
                      : _text('projectType'),
                ),
                _MiniInfoCard(
                  icon: Icons.hourglass_bottom_rounded,
                  title: 'Project Duration',
                  value: _text('projectDuration').isEmpty
                      ? 'Flexible'
                      : _text('projectDuration'),
                ),
                _MiniInfoCard(
                  icon: Icons.schedule_rounded,
                  title: 'Hours Per Week',
                  value: '$hours hrs',
                ),
                _MiniInfoCard(
                  icon: Icons.currency_rupee_rounded,
                  title: 'Hourly Rate',
                  value: _orDash(_text('hourlyRate')),
                ),
              ]),

              const SizedBox(height: 18),
              const _ProfileSectionTitle(title: 'SKILLS & TECHNOLOGIES'),
              const SizedBox(height: 12),
              _ChipsCard(
                icon: Icons.code_rounded,
                title: 'Skills',
                items: skills,
                emptyText: 'No skills added yet.',
              ),
              const SizedBox(height: 12),
              _ChipsCard(
                icon: Icons.memory_rounded,
                title: 'Technologies',
                items: technologies,
                emptyText: 'No technologies added yet.',
              ),
              const SizedBox(height: 12),
              _ChipsCard(
                icon: Icons.translate_rounded,
                title: 'Languages',
                items: languages,
                emptyText: 'No languages added yet.',
              ),

              if (links.isNotEmpty) ...[
                const SizedBox(height: 30),
                const _ProfileSectionTitle(title: 'PROFESSIONAL LINKS'),
                const SizedBox(height: 12),
                ...links.map(
                  (l) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProfileLinkCard(
                      icon: l.$1,
                      title: l.$2,
                      onTap: () => _openUrl(context, l.$3),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const _ProfileSectionTitle(title: 'VISIBILITY'),
              const SizedBox(height: 12),
              _pairs([
                _MiniInfoCard(
                  icon: profileVisible
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  title: 'Profile Visible',
                  value: profileVisible ? 'Yes' : 'Hidden',
                  color: profileVisible
                      ? const Color(0xFF059669)
                      : const Color(0xFF6B7280),
                ),
                _MiniInfoCard(
                  icon: Icons.groups_rounded,
                  title: 'Open to Teams',
                  value: openToTeams ? 'Yes' : 'No',
                  color: openToTeams
                      ? const Color(0xFF059669)
                      : const Color(0xFF6B7280),
                ),
              ]),

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
                onTap: () => _showHelpAndSupport(context),
              ),
              const SizedBox(height: 10),
              _ProfileLinkCard(
                icon: Icons.ondemand_video_rounded,
                title: 'How to Use SkillBridge',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HowToUseSkillBridgeScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 30),
              const _ProfileSectionTitle(title: 'FOLLOW US'),
              const SizedBox(height: 14),
              Row(
                children: [
                  _SocialIconButton(
                    icon: FontAwesomeIcons.instagram,
                    onTap: () => _openUrl(
                      context,
                      'https://www.instagram.com/skillbridge_9t9',
                    ),
                  ),
                  const SizedBox(width: 18),
                  _SocialIconButton(
                    icon: FontAwesomeIcons.youtube,
                    onTap: () => _openUrl(
                      context,
                      'https://www.youtube.com/@SkillBridge-nt9',
                    ),
                  ),
                  const SizedBox(width: 18),
                  _SocialIconButton(
                    icon: FontAwesomeIcons.envelope,
                    onTap: () => _openEmail(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pairs(List<Widget> items) {
    final rows = <Widget>[];

    for (var i = 0; i < items.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: items[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < items.length
                      ? items[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}

// ---------------------------------------------------------------- HERO
class _ProfileHero extends StatelessWidget {
  final String name;
  final String email;
  final String headline;
  final String photoUrl;
  final String availability;
  final String location;

  const _ProfileHero({
    required this.name,
    required this.email,
    required this.headline,
    required this.photoUrl,
    required this.availability,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'D' : name.trim()[0].toUpperCase();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  child: photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          width: 72,
                          height: 72,
                          errorBuilder: (_, __, ___) => _initialText(initial),
                        )
                      : _initialText(initial),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DEVELOPER',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                        color: Color(0xFFA5B4FC),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      name.isEmpty ? 'Developer' : name,
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
                      email.isEmpty ? 'No email' : email,
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
            ],
          ),
          const SizedBox(height: 16),
          Text(
            headline.isEmpty ? 'Add your professional headline' : headline,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroChip(
                Icons.circle,
                availability,
                dotColor: _availabilityColor(availability),
              ),
              if (location.isNotEmpty)
                _heroChip(Icons.location_on_outlined, location),
            ],
          ),
        ],
      ),
    );
  }

  Widget _initialText(String initial) {
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
  }

  Widget _heroChip(IconData icon, String label, {Color? dotColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: dotColor != null ? 9 : 14,
            color: dotColor ?? const Color(0xFFA5B4FC),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------- SHARED UI PIECES
class _CompletionCard extends StatelessWidget {
  final int percentage;

  const _CompletionCard({required this.percentage});

  @override
  Widget build(BuildContext context) {
    final complete = percentage >= 90;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    backgroundColor: const Color(0xFFEEF2FF),
                    color: complete ? const Color(0xFF059669) : _primary,
                  ),
                ),
                Text(
                  '$percentage%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complete
                      ? 'Profile ready for marketplace'
                      : 'Profile strength',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  complete
                      ? 'Great work! Clients can find you easily.'
                      : 'Complete your profile to improve project matching.',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: _muted,
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
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _border),
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
                child: Icon(icon, size: 20, color: _primary),
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
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DEVELOPER',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.25,
            color: _primary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'My Profile',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: _ink,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Your professional presence on SkillBridge.',
          style: TextStyle(fontSize: 12, height: 1.4, color: _muted),
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
        color: _primary,
      ),
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final int maxLines;

  const _ProfileInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: _primary),
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
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w800,
                    color: _ink,
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

class _MiniInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _MiniInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.color = _primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              size: icon == Icons.circle ? 11 : 17,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: _muted,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<String> items;
  final String emptyText;

  const _ChipsCard({
    required this.icon,
    required this.title,
    required this.items,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: _primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const Spacer(),
              if (items.isNotEmpty)
                Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _muted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Text(
              emptyText,
              style: const TextStyle(color: _muted, fontSize: 12.5),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Text(
                        item,
                        style: const TextStyle(
                          color: Color(0xFF3730A3),
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
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
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
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
                child: Icon(icon, color: _primary, size: 20),
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

class _CenterMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _CenterMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: const Color(0xFFD97706)),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
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
  bool shouldRepaint(covariant _ProfileAmbientPainter oldDelegate) => false;
}

// =====================================================================
//                         EDIT PROFILE SCREEN
// =====================================================================
class DeveloperProfileEditScreen extends StatefulWidget {
  const DeveloperProfileEditScreen({super.key});

  @override
  State<DeveloperProfileEditScreen> createState() =>
      _DeveloperProfileEditScreenState();
}

class _DeveloperProfileEditScreenState
    extends State<DeveloperProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  final _headlineController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _experienceController = TextEditingController();
  final _educationController = TextEditingController();
  final _githubController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _resumeController = TextEditingController();
  final _rateController = TextEditingController();

  final _skillController = TextEditingController();
  final _technologyController = TextEditingController();

  late final List<TextEditingController> _trackedControllers;

  bool _loading = true;
  bool _saving = false;
  bool _hasChanges = false;

  // True while data is being copied into the fields, so loading or
  // discarding does not count as a user edit.
  bool _applying = false;

  String _name = '';
  String _email = '';

  String _availability = 'Available';
  String _workMode = 'Remote';
  String _projectType = 'Both';
  String _projectDuration = 'Flexible';
  int _hoursPerWeek = 20;

  bool _profileVisible = true;
  bool _openToTeams = true;

  List<String> _skills = [];
  List<String> _technologies = [];
  List<String> _languages = ['English'];

  @override
  void initState() {
    super.initState();

    _trackedControllers = [
      _headlineController,
      _bioController,
      _locationController,
      _photoUrlController,
      _experienceController,
      _educationController,
      _githubController,
      _linkedinController,
      _portfolioController,
      _resumeController,
      _rateController,
    ];

    for (final controller in _trackedControllers) {
      controller.addListener(_markChanged);
    }

    _loadProfile();
  }

  @override
  void dispose() {
    for (final controller in _trackedControllers) {
      controller.dispose();
    }
    _skillController.dispose();
    _technologyController.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (_applying || _loading || _saving || !mounted) return;

    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    } else {
      // Refresh the live preview (avatar, completion) while typing.
      setState(() {});
    }
  }

  void _change(VoidCallback update) {
    setState(() {
      update();
      _hasChanges = true;
    });
  }

  int get _completionValue => _completion(
    name: _name,
    headline: _headlineController.text,
    bio: _bioController.text,
    location: _locationController.text,
    skills: _skills,
    technologies: _technologies,
    experience: _experienceController.text,
    education: _educationController.text,
    github: _githubController.text,
    resume: _resumeController.text,
    availability: _availability,
    projectType: _projectType,
  );

  // ---------------------------------------------------------------- LOAD
  Future<void> _loadProfile() async {
    _applying = true;

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      _email = user.email ?? '';

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        _name = userDoc.data()?['name']?.toString() ?? '';
      }

      final profileDoc = await FirebaseFirestore.instance
          .collection('developerProfiles')
          .doc(user.uid)
          .get();

      final data = profileDoc.data() ?? <String, dynamic>{};

      _headlineController.text = data['headline']?.toString() ?? '';
      _bioController.text = data['bio']?.toString() ?? '';
      _locationController.text = data['location']?.toString() ?? '';
      _photoUrlController.text = data['photoUrl']?.toString() ?? '';
      _experienceController.text = data['experience']?.toString() ?? '';
      _educationController.text = data['education']?.toString() ?? '';
      _githubController.text = data['githubUrl']?.toString() ?? '';
      _linkedinController.text = data['linkedinUrl']?.toString() ?? '';
      _portfolioController.text = data['portfolioUrl']?.toString() ?? '';
      _resumeController.text = data['resumeUrl']?.toString() ?? '';
      _rateController.text = data['hourlyRate']?.toString() ?? '';

      _availability = data['availability']?.toString() ?? 'Available';
      _workMode = data['workMode']?.toString() ?? 'Remote';
      _projectType = data['projectType']?.toString() ?? 'Both';
      _projectDuration = data['projectDuration']?.toString() ?? 'Flexible';
      _hoursPerWeek = ((data['hoursPerWeek'] as num?)?.toInt() ?? 20).clamp(
        5,
        60,
      );

      _profileVisible = data['profileVisible'] is bool
          ? data['profileVisible'] as bool
          : true;
      _openToTeams = data['openToTeams'] is bool
          ? data['openToTeams'] as bool
          : true;

      _skills = _stringList(data['skills']);
      _technologies = _stringList(data['technologies']);
      _languages = _stringList(data['languages'], fallback: ['English']);
      if (_languages.isEmpty) _languages = ['English'];

      if (mounted) {
        setState(() {
          _loading = false;
          _hasChanges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showMessage('Unable to load profile', isError: true);
      }
    } finally {
      _applying = false;
    }
  }

  // ---------------------------------------------------------------- SAVE
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      // Same percentage everywhere, so both screens always agree.
      final completion = _completionValue;

      final profileRef = FirebaseFirestore.instance
          .collection('developerProfiles')
          .doc(user.uid);

      // Check whether this is the first profile save.
      final existingProfile = await profileRef.get();

      final profileData = <String, dynamic>{
        'uid': user.uid,
        'name': _name,
        'email': _email,
        'headline': _headlineController.text.trim(),
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
        'photoUrl': _photoUrlController.text.trim(),
        'experience': _experienceController.text.trim(),
        'education': _educationController.text.trim(),
        'skills': _skills,
        'technologies': _technologies,
        'languages': _languages,
        'githubUrl': _githubController.text.trim(),
        'linkedinUrl': _linkedinController.text.trim(),
        'portfolioUrl': _portfolioController.text.trim(),
        'resumeUrl': _resumeController.text.trim(),
        'availability': _availability,
        'workMode': _workMode,
        'projectType': _projectType,
        'projectDuration': _projectDuration,
        'hoursPerWeek': _hoursPerWeek,
        'hourlyRate': _rateController.text.trim(),
        'profileVisible': _profileVisible,
        'openToTeams': _openToTeams,
        'profileCompletion': completion,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // createdAt is written only once and never overwritten later.
      if (!existingProfile.exists) {
        profileData['createdAt'] = FieldValue.serverTimestamp();
      }

      await profileRef.set(profileData, SetOptions(merge: true));

      // Keep the users document synchronized for other screens.
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'profileCompletion': completion,
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _saving = false;
          _hasChanges = false;
        });
        _showMessage('Profile updated successfully');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showMessage('Could not save your profile', isError: true);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        backgroundColor: isError ? Colors.red.shade700 : _ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _addSkill() {
    final value = _skillController.text.trim();
    if (value.isEmpty) return;

    if (!_skills.contains(value)) {
      _change(() => _skills.add(value));
    }
    _skillController.clear();
  }

  void _addTechnology() {
    final value = _technologyController.text.trim();
    if (value.isEmpty) return;

    if (!_technologies.contains(value)) {
      _change(() => _technologies.add(value));
    }
    _technologyController.clear();
  }

  void _addLanguage(String language) {
    if (!_languages.contains(language)) {
      _change(() => _languages.add(language));
    }
  }

  Future<bool> _showDiscardDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Discard changes?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'You have unsaved profile changes. Are you sure you want to leave?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Stay'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // --------------------------------------------------------------- BUILD
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final discard = await _showDiscardDialog();

        if (discard && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Edit Profile',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
          ),
          iconTheme: const IconThemeData(color: _ink),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Center(child: _completionMini()),
            ),
          ],
        ),
        bottomNavigationBar: _hasChanges ? _buildSaveBar() : null,
        body: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _ProfileAmbientPainter()),
              ),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildEditHeader(),
                        const SizedBox(height: 18),
                        _basicSection(),
                        _skillsSection(),
                        _experienceSection(),
                        _preferencesSection(),
                        _linksSection(),
                        _languagesSection(),
                        _visibilitySection(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _completionMini() {
    final percentage = _completionValue;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              value: percentage / 100,
              strokeWidth: 3,
              backgroundColor: Colors.white,
              color: _primary,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '$percentage%',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: Color(0xFF3730A3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditHeader() {
    final photo = _photoUrlController.text.trim();
    final initial = _name.trim().isEmpty ? 'D' : _name.trim()[0].toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: photo.isNotEmpty
                  ? Image.network(
                      photo,
                      fit: BoxFit.cover,
                      width: 64,
                      height: 64,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _name.isEmpty ? 'Developer' : _name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _hasChanges ? 'Unsaved changes' : 'All changes saved',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _hasChanges
                        ? const Color(0xFFFCD34D)
                        : const Color(0xFF6EE7B7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ SECTIONS
  Widget _basicSection() {
    return _section(
      icon: Icons.person_outline_rounded,
      title: 'Basic Information',
      subtitle: 'Tell clients who you are and what you build.',
      gradient: const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
      child: Column(
        children: [
          _field(
            controller: _headlineController,
            label: 'Professional Headline',
            hint: 'e.g. Flutter Developer | Firebase | AI',
            icon: Icons.work_outline_rounded,
            required: true,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _bioController,
            label: 'Professional Bio',
            hint: 'Describe your experience, strengths and what you enjoy building...',
            icon: Icons.notes_rounded,
            maxLines: 5,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _locationController,
            label: 'Location',
            hint: 'e.g. Kolhapur, Maharashtra',
            icon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _photoUrlController,
            label: 'Profile Photo URL',
            hint: 'https://...',
            icon: Icons.photo_outlined,
          ),
        ],
      ),
    );
  }

  Widget _skillsSection() {
    return _section(
      icon: Icons.code_rounded,
      title: 'Skills & Technologies',
      subtitle: 'Add skills that SkillBridge can use for project matching.',
      gradient: const [Color(0xFFEC4899), Color(0xFF7C3AED)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Skills'),
          _chipInput(
            controller: _skillController,
            hint: 'Add a skill e.g. Flutter',
            onAdd: _addSkill,
          ),
          const SizedBox(height: 12),
          _chips(_skills, (s) => _change(() => _skills.remove(s))),
          const SizedBox(height: 22),
          _label('Technologies'),
          _chipInput(
            controller: _technologyController,
            hint: 'Add technology e.g. Firebase',
            onAdd: _addTechnology,
          ),
          const SizedBox(height: 12),
          _chips(_technologies, (t) => _change(() => _technologies.remove(t))),
        ],
      ),
    );
  }

  Widget _experienceSection() {
    return _section(
      icon: Icons.workspace_premium_outlined,
      title: 'Professional Experience',
      subtitle: 'Help clients understand your background and expertise.',
      gradient: const [Color(0xFF0EA5E9), Color(0xFF4F46E5)],
      child: Column(
        children: [
          _field(
            controller: _experienceController,
            label: 'Experience',
            hint: 'e.g. 2 years Flutter development, freelance projects...',
            icon: Icons.timeline_rounded,
            maxLines: 4,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _educationController,
            label: 'Education',
            hint: 'e.g. B.Tech Computer Science & Engineering',
            icon: Icons.school_outlined,
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _preferencesSection() {
    return _section(
      icon: Icons.tune_rounded,
      title: 'Work Preferences',
      subtitle: 'These preferences help SkillBridge find suitable projects.',
      gradient: const [Color(0xFFF59E0B), Color(0xFFEC4899)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Availability'),
          _choice(
            items: const ['Available', 'Part-time', 'Busy', 'Unavailable'],
            value: _availability,
            colorFor: _availabilityColor,
            onChanged: (v) => _change(() => _availability = v),
          ),
          const SizedBox(height: 20),
          _label('Work Mode'),
          _choice(
            items: const ['Remote', 'Hybrid', 'On-site'],
            value: _workMode,
            onChanged: (v) => _change(() => _workMode = v),
          ),
          const SizedBox(height: 20),
          _label('Project Type'),
          _choice(
            items: const ['Both', 'Short-term', 'Long-term', 'Freelance'],
            value: _projectType,
            onChanged: (v) => _change(() => _projectType = v),
          ),
          const SizedBox(height: 20),
          _label('Project Duration'),
          _choice(
            items: const [
              'Flexible',
              'Less than 1 month',
              '1–3 months',
              '3–6 months',
              '6+ months',
            ],
            value: _projectDuration,
            onChanged: (v) => _change(() => _projectDuration = v),
          ),
          const SizedBox(height: 22),
          _hoursSlider(),
          const SizedBox(height: 18),
          _field(
            controller: _rateController,
            label: 'Expected Hourly Rate',
            hint: 'e.g. ₹500 / hour',
            icon: Icons.currency_rupee_rounded,
          ),
        ],
      ),
    );
  }

  Widget _linksSection() {
    return _section(
      icon: Icons.link_rounded,
      title: 'Professional Links',
      subtitle: 'Connect your professional presence and portfolio.',
      gradient: const [Color(0xFF059669), Color(0xFF0EA5E9)],
      child: Column(
        children: [
          _field(
            controller: _githubController,
            label: 'GitHub',
            hint: 'https://github.com/username',
            icon: Icons.code_rounded,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _linkedinController,
            label: 'LinkedIn',
            hint: 'https://linkedin.com/in/username',
            icon: Icons.business_center_outlined,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _portfolioController,
            label: 'Portfolio Website',
            hint: 'https://yourportfolio.com',
            icon: Icons.language_rounded,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _resumeController,
            label: 'Resume URL',
            hint: 'https://...',
            icon: Icons.description_outlined,
          ),
        ],
      ),
    );
  }

  Widget _languagesSection() {
    const options = [
      'English',
      'Hindi',
      'Marathi',
      'Gujarati',
      'Tamil',
      'Telugu',
    ];

    return _section(
      icon: Icons.translate_rounded,
      title: 'Languages',
      subtitle: 'Languages you can use while communicating with clients.',
      gradient: const [Color(0xFF6366F1), Color(0xFF06B6D4)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _chips(_languages, (language) {
            if (_languages.length <= 1) return;
            _change(() => _languages.remove(language));
          }),
          const SizedBox(height: 16),
          _label('Quick add'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .where((language) => !_languages.contains(language))
                .map(
                  (language) => ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text(language),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: BorderSide.none,
                    onPressed: () => _addLanguage(language),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _visibilitySection() {
    return _section(
      icon: Icons.security_outlined,
      title: 'Profile Visibility',
      subtitle: 'Control how clients and other developers discover you.',
      gradient: const [Color(0xFF111827), Color(0xFF4F46E5)],
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Show my profile to clients',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Allow your profile to appear in developer search and project matching.',
            ),
            value: _profileVisible,
            onChanged: (value) => _change(() => _profileVisible = value),
          ),
          const Divider(height: 28),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Open to team projects',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: const Text(
              'Allow other developers to invite you to collaborative projects.',
            ),
            value: _openToTeams,
            onChanged: (value) => _change(() => _openToTeams = value),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- WIDGETS
  Widget _section({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: _muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _ink,
      ),
    ),
  );

  InputDecoration _decoration({
    required String label,
    String? hint,
    IconData? icon,
    bool multiline = false,
  }) {
    OutlineInputBorder outline(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: multiline,
      prefixIcon: icon == null
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: multiline ? 0 : 0),
              child: Icon(icon, color: _primary),
            ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: outline(_border),
      enabledBorder: outline(_border),
      focusedBorder: outline(_primary, 1.6),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Please add a professional headline';
        }
        return null;
      },
      decoration: _decoration(
        label: label,
        hint: hint,
        icon: icon,
        multiline: maxLines > 1,
      ),
    );
  }

  Widget _choice({
    required List<String> items,
    required String value,
    required ValueChanged<String> onChanged,
    Color Function(String)? colorFor,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final selected = item == value;
        final color = colorFor?.call(item) ?? _primary;

        return GestureDetector(
          onTap: () => onChanged(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? color : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: selected ? color : const Color(0xFFE2E8F0),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _ink,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _hoursSlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: _primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Available Hours Per Week',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '$_hoursPerWeek hrs',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _hoursPerWeek.toDouble(),
            min: 5,
            max: 60,
            divisions: 11,
            activeColor: _primary,
            onChanged: (value) => _change(() => _hoursPerWeek = value.round()),
          ),
        ],
      ),
    );
  }

  Widget _chipInput({
    required TextEditingController controller,
    required String hint,
    required VoidCallback onAdd,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onSubmitted: (_) => onAdd(),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.add_circle_outline_rounded),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: _primary, width: 1.6),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 54,
          child: FilledButton(
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Widget _chips(List<String> items, ValueChanged<String> onDelete) {
    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Nothing added yet. Add some items above.',
          style: TextStyle(color: _muted, fontSize: 12.5),
        ),
      );
    }

    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: items.map((item) {
        return Container(
          padding: const EdgeInsets.only(left: 13, right: 6, top: 7, bottom: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFC7D2FE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item,
                style: const TextStyle(
                  color: Color(0xFF3730A3),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => onDelete(item),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(Icons.close_rounded, size: 16, color: _violet),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSaveBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: _border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.edit_rounded, color: Color(0xFFD97706), size: 19),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'Unsaved changes',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: _saving ? null : _loadProfile,
              child: const Text('Discard'),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primary, _violet]),
                borderRadius: BorderRadius.circular(13),
              ),
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveProfile,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(_saving ? 'Saving...' : 'Save Profile'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
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
