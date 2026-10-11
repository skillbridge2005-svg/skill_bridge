import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../localization/app_localizations.dart';

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
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
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

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
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
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.all(14),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              isGenerating ? Icons.hourglass_top : Icons.auto_awesome,
              size: 15,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                isGenerating
                    ? 'Generating with Gemini AI...'
                    : 'Tap the sparkle icon to generate with AI.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(value, style: const TextStyle(fontSize: 14)),
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
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.secondaryContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calculate_outlined),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Initial Project Estimate',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your project has been analyzed. Use the results to help '
            'prepare an initial development estimate.',
          ),
          const SizedBox(height: 12),
          const Text(
            'This analysis is advisory only. Validate the project scope, '
            'development effort, and service costs before deciding the final price.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
      appBar: AppBar(title: Text(l10n.aiProjectAssistant)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: Theme.of(context).colorScheme.onPrimary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'AI Project Assistant',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create project descriptions, detailed requirements, '
                    'and technology recommendations using Gemini AI.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            _sectionTitle('Project Information', Icons.description_outlined),

            const SizedBox(height: 14),

            _infoCard(
              title: 'Selected Categories',
              value: widget.categories.isEmpty
                  ? 'No categories selected'
                  : widget.categories.join(', '),
              icon: Icons.category_outlined,
            ),

            const SizedBox(height: 12),

            TextField(
              controller: _titleController,
              maxLength: 150,
              decoration: const InputDecoration(
                labelText: 'Project Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  _generatingRequirements
                      ? 'Generating Requirements...'
                      : 'Generate Requirements with AI',
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.palette_outlined,
                      size: 26,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'Generate Your Project Design',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'AI will turn your requirements into a multi-page software '
                    'design: several key screens as high-fidelity UI images.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_generatedPages.isNotEmpty) ...[
                    Text(
                      _generatedPages[_designPageIndex].label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_generatedPages[_designPageIndex]
                        .purpose
                        .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _generatedPages[_designPageIndex].purpose,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
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
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              child: Image.memory(
                                page.bytes,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Padding(
                                    padding: EdgeInsets.all(20),
                                    child: Text(
                                      'Unable to display this page image.',
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
                      children: List.generate(_generatedPages.length, (index) {
                        final selected = index == _designPageIndex;
                        return Container(
                          width: selected ? 18 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
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
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Multi-page design ready • '
                            '${_designPageIndex + 1} of ${_generatedPages.length}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
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
                              child: CircularProgressIndicator(strokeWidth: 2),
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
                    ),
                  ),

                  if (_generatingDesign) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      'AI is designing multiple software pages from your '
                      'requirements. This can take a minute.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology_outlined),
                label: Text(
                  _analyzing
                      ? 'Analyzing Requirements...'
                      : 'Analyze Project with AI',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                    _showMessage(
                      'Analysis complete. Initial cost estimation '
                      'integration is not implemented yet.',
                    );
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text(
                    'Continue to Initial Estimate',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context, {
                    'description': _descriptionController.text.trim(),
                    'requirements': _requirementsController.text.trim(),
                    'technologies': _technologiesController.text.trim(),
                  });
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  'Use This Content',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
