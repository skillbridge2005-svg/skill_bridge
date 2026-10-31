import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/developer_rating_summary.dart';
import '../../widgets/developer_reviews_list.dart';
import '../../widgets/skillbridge_avatar.dart';

/// Read-only profile view for a developer other than the signed-in user.
/// The profile is loaded using the selected developer's UID.
class DeveloperPublicProfileScreen extends StatelessWidget {
  const DeveloperPublicProfileScreen({super.key, required this.developerId});

  final String developerId;

  List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _value(Map<String, dynamic> data, String key, [String fallback = '']) {
    final value = data[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Developer Profile'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: FutureBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
        future: Future.wait([
          FirebaseFirestore.instance.collection('users').doc(developerId).get(),
          FirebaseFirestore.instance
              .collection('developerProfiles')
              .doc(developerId)
              .get(),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _message(
              'Unable to load this developer profile. Check Firestore access and try again.',
              icon: Icons.error_outline_rounded,
            );
          }
          final docs = snapshot.data;
          if (docs == null ||
              docs.length < 2 ||
              (!docs[0].exists && !docs[1].exists)) {
            return _message(
              'Developer profile not found.',
              icon: Icons.person_off_outlined,
            );
          }

          final user = docs[0].data() ?? <String, dynamic>{};
          final profile = docs[1].data() ?? <String, dynamic>{};
          final name = _value(
            profile,
            'name',
            _value(
              user,
              'name',
              _value(
                user,
                'displayName',
                _value(user, 'fullName', 'Developer'),
              ),
            ),
          );
          final email = _value(profile, 'email', _value(user, 'email'));
          final headline = _value(profile, 'headline', 'Developer');
          final photoUrl = _value(
            user,
            'profileImageUrl',
            _value(profile, 'photoUrl'),
          );
          final skills = _strings(profile['skills']);
          final technologies = _strings(profile['technologies']);
          final languages = _strings(profile['languages']);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF111827), Color(0xFF312E81)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    SkillBridgeAvatar(
                      profileImageUrl: photoUrl,
                      name: name,
                      size: 96,
                      backgroundColor: const Color(0xFFE0E7FF),
                      foregroundColor: const Color(0xFF4338CA),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      headline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        email,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _section('About', _value(profile, 'bio', 'No bio added yet.')),
              _chipsSection('Skills', skills),
              _chipsSection('Technologies', technologies),
              _section(
                'Location',
                _value(profile, 'location', 'Not specified'),
              ),
              _section(
                'Experience',
                _value(profile, 'experience', 'Not specified'),
              ),
              _section(
                'Education',
                _value(profile, 'education', 'Not specified'),
              ),
              _section(
                'Availability',
                _value(profile, 'availability', 'Not specified'),
              ),
              _section(
                'Work mode',
                _value(profile, 'workMode', 'Not specified'),
              ),
              _section(
                'Project preference',
                _value(profile, 'projectType', 'Not specified'),
              ),
              _section(
                'Preferred duration',
                _value(profile, 'projectDuration', 'Not specified'),
              ),
              _section(
                'Hours per week',
                profile['hoursPerWeek']?.toString() ?? 'Not specified',
              ),
              _section(
                'Hourly rate',
                _value(profile, 'hourlyRate', 'Not specified'),
              ),
              _chipsSection('Languages', languages),
              _linkSection(context, 'GitHub', _value(profile, 'githubUrl', '')),
              _linkSection(
                context,
                'LinkedIn',
                _value(profile, 'linkedinUrl', ''),
              ),
              _linkSection(
                context,
                'Portfolio',
                _value(profile, 'portfolioUrl', ''),
              ),
              _linkSection(context, 'Resume', _value(profile, 'resumeUrl', '')),
              const SizedBox(height: 24),
              DeveloperRatingSummary(developerId: developerId),
              const SizedBox(height: 24),
              DeveloperReviewsList(developerId: developerId),
            ],
          );
        },
      ),
    );
  }

  Widget _message(String text, {required IconData icon}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: const Color(0xFF64748B)),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            value,
            style: const TextStyle(height: 1.45, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }

  Widget _linkSection(BuildContext context, String title, String value) {
    final hasLink = value.trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: InkWell(
        onTap: hasLink ? () => _openLink(context, value) : null,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasLink ? 'Tap to open' : 'Not provided',
                    style: TextStyle(
                      height: 1.45,
                      color: hasLink
                          ? const Color(0xFF2563EB)
                          : const Color(0xFF4B5563),
                    ),
                  ),
                ),
                if (hasLink) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: Color(0xFF2563EB),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLink(BuildContext context, String rawValue) async {
    var value = rawValue.trim();
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('This link is not valid.')));
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the link.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
    }
  }

  Widget _chipsSection(String title, List<String> values) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          if (values.isEmpty)
            const Text(
              'Not provided',
              style: TextStyle(color: Color(0xFF6B7280)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values
                  .map(
                    (value) => Chip(
                      label: Text(value),
                      backgroundColor: const Color(0xFFEEF2FF),
                      side: BorderSide.none,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
