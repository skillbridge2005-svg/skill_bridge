import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../localization/app_localizations.dart';
import 'ai_project_assistant_screen.dart';

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

  List<String> _selectedCategories = [];
  bool _isLoading = false;
  XFile? _designImage;
  Uint8List? _designImageBytes;
  bool _isPickingDesign = false;

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
    super.dispose();
  }

  String _categoryLabel(BuildContext context, String category) {
    final language = AppLocalizations.of(context);

    switch (category) {
      case 'Web Application':
        return language.locale.languageCode == 'hi'
            ? 'वेब एप्लिकेशन'
            : language.locale.languageCode == 'mr'
            ? 'वेब ॲप्लिकेशन'
            : 'Web Application';

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

  Future<void> _pickDesignImage() async {
    if (_isPickingDesign) return;

    setState(() {
      _isPickingDesign = true;
    });

    try {
      final picker = ImagePicker();

      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (!mounted || image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        _designImage = image;
        _designImageBytes = bytes;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project design selected successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to select the design image.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      debugPrint('Design image selection error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingDesign = false;
        });
      }
    }
  }

  Future<void> _createProject() async {
    final l10n = AppLocalizations.of(context);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.category),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        'categories': _selectedCategories,
        'description': _descriptionController.text.trim(),
        'requirements': _requirementsController.text.trim(),
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
            'title': 'Get Project Estimate',
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

  Future<void> _openAIAssistant(String target) async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the project title first.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one project category.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (target == 'design' &&
        _requirementsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please add project requirements first so AI can design the pages.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => AIProjectAssistantScreen(
          title: _titleController.text.trim(),
          categories: List<String>.from(_selectedCategories),
          description: _descriptionController.text.trim(),
          requirements: _requirementsController.text.trim(),
          initialTarget: target,
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _descriptionController.text =
          result['description'] ?? _descriptionController.text;

      _requirementsController.text =
          result['requirements'] ?? _requirementsController.text;
    });
  }

  Widget _aiGenerateButton(String target) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: TextButton.icon(
        onPressed: () => _openAIAssistant(target),
        icon: const Icon(
          Icons.auto_awesome_rounded,
          size: 17,
          color: Color(0xFF4F46E5),
        ),
        label: const Text(
          'Generate with AI',
          style: TextStyle(
            color: Color(0xFF4F46E5),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        ),
      ),
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
        title: const Text(
          'Get Project Estimate',
          style: TextStyle(
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
                                  Icons.auto_awesome_rounded,
                                  color: Color(0xFFA5B4FC),
                                  size: 27,
                                ),
                              ),
                              const SizedBox(width: 15),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PROJECT ESTIMATE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        color: Color(0xFFA5B4FC),
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Get Project Estimate',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Tell us about your project and let AI help prepare an initial estimate.',
                                      style: TextStyle(
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
                              const Text(
                                'Project Information',
                                style: TextStyle(
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

                              Text(
                                l10n.category,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF344054),
                                ),
                              ),

                              const SizedBox(height: 8),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Column(
                                  children: _categories.map((category) {
                                    final selected = _selectedCategories
                                        .contains(category);

                                    return CheckboxListTile(
                                      value: selected,
                                      onChanged: (value) {
                                        setState(() {
                                          if (value == true) {
                                            _selectedCategories.add(category);
                                          } else {
                                            _selectedCategories.remove(
                                              category,
                                            );
                                          }
                                        });
                                      },
                                      title: Text(
                                        _categoryLabel(context, category),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF344054),
                                        ),
                                      ),
                                      activeColor: const Color(0xFF4F46E5),
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                      dense: true,
                                    );
                                  }).toList(),
                                ),
                              ),

                              if (_selectedCategories.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: _selectedCategories
                                      .map(
                                        (category) => Chip(
                                          label: Text(
                                            _categoryLabel(context, category),
                                          ),
                                          deleteIcon: const Icon(
                                            Icons.close,
                                            size: 16,
                                          ),
                                          onDeleted: () {
                                            setState(() {
                                              _selectedCategories.remove(
                                                category,
                                              );
                                            });
                                          },
                                          backgroundColor: const Color(
                                            0xFFEEF2FF,
                                          ),
                                          side: BorderSide.none,
                                          labelStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF4338CA),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
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
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l10n.description.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ),
                                  _aiGenerateButton('description'),
                                ],
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

                              const SizedBox(height: 20),

                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l10n.requirements.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                  ),
                                  _aiGenerateButton('requirements'),
                                ],
                              ),

                              const SizedBox(height: 5),

                              const Text(
                                'Project Requirements & Features',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                  letterSpacing: -0.3,
                                ),
                              ),

                              const SizedBox(height: 18),

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

                              const SizedBox(height: 22),

                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE0E7FF),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.design_services_rounded,
                                          color: Color(0xFF4F46E5),
                                          size: 22,
                                        ),
                                        SizedBox(width: 9),
                                        Expanded(
                                          child: Text(
                                            'Project Design',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 7),

                                    const Text(
                                      'Upload a UI design, or generate a multi-page software '
                                      'mockup from your requirements with AI.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                        color: Color(0xFF667085),
                                      ),
                                    ),

                                    const SizedBox(height: 15),

                                    if (_designImageBytes != null) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(
                                          _designImageBytes!,
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.contain,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return const SizedBox(
                                                  height: 100,
                                                  child: Center(
                                                    child: Text(
                                                      'Unable to preview this image.',
                                                    ),
                                                  ),
                                                );
                                              },
                                        ),
                                      ),

                                      const SizedBox(height: 12),
                                    ],

                                    SizedBox(
                                      width: double.infinity,
                                      height: 46,
                                      child: OutlinedButton.icon(
                                        onPressed: _isPickingDesign
                                            ? null
                                            : _pickDesignImage,
                                        icon: _isPickingDesign
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : Icon(
                                                _designImage == null
                                                    ? Icons
                                                          .cloud_upload_outlined
                                                    : Icons.edit_outlined,
                                              ),
                                        label: Text(
                                          _isPickingDesign
                                              ? 'Selecting Design...'
                                              : _designImage == null
                                              ? 'Upload Project Design'
                                              : 'Change Design',
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(
                                            0xFF4F46E5,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFF818CF8),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 46,
                                      child: FilledButton.icon(
                                        onPressed: () =>
                                            _openAIAssistant('design'),
                                        icon: const Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Generate Design with AI',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF4F46E5,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    if (_designImage != null) ...[
                                      const SizedBox(height: 8),

                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _designImage = null;
                                              _designImageBytes = null;
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                          ),
                                          label: const Text('Remove Design'),
                                          style: TextButton.styleFrom(
                                            foregroundColor: const Color(
                                              0xFFDC2626,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              const SizedBox(height: 14),

                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _openAIAssistant('requirements'),
                                  icon: const Icon(
                                    Icons.auto_awesome_rounded,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Generate with AI',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF4F46E5),
                                    backgroundColor: const Color(0xFFF5F3FF),
                                    side: const BorderSide(
                                      color: Color(0xFFE0E7FF),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
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
                                  : const Row(
                                      key: ValueKey('estimate'),
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 21,
                                        ),
                                        SizedBox(width: 9),
                                        Text(
                                          'Get Project Estimate',
                                          style: TextStyle(
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
