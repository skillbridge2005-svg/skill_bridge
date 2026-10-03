import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';

class HireDeveloperScreen extends StatefulWidget {
  const HireDeveloperScreen({super.key});

  @override
  State<HireDeveloperScreen> createState() => _HireDeveloperScreenState();
}

class _HireDeveloperScreenState extends State<HireDeveloperScreen> {
  String selectedSkill = 'Flutter';
  String selectedExperience = 'Any Experience';

  final List<String> skills = [
    'Flutter',
    'React',
    'Java',
    'Python',
    'Node.js',
    'UI/UX Design',
    'Database',
  ];

  final List<String> experience = [
    'Any Experience',
    'Beginner',
    'Intermediate',
    'Experienced',
  ];

  String _skillLabel(String skill, String languageCode) {
    if (languageCode == 'mr') {
      switch (skill) {
        case 'UI/UX Design':
          return 'UI/UX डिझाइन';
        case 'Database':
          return 'डेटाबेस';
        default:
          return skill;
      }
    }

    if (languageCode == 'hi') {
      switch (skill) {
        case 'UI/UX Design':
          return 'UI/UX डिज़ाइन';
        case 'Database':
          return 'डेटाबेस';
        default:
          return skill;
      }
    }

    return skill;
  }

  String _experienceLabel(String value, String languageCode) {
    if (languageCode == 'mr') {
      switch (value) {
        case 'Any Experience':
          return 'कोणताही अनुभव';
        case 'Beginner':
          return 'नवशिक्या';
        case 'Intermediate':
          return 'मध्यम अनुभव';
        case 'Experienced':
          return 'अनुभवी';
      }
    }

    if (languageCode == 'hi') {
      switch (value) {
        case 'Any Experience':
          return 'कोई भी अनुभव';
        case 'Beginner':
          return 'शुरुआती';
        case 'Intermediate':
          return 'मध्यम अनुभव';
        case 'Experienced':
          return 'अनुभवी';
      }
    }

    return value;
  }

  String _pageDescription(AppLocalizations l10n) {
    final languageCode = Localizations.localeOf(context).languageCode;

    if (languageCode == 'mr') {
      return 'तुमच्या प्रोजेक्टसाठी योग्य developer शोधण्यासाठी आवश्यकता निवडा.';
    }

    if (languageCode == 'hi') {
      return 'अपने प्रोजेक्ट के लिए सही developer खोजने के लिए आवश्यकताएँ चुनें।';
    }

    return 'Select your requirements and find developers who match your project.';
  }

  String _findDeveloperMessage(AppLocalizations l10n, String skill) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final skillName = _skillLabel(skill, languageCode);

    if (languageCode == 'mr') {
      return '$skillName developers शोधत आहे...';
    }

    if (languageCode == 'hi') {
      return '$skillName developers खोजे जा रहे हैं...';
    }

    return 'Searching $skillName developers...';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 20,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: Text(
          l10n.hireDeveloper,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HireDeveloperAmbientPainter()),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF111827), Color(0xFF1E293B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x160F172A),
                              blurRadius: 24,
                              offset: Offset(0, 9),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: const Icon(
                                Icons.person_search_rounded,
                                color: Color(0xFFA5B4FC),
                                size: 27,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.hireDeveloper.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                      color: Color(0xFFA5B4FC),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    languageCode == 'mr'
                                        ? 'योग्य developer शोधा'
                                        : languageCode == 'hi'
                                        ? 'सही developer खोजें'
                                        : 'Find the right developer',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _pageDescription(l10n),
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      height: 1.45,
                                      color: Color(0xFFD1D5DB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x060F172A),
                              blurRadius: 18,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.requiredSkill.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              l10n.requiredSkill,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: selectedSkill,
                              decoration: InputDecoration(
                                labelText: l10n.requiredSkill,
                                prefixIcon: const Icon(
                                  Icons.code_rounded,
                                  color: Color(0xFF4F46E5),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF818CF8),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              items: skills.map((skill) {
                                return DropdownMenuItem<String>(
                                  value: skill,
                                  child: Text(
                                    _skillLabel(skill, languageCode),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF344054),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value == null) return;

                                setState(() {
                                  selectedSkill = value;
                                });
                              },
                            ),
                            const SizedBox(height: 24),
                            Text(
                              l10n.experience.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              l10n.experience,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: selectedExperience,
                              decoration: InputDecoration(
                                labelText: l10n.experience,
                                prefixIcon: const Icon(
                                  Icons.work_outline_rounded,
                                  color: Color(0xFF4F46E5),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF818CF8),
                                    width: 1.4,
                                  ),
                                ),
                              ),
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              items: experience.map((item) {
                                return DropdownMenuItem<String>(
                                  value: item,
                                  child: Text(
                                    _experienceLabel(item, languageCode),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF344054),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value == null) return;

                                setState(() {
                                  selectedExperience = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: FilledButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _findDeveloperMessage(l10n, selectedSkill),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          icon: const Icon(Icons.search_rounded, size: 21),
                          label: Text(
                            l10n.findDevelopers,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HireDeveloperAmbientPainter extends CustomPainter {
  const _HireDeveloperAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0x0A4F46E5);

    canvas.drawCircle(
      Offset(size.width * 0.94, size.height * 0.10),
      180,
      paint,
    );

    paint.color = const Color(0x087C3AED);

    canvas.drawCircle(
      Offset(size.width * 0.04, size.height * 0.82),
      150,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _HireDeveloperAmbientPainter oldDelegate) {
    return false;
  }
}
