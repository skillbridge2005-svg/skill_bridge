import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _budgetController = TextEditingController();
  final _timelineController = TextEditingController();

  String _selectedCategory = 'Web Application';
  bool _isLoading = false;

  final List<String> _categories = [
    'Web Application',
    'Mobile Application',
    'Desktop Application',
    'Software System',
    'E-Commerce',
    'Business Application',
    'Other',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _budgetController.dispose();
    _timelineController.dispose();
    super.dispose();
  }

  String _categoryLabel(BuildContext context, String category) {
    final language = AppLocalizations.of(context);

    switch (category) {
      case 'Web Application':
        return language.projects == 'Projects'
            ? 'Web Application'
            : category == 'Web Application' &&
                  language.projects == 'प्रोजेक्ट्स'
            ? 'वेब ॲप्लिकेशन'
            : language.locale.languageCode == 'hi'
            ? 'वेब एप्लिकेशन'
            : 'वेब ॲप्लिकेशन';

      case 'Mobile Application':
        return language.locale.languageCode == 'hi'
            ? 'मोबाइल एप्लिकेशन'
            : language.locale.languageCode == 'mr'
            ? 'मोबाइल ॲप्लिकेशन'
            : 'Mobile Application';

      case 'Desktop Application':
        return language.locale.languageCode == 'hi'
            ? 'डेस्कटॉप एप्लिकेशन'
            : language.locale.languageCode == 'mr'
            ? 'डेस्कटॉप ॲप्लिकेशन'
            : 'Desktop Application';

      case 'Software System':
        return language.locale.languageCode == 'hi'
            ? 'सॉफ्टवेयर सिस्टम'
            : language.locale.languageCode == 'mr'
            ? 'सॉफ्टवेअर सिस्टम'
            : 'Software System';

      case 'E-Commerce':
        return language.locale.languageCode == 'hi'
            ? 'ई-कॉमर्स'
            : language.locale.languageCode == 'mr'
            ? 'ई-कॉमर्स'
            : 'E-Commerce';

      case 'Business Application':
        return language.locale.languageCode == 'hi'
            ? 'बिजनेस एप्लिकेशन'
            : language.locale.languageCode == 'mr'
            ? 'बिझनेस ॲप्लिकेशन'
            : 'Business Application';

      case 'Other':
        return language.locale.languageCode == 'hi'
            ? 'अन्य'
            : language.locale.languageCode == 'mr'
            ? 'इतर'
            : 'Other';

      default:
        return category;
    }
  }

  Future<void> _createProject() async {
    final l10n = AppLocalizations.of(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.loginAgain),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final projectRef = FirebaseFirestore.instance
          .collection('projects')
          .doc();

      final projectData = {
        'projectId': projectRef.id,
        'clientId': user.uid,
        'title': _titleController.text.trim(),
        'category': _selectedCategory,
        'description': _descriptionController.text.trim(),
        'requirements': _requirementsController.text.trim(),
        'budget': _budgetController.text.trim(),
        'timeline': _timelineController.text.trim(),
        'status': 'requirement',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await projectRef.set(projectData);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
            'title': l10n.createProject,
            'message': l10n.projectGeneratedSuccessfully,
            'type': 'project',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.projectGeneratedSuccessfully),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;

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
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.somethingWentWrong}\n$e'),
          behavior: SnackBarBehavior.floating,
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

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF667085), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        borderSide: const BorderSide(color: Color(0xFF818CF8), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFFCA5A5)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
      ),
      labelStyle: const TextStyle(
        color: Color(0xFF667085),
        fontWeight: FontWeight.w600,
      ),
      hintStyle: const TextStyle(color: Color(0xFF98A2B3), fontSize: 13),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 20,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: Text(
          l10n.createProject,
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
              child: CustomPaint(painter: _CreateProjectAmbientPainter()),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
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
                                  Icons.add_business_rounded,
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
                                      l10n.createProject.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        color: Color(0xFFA5B4FC),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      l10n.createProject,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.softwareProjectsDescription,
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
                                l10n.projectDetails.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                l10n.overview,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 18),

                              TextFormField(
                                controller: _titleController,
                                textInputAction: TextInputAction.next,
                                decoration: _fieldDecoration(
                                  label: l10n.projectTitle,
                                  hint: l10n.exampleProjectIdea,
                                  icon: Icons.title_rounded,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return l10n.projectTitle;
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              DropdownButtonFormField<String>(
                                initialValue: _selectedCategory,
                                decoration: _fieldDecoration(
                                  label: l10n.category,
                                  hint: l10n.select,
                                  icon: Icons.category_outlined,
                                ),
                                dropdownColor: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                items: _categories
                                    .map(
                                      (category) => DropdownMenuItem<String>(
                                        value: category,
                                        child: Text(
                                          _categoryLabel(context, category),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF344054),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setState(() {
                                    _selectedCategory = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        Container(
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
                                l10n.description.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                l10n.describeProject,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 18),

                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 5,
                                textInputAction: TextInputAction.newline,
                                decoration: _fieldDecoration(
                                  label: l10n.projectDescription,
                                  hint: l10n.describeProject,
                                  icon: Icons.description_outlined,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return l10n.projectDescription;
                                  }

                                  if (value.trim().length < 20) {
                                    return l10n.requirements;
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _requirementsController,
                                maxLines: 6,
                                textInputAction: TextInputAction.newline,
                                decoration: _fieldDecoration(
                                  label: l10n.requirements,
                                  hint: l10n.requirements,
                                  icon: Icons.checklist_rounded,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return l10n.requirements;
                                  }

                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        Container(
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
                                l10n.timeline.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${l10n.budget} & ${l10n.timeline}',
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 18),

                              LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth < 600) {
                                    return Column(
                                      children: [
                                        TextFormField(
                                          controller: _budgetController,
                                          keyboardType: TextInputType.number,
                                          decoration: _fieldDecoration(
                                            label: l10n.budget,
                                            hint: l10n.amount,
                                            icon: Icons.currency_rupee_rounded,
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return l10n.budget;
                                            }

                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: _timelineController,
                                          decoration: _fieldDecoration(
                                            label: l10n.timeline,
                                            hint: l10n.timeline,
                                            icon: Icons.schedule_outlined,
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return l10n.timeline;
                                            }

                                            return null;
                                          },
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _budgetController,
                                          keyboardType: TextInputType.number,
                                          decoration: _fieldDecoration(
                                            label: l10n.budget,
                                            hint: l10n.amount,
                                            icon: Icons.currency_rupee_rounded,
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return l10n.budget;
                                            }

                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _timelineController,
                                          decoration: _fieldDecoration(
                                            label: l10n.timeline,
                                            hint: l10n.timeline,
                                            icon: Icons.schedule_outlined,
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return l10n.timeline;
                                            }

                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          height: 55,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _createProject,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              disabledBackgroundColor: const Color(0xFFA5B4FC),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: _isLoading
                                  ? Row(
                                      key: const ValueKey('loading'),
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 21,
                                          height: 21,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 11),
                                        Text(
                                          l10n.loading,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      key: const ValueKey('create'),
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.add_business_rounded,
                                          size: 21,
                                        ),
                                        const SizedBox(width: 9),
                                        Text(
                                          l10n.createProject,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          l10n.requirement,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF98A2B3),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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

class _CreateProjectAmbientPainter extends CustomPainter {
  const _CreateProjectAmbientPainter();

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
  bool shouldRepaint(covariant _CreateProjectAmbientPainter oldDelegate) {
    return false;
  }
}
