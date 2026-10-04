import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';

class AIProjectAssistantScreen extends StatefulWidget {
  const AIProjectAssistantScreen({super.key});

  @override
  State<AIProjectAssistantScreen> createState() =>
      _AIProjectAssistantScreenState();
}

class _AIProjectAssistantScreenState extends State<AIProjectAssistantScreen> {
  final TextEditingController _controller = TextEditingController();

  String? generatedTitle;
  String? generatedDescription;
  String? generatedSkills;

  void _generateProject() {
    final l10n = AppLocalizations.of(context);

    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.describeProject)));
      return;
    }

    setState(() {
      generatedTitle = 'Website / Application Project';
      generatedDescription = _controller.text.trim();
      generatedSkills = 'Flutter, Backend, Database';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.aiProjectAssistant)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    l10n.aiProjectAssistant,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.shareIdea),
                ],
              ),
            ),

            const SizedBox(height: 25),

            Text(
              l10n.describeProject,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: _controller,
              maxLines: 7,
              decoration: InputDecoration(
                hintText: 'Example: I need a website for my grocery shop where customers can view products and place orders.',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _generateProject,
                icon: const Icon(Icons.auto_awesome),
                label: Text(
                  l10n.generateProject,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),

            if (generatedTitle != null) ...[
              const SizedBox(height: 30),

              Text(
                'Generated Project',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Title',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 6),

                      Text(generatedTitle!),

                      const SizedBox(height: 18),

                      const Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 6),

                      Text(generatedDescription!),

                      const SizedBox(height: 18),

                      Text(
                        l10n.requiredSkill,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 6),

                      Text(generatedSkills!),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {},
                          child: Text(l10n.continueToPostProject),
                        ),
                      ),
                    ],
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
