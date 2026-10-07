import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';

class AIProjectAssistantScreen extends StatefulWidget {
  final String title;
  final List<String> categories;
  final String description;
  final String requirements;

  const AIProjectAssistantScreen({
    super.key,
    required this.title,
    required this.categories,
    required this.description,
    required this.requirements,
  });

  @override
  State<AIProjectAssistantScreen> createState() =>
      _AIProjectAssistantScreenState();
}

class _AIProjectAssistantScreenState extends State<AIProjectAssistantScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _requirementsController;

  final TextEditingController _technologiesController = TextEditingController();

  bool _analyzing = false;
  bool _analyzed = false;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.title);
    _descriptionController = TextEditingController(text: widget.description);
    _requirementsController = TextEditingController(text: widget.requirements);

    _technologiesController.text = 'Flutter, Firebase, Firestore, REST API';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _requirementsController.dispose();
    _technologiesController.dispose();
    super.dispose();
  }

  Future<void> _analyzeProject() async {
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty ||
        _requirementsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all project details.')),
      );
      return;
    }

    setState(() {
      _analyzing = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _analyzing = false;
      _analyzed = true;
    });
  }

  void _generateDescription() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the project title first.')),
      );
      return;
    }

    setState(() {
      _descriptionController.text =
          'Develop a modern $title solution with a user-friendly interface, secure backend, database integration, and scalable architecture.';
    });
  }

  void _generateRequirements() {
    final categories = widget.categories.join(', ');

    setState(() {
      _requirementsController.text =
          'The project should include a responsive user interface, secure authentication, database integration, required $categories functionality, proper error handling, testing, and deployment support.';
    });
  }

  void _generateTechnologies() {
    setState(() {
      _technologiesController.text =
          'Flutter, Firebase, Firestore, REST API, Cloud Functions';
    });
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
              onPressed: onGenerate,
              tooltip: buttonText,
              icon: const Icon(Icons.auto_awesome),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 15),
            const SizedBox(width: 5),
            Text(
              'AI suggestion available',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                Text(value, style: const TextStyle(fontSize: 14)),
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
          Row(
            children: [
              const Icon(Icons.calculate_outlined),
              const SizedBox(width: 8),
              const Text(
                'Initial Project Estimate',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'AI will analyze the project requirements and provide an initial estimated cost range.',
          ),
          const SizedBox(height: 12),
          const Text(
            'This is only a preliminary estimate. The final price will be decided after technical and service-cost validation.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    'Review your project information and let AI help structure your requirements before estimating the cost.',
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
              decoration: const InputDecoration(
                labelText: 'Project Title',
                border: OutlineInputBorder(),
              ),
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
            ),

            const SizedBox(height: 25),

            _sectionTitle('Suggested Technologies', Icons.code_outlined),

            const SizedBox(height: 14),

            _editableField(
              label: 'Technologies / Skills',
              controller: _technologiesController,
              maxLines: 3,
              onGenerate: _generateTechnologies,
              buttonText: 'Suggest technologies with AI',
            ),

            const SizedBox(height: 25),

            if (!_analyzed)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _analyzing ? null : _analyzeProject,
                  icon: _analyzing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
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
              _sectionTitle('AI Analysis', Icons.psychology_outlined),

              const SizedBox(height: 14),

              _infoCard(
                title: 'Requirement Understanding',
                value: 'The project requirements have been analyzed. AI has identified the main development areas, technologies, and technical requirements.',
                icon: Icons.psychology_outlined,
              ),

              const SizedBox(height: 12),

              _infoCard(
                title: 'Development Scope',
                value: 'Frontend, backend, database integration, API/services, testing, and deployment should be considered during the technical estimation.',
                icon: Icons.account_tree_outlined,
              ),

              const SizedBox(height: 20),

              _estimatePreview(),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text(
                    'Continue to Initial Estimate',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
