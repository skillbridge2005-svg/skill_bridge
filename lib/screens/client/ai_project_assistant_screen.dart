import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../localization/app_localizations.dart';
import 'initial_project_estimate_screen.dart';

// ================================================================
// DESIGN TOKENS — MATCH CLIENT HOME THEME
// ================================================================

const _kPrimaryBlue = Color(0xFF2563EB);
const _kSecondaryIndigo = Color(0xFF4F46E5);
const _kTextDark = Color(0xFF101828);
const _kTextSecondary = Color(0xFF667085);
const _kBackground = Color(0xFFF5F7FB);
const _kCardBorder = Color(0xFFE5EAF2);
const _kSelectedBackground = Color(0xFFEFF4FF);

class AIProjectAssistantScreen extends StatefulWidget {
  final String title;
  final List<String> categories;
  final String description;
  final String requirements;
  final String initialTarget;

  const AIProjectAssistantScreen({
    super.key,
    required this.title,
    required this.categories,
    required this.description,
    required this.requirements,
    required this.initialTarget,
  });

  @override
  State<AIProjectAssistantScreen> createState() =>
      _AIProjectAssistantScreenState();
}

class _AIProjectAssistantScreenState extends State<AIProjectAssistantScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _requirementsController;
  late final TextEditingController _technologiesController;

  bool _analyzing = false;
  bool _analyzed = false;

  bool _generatingDescription = false;
  bool _generatingRequirements = false;
  bool _generatingTechnologies = false;

  List<_GeneratedDesignPage> _generatedPages = [];
  int _designPageIndex = 0;
  bool _generatingDesign = false;

  String _analysis = '';

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.title);
    _descriptionController = TextEditingController(text: widget.description);
    _requirementsController = TextEditingController(text: widget.requirements);

    _technologiesController = TextEditingController(
      text: 'Flutter, Firebase, Firestore, REST API',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (widget.initialTarget == 'design') {
        _generateDesign();
      } else if (widget.initialTarget == 'description' ||
          widget.initialTarget == 'requirements' ||
          widget.initialTarget == 'technologies') {
        _generateDescription();
        _generateRequirements();
        _generateTechnologies();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _technologiesController.dispose();

    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _kTextDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  List<_GeneratedDesignPage> _pagesFromResponse(Map<String, dynamic> data) {
    final rawImages = data['images'];
    final pages = <_GeneratedDesignPage>[];

    if (rawImages is List) {
      for (final item in rawImages) {
        if (item is! Map) continue;

        final page = Map<String, dynamic>.from(item);
        final encoded = page['imageBase64']?.toString() ?? '';
        if (encoded.isEmpty) continue;

        pages.add(
          _GeneratedDesignPage(
            label: page['label']?.toString() ?? 'Screen ${pages.length + 1}',
            purpose: page['purpose']?.toString() ?? '',
            bytes: base64Decode(encoded),
          ),
        );
      }
    }

    if (pages.isEmpty) {
      final encoded = data['imageBase64']?.toString() ?? '';
      if (encoded.isNotEmpty) {
        pages.add(
          _GeneratedDesignPage(
            label: 'Project Design',
            purpose: '',
            bytes: base64Decode(encoded),
          ),
        );
      }
    }

    return pages;
  }

  Future<void> _generateDesign() async {
    if (_generatingDesign) return;

    if (_titleController.text.trim().isEmpty) {
      _showMessage('Please enter the project title first.');
      return;
    }

    if (_requirementsController.text.trim().isEmpty) {
      _showMessage(
        'Please generate or enter project requirements first so AI can design the pages.',
      );
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      _showMessage('Please log in to generate a project design.');
      return;
    }

    setState(() {
      _generatingDesign = true;
    });

    try {
      debugPrint('AI DESIGN: Starting multi-page design generation');

      final HttpsCallable callable = _functions.httpsCallable(
        'generateProjectDesign',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 240)),
      );

      final result = await callable.call(<String, dynamic>{
        'title': _titleController.text.trim(),
        'categories': widget.categories,
        'description': _descriptionController.text.trim(),
        'requirements': _requirementsController.text.trim(),
        'technologies': _technologiesController.text.trim(),
      });

      if (!mounted) return;

      final raw = result.data;

      if (raw is! Map) {
        throw Exception('Invalid response from the design-generation service.');
      }

      final data = Map<String, dynamic>.from(raw);

      if (data['success'] != true) {
        throw Exception('The AI could not generate the design.');
      }

      final pages = _pagesFromResponse(data);

      if (pages.isEmpty) {
        throw Exception('The AI returned no design pages.');
      }

      setState(() {
        _generatedPages = pages;
        _designPageIndex = 0;
        _analyzed = false;
        _analysis = '';
      });

      _showMessage(
        '${pages.length} software pages were generated from your requirements.',
      );
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint('AI DESIGN FUNCTION ERROR');
      debugPrint('Code: ${error.code}');
      debugPrint('Message: ${error.message}');
      debugPrint('Details: ${error.details}');
      debugPrintStack(stackTrace: stackTrace);

      _showMessage(_friendlyError(error));
    } catch (error, stackTrace) {
      debugPrint('AI DESIGN ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);

      _showMessage('Unable to generate the design. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _generatingDesign = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is FirebaseFunctionsException) {
      switch (error.code) {
        case 'unauthenticated':
          return 'Please log in before using the AI Project Assistant.';

        case 'invalid-argument':
          return error.message ?? 'Please check your project information.';

        case 'failed-precondition':
          return error.message ?? 'AI generation is not configured correctly.';

        case 'unavailable':
          return 'The AI service is unavailable. Please try again.';

        case 'deadline-exceeded':
          return 'AI generation took too long. Please try again.';

        case 'resource-exhausted':
          return 'The AI service has reached a usage limit. Try again later.';

        case 'internal':
          return error.message ??
              'An internal error occurred while generating content.';

        default:
          return error.message ??
              'Unable to connect to the AI service. Please try again.';
      }
    }

    return 'Something went wrong. Please check your connection and try again.';
  }

  Future<String?> _generateAIContent(String contentType) async {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      _showMessage('Please enter the project title first.');
      return null;
    }

    if (title.length > 150) {
      _showMessage('The project title must be 150 characters or fewer.');
      return null;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      _showMessage('Please log in to use the AI Project Assistant.');
      return null;
    }

    try {
      final HttpsCallable callable = _functions.httpsCallable(
        'generateProjectContent',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

      final result = await callable.call(<String, dynamic>{
        'title': title,
        'categories': widget.categories,
        'description': _descriptionController.text.trim(),
        'requirements': _requirementsController.text.trim(),
        'contentType': contentType,
      });

      final raw = result.data;
      if (raw is! Map) {
        throw Exception('The AI service returned an invalid response.');
      }

      final data = Map<String, dynamic>.from(raw);
      final content = data['content']?.toString().trim() ?? '';

      if (data['success'] != true || content.isEmpty) {
        throw Exception('The AI service returned no content.');
      }

      return content;
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint('========== AI FUNCTION ERROR ==========');
      debugPrint('Content type: $contentType');
      debugPrint('Error code: ${error.code}');
      debugPrint('Error message: ${error.message}');
      debugPrint('Error details: ${error.details}');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('=======================================');

      _showMessage(_friendlyError(error));
      return null;
    } catch (error, stackTrace) {
      debugPrint('========== AI UNEXPECTED ERROR ==========');
      debugPrint('Error type: ${error.runtimeType}');
      debugPrint('Error: $error');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('========================================');

      _showMessage('Unable to generate content. Please try again.');
      return null;
    }
  }

  Future<void> _generateDescription() async {
    debugPrint('AI DEBUG: Generate Description button tapped');

    if (_generatingDescription) {
      debugPrint('AI DEBUG: Generation already in progress');
      return;
    }

    setState(() {
      _generatingDescription = true;
    });

    try {
      debugPrint('AI DEBUG: Calling Gemini function');

      final content = await _generateAIContent('description');

      debugPrint('AI DEBUG: Response received: ${content != null}');

      if (!mounted) return;

      if (content != null) {
        setState(() {
          _descriptionController.text = content;
          _analyzed = false;
          _analysis = '';
        });

        _showMessage('Project description generated successfully.');
      }
    } catch (error, stackTrace) {
      debugPrint('AI DEBUG: Unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);

      _showMessage('Unable to generate content. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _generatingDescription = false;
        });
      }
    }
  }

  Future<void> _generateRequirements() async {
    if (_generatingRequirements) return;

    setState(() {
      _generatingRequirements = true;
    });

    try {
      final content = await _generateAIContent('requirements');

      if (!mounted) return;

      if (content != null) {
        setState(() {
          _requirementsController.text = content;
          _analyzed = false;
          _analysis = '';
        });

        _showMessage('Project requirements generated successfully.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _generatingRequirements = false;
        });
      }
    }
  }

  Future<void> _generateTechnologies() async {
    if (_generatingTechnologies) return;

    setState(() {
      _generatingTechnologies = true;
    });

    try {
      final content = await _generateAIContent('technologies');

      if (!mounted) return;

      if (content != null) {
        setState(() {
          _technologiesController.text = content;
          _analyzed = false;
          _analysis = '';
        });

        _showMessage('Technology recommendations generated successfully.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _generatingTechnologies = false;
        });
      }
    }
  }

  Future<void> _analyzeProject() async {
    if (_analyzing) return;

    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _requirementsController.text.trim().isEmpty) {
      _showMessage(
        'Please complete the project title, description, and requirements.',
      );
      return;
    }

    setState(() {
      _analyzing = true;
    });

    try {
      final content = await _generateAIContent('analysis');

      if (!mounted) return;

      if (content != null) {
        setState(() {
          _analysis = content;
          _analyzed = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _analyzing = false;
        });
      }
    }
  }

  // ================================================================
  // REUSABLE THEME STYLES
  // ================================================================

  InputDecoration _fieldDecoration({
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      alignLabelWithHint: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: const TextStyle(color: _kTextSecondary),
      hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kCardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kCardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _kPrimaryBlue, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.6),
      ),
      counterStyle: const TextStyle(color: _kTextSecondary),
    );
  }

  ButtonStyle _primaryButtonStyle({
    double radius = 14,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 14,
    ),
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: _kPrimaryBlue,
      foregroundColor: Colors.white,
      disabledBackgroundColor: const Color(0xFFB8CCF8),
      disabledForegroundColor: Colors.white,
      elevation: 0,
      padding: padding,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _kSelectedBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 21, color: _kPrimaryBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _kTextDark,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _editableField({
    required String label,
    required TextEditingController controller,
    required int maxLines,
    required VoidCallback onGenerate,
    required String buttonText,
    bool isGenerating = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: _kTextDark,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, height: 1.5, color: _kTextDark),
          decoration: _fieldDecoration(
            suffixIcon: IconButton(
              onPressed: () {
                debugPrint('AI DEBUG: Sparkle icon tapped');
                debugPrint('AI DEBUG: Button text = $buttonText');
                debugPrint('AI DEBUG: Is generating = $isGenerating');

                if (isGenerating) {
                  debugPrint(
                    'AI DEBUG: Button disabled because generation is running',
                  );
                  return;
                }

                debugPrint('AI DEBUG: Executing onGenerate callback');
                onGenerate();
              },
              tooltip: buttonText,
              icon: isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kPrimaryBlue,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, color: _kPrimaryBlue),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              isGenerating ? Icons.hourglass_top : Icons.auto_awesome,
              size: 15,
              color: _kPrimaryBlue,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isGenerating
                    ? 'Generating with Gemini AI...'
                    : 'Tap the sparkle icon to generate with AI.',
                style: const TextStyle(fontSize: 12, color: _kTextSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _kSelectedBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _kPrimaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: _kTextDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _estimatePreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kCardBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_outlined, color: _kPrimaryBlue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Initial Project Estimate',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _kTextDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your project has been analyzed. Use the results to help '
            'prepare an initial development estimate.',
            style: TextStyle(color: _kTextSecondary, height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kSelectedBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'This analysis is advisory only. Validate the project scope, '
              'development effort, and service costs before deciding the final price.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: _kTextDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('AI DEBUG: AIProjectAssistantScreen build() executed');

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        title: Text(
          l10n.aiProjectAssistant,
          style: const TextStyle(
            color: _kTextDark,
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),
        backgroundColor: _kBackground,
        foregroundColor: _kTextDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _AmbientPainter()),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      colors: [_kPrimaryBlue, _kSecondaryIndigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x222563EB),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.20),
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'AI Project Assistant',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create project descriptions, detailed requirements, '
                        'and technology recommendations using Gemini AI.',
                        style: TextStyle(
                          color: Color(0xFFEFF4FF),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                _sectionTitle(
                  'Project Information',
                  Icons.description_outlined,
                ),

                const SizedBox(height: 14),

                _infoCard(
                  title: 'Selected Categories',
                  value: widget.categories.isEmpty
                      ? 'No categories selected'
                      : widget.categories.join(', '),
                  icon: Icons.category_outlined,
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: _titleController,
                  maxLength: 150,
                  style: const TextStyle(color: _kTextDark, fontSize: 14),
                  decoration: _fieldDecoration(
                    labelText: 'Project Title',
                    prefixIcon: const Icon(Icons.title, color: _kPrimaryBlue),
                  ),
                  onChanged: (_) {
                    if (_analyzed) {
                      setState(() {
                        _analyzed = false;
                        _analysis = '';
                      });
                    }
                  },
                ),

                const SizedBox(height: 25),

                _sectionTitle('Project Description', Icons.article_outlined),

                const SizedBox(height: 14),

                _editableField(
                  label: 'Description',
                  controller: _descriptionController,
                  maxLines: 6,
                  onGenerate: _generateDescription,
                  buttonText: 'Generate description with AI',
                  isGenerating: _generatingDescription,
                ),

                const SizedBox(height: 25),

                _sectionTitle('Project Requirements', Icons.checklist_outlined),

                const SizedBox(height: 14),

                _editableField(
                  label: 'Requirements',
                  controller: _requirementsController,
                  maxLines: 7,
                  onGenerate: _generateRequirements,
                  buttonText: 'Generate requirements with AI',
                  isGenerating: _generatingRequirements,
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _generatingRequirements
                        ? null
                        : _generateRequirements,
                    icon: _generatingRequirements
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _kPrimaryBlue,
                            ),
                          )
                        : const Icon(Icons.auto_awesome, color: _kPrimaryBlue),
                    label: Text(
                      _generatingRequirements
                          ? 'Generating Requirements...'
                          : 'Generate Requirements with AI',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kPrimaryBlue,
                      side: const BorderSide(color: _kPrimaryBlue),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                _sectionTitle('Suggested Technologies', Icons.code_outlined),

                const SizedBox(height: 14),

                _editableField(
                  label: 'Technologies / Skills',
                  controller: _technologiesController,
                  maxLines: 5,
                  onGenerate: _generateTechnologies,
                  buttonText: 'Suggest technologies with AI',
                  isGenerating: _generatingTechnologies,
                ),

                const SizedBox(height: 25),

                _sectionTitle('AI Project Design', Icons.auto_awesome),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: Colors.white,
                    border: Border.all(color: _kCardBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x080F172A),
                        blurRadius: 16,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _kSelectedBackground,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.palette_outlined,
                          size: 26,
                          color: _kPrimaryBlue,
                        ),
                      ),

                      const SizedBox(height: 14),

                      const Text(
                        'Generate Your Project Design',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _kTextDark,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'AI will turn your requirements into a multi-page software '
                        'design: several key screens as high-fidelity UI images.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: _kTextSecondary,
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (_generatedPages.isNotEmpty) ...[
                        Text(
                          _generatedPages[_designPageIndex].label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: _kTextDark,
                          ),
                        ),
                        if (_generatedPages[_designPageIndex]
                            .purpose
                            .isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _generatedPages[_designPageIndex].purpose,
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: _kTextSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 420,
                          child: PageView.builder(
                            itemCount: _generatedPages.length,
                            onPageChanged: (index) {
                              setState(() {
                                _designPageIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              final page = _generatedPages[index];
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: ColoredBox(
                                  color: const Color(0xFFF8FAFC),
                                  child: Image.memory(
                                    page.bytes,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Padding(
                                        padding: EdgeInsets.all(20),
                                        child: Text(
                                          'Unable to display this page image.',
                                          style: TextStyle(
                                            color: _kTextSecondary,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_generatedPages.length, (
                            index,
                          ) {
                            final selected = index == _designPageIndex;
                            return Container(
                              width: selected ? 18 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: selected ? _kPrimaryBlue : _kCardBorder,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF16A34A),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Multi-page design ready • '
                                '${_designPageIndex + 1} of ${_generatedPages.length}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _kTextDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _generatingDesign ? null : _generateDesign,
                          icon: _generatingDesign
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _generatedPages.isEmpty
                                      ? Icons.auto_awesome
                                      : Icons.refresh,
                                ),
                          label: Text(
                            _generatingDesign
                                ? 'Generating Multi-page Design...'
                                : _generatedPages.isEmpty
                                ? 'Generate Design with AI'
                                : 'Regenerate Pages',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: _primaryButtonStyle(
                            radius: 14,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),

                      if (_generatingDesign) ...[
                        const SizedBox(height: 12),
                        const LinearProgressIndicator(
                          color: _kPrimaryBlue,
                          backgroundColor: _kSelectedBackground,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'AI is designing multiple software pages from your '
                          'requirements. This can take a minute.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: _kTextSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed:
                        _analyzing ||
                            _generatingDescription ||
                            _generatingRequirements ||
                            _generatingTechnologies ||
                            _generatingDesign
                        ? null
                        : _analyzeProject,
                    icon: _analyzing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.psychology_outlined),
                    label: Text(
                      _analyzing
                          ? 'Analyzing Requirements...'
                          : 'Analyze Project with AI',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: _primaryButtonStyle(radius: 15),
                  ),
                ),

                if (_analyzed) ...[
                  const SizedBox(height: 25),

                  _sectionTitle('AI Analysis', Icons.psychology_outlined),

                  const SizedBox(height: 14),

                  _infoCard(
                    title: 'AI Project Analysis',
                    value: _analysis,
                    icon: Icons.auto_awesome,
                  ),

                  const SizedBox(height: 20),

                  _estimatePreview(),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => InitialProjectEstimateScreen(
                              title: _titleController.text.trim(),
                              categories: widget.categories,
                              description: _descriptionController.text.trim(),
                              requirements: _requirementsController.text.trim(),
                              technologies: _technologiesController.text.trim(),
                              analysis: _analysis,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text(
                        'Continue to Initial Estimate',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: _primaryButtonStyle(radius: 15),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0x0D2563EB);
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.10),
      190,
      paint,
    );

    paint.color = const Color(0x087C3AED);
    canvas.drawCircle(
      Offset(size.width * 0.04, size.height * 0.76),
      150,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter oldDelegate) => false;
}

class _GeneratedDesignPage {
  final String label;
  final String purpose;
  final Uint8List bytes;

  const _GeneratedDesignPage({
    required this.label,
    required this.purpose,
    required this.bytes,
  });
}
