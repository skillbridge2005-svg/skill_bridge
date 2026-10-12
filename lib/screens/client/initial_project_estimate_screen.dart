import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'project_estimate_result_screen.dart';

const _kPrimaryBlue = Color(0xFF2563EB);
const _kSecondaryIndigo = Color(0xFF4F46E5);
const _kTextDark = Color(0xFF101828);
const _kTextSecondary = Color(0xFF667085);
const _kBackground = Color(0xFFF5F7FB);
const _kCardBorder = Color(0xFFE5EAF2);
const _kSelectedBackground = Color(0xFFEFF4FF);

class InitialProjectEstimateScreen extends StatefulWidget {
  final String? projectId;
  final String title;
  final List<String> categories;
  final String description;
  final String requirements;
  final String technologies;
  final dynamic analysis;

  const InitialProjectEstimateScreen({
    super.key,
    this.projectId,
    required this.title,
    required this.categories,
    required this.description,
    required this.requirements,
    required this.technologies,
    required this.analysis,
  });

  @override
  State<InitialProjectEstimateScreen> createState() =>
      _InitialProjectEstimateScreenState();
}

class _InitialProjectEstimateScreenState
    extends State<InitialProjectEstimateScreen> {
  Map<String, dynamic>? _generatedPlan;
  bool _isGenerating = false;

  Future<void> _generateEstimate() async {
    if (_isGenerating) return;

    setState(() {
      _isGenerating = true;
    });

    try {
      // Existing backend call: intentionally unchanged.
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateAIProjectPlan',
      );

      final result = await callable.call({
        'mode': 'initial',
        'title': widget.title,
        'categories': widget.categories,
        'description': widget.description,
        'requirements': widget.requirements,
        'technologies': widget.technologies,
        'analysis': widget.analysis.toString(),
      });

      debugPrint('INITIAL ESTIMATE RESPONSE: ${result.data}');

      if (!mounted) return;

      if (result.data is! Map) {
        throw Exception('Invalid response from server. Expected a map.');
      }

      final data = Map<String, dynamic>.from(result.data as Map);
      final rawPlan = data['plan'];

      if (rawPlan is! Map) {
        debugPrint('INITIAL ESTIMATE RESPONSE KEYS: ${data.keys.toList()}');

        throw Exception(
          'The server response does not contain a valid '
          '"plan" object. Check the Debug Console.',
        );
      }

      final plan = Map<String, dynamic>.from(rawPlan);

      debugPrint('INITIAL ESTIMATE PLAN KEYS: ${plan.keys.toList()}');

      // Preserve the existing generated-plan display.
      setState(() {
        _generatedPlan = plan;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Initial estimate generated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // NEW: Open the client-facing page after successful generation.
      // If no real project ID exists, retain the old screen behavior.
      final projectId = widget.projectId?.trim();

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => ProjectEstimateResultScreen(
            projectId: widget.projectId,
            title: widget.title,
            categories: widget.categories,
            description: widget.description,
            requirements: widget.requirements,
            technologies: widget.technologies,
            plan: plan,
            planId: data['planId']?.toString(),
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('INITIAL ESTIMATE FIREBASE ERROR: ${e.code} - ${e.message}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estimate failed: ${e.message ?? e.code}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('INITIAL ESTIMATE ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        title: const Text(
          'Initial Project Estimate',
          style: TextStyle(color: _kTextDark, fontWeight: FontWeight.w800),
        ),
        backgroundColor: _kBackground,
        foregroundColor: _kTextDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.calculate_outlined,
                      color: Colors.white,
                      size: 34,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Plan your project realistically',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'AI will plan the work, identify the minimum '
                      'required team, and estimate a price range '
                      'and a timeline range.',
                      style: TextStyle(color: Color(0xFFEFF4FF), height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _sectionTitle('Project Overview', Icons.description_outlined),
              const SizedBox(height: 12),

              _infoCard('Project Title', widget.title, Icons.title),
              const SizedBox(height: 12),

              _infoCard(
                'Categories',
                widget.categories.isEmpty
                    ? 'No categories selected'
                    : widget.categories.join(', '),
                Icons.category_outlined,
              ),
              const SizedBox(height: 12),

              _infoCard(
                'Project Description',
                widget.description,
                Icons.article_outlined,
              ),
              const SizedBox(height: 12),

              _infoCard(
                'Requirements',
                widget.requirements,
                Icons.checklist_outlined,
              ),
              const SizedBox(height: 12),

              _infoCard(
                'Suggested Technologies',
                widget.technologies,
                Icons.code_outlined,
              ),

              const SizedBox(height: 24),

              _sectionTitle('AI Project Analysis', Icons.psychology_outlined),
              const SizedBox(height: 12),

              _infoCard(
                'Analysis',
                widget.analysis.toString(),
                Icons.auto_awesome,
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _kCardBorder),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What the estimate will include',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _kTextDark,
                      ),
                    ),
                    SizedBox(height: 14),
                    _FeatureRow(
                      icon: Icons.list_alt,
                      text: 'Task and subtask breakdown',
                    ),
                    _FeatureRow(
                      icon: Icons.people_outline,
                      text: 'Required developer roles and team size',
                    ),
                    _FeatureRow(
                      icon: Icons.calendar_month_outlined,
                      text: 'Estimated timeline range',
                    ),
                    _FeatureRow(
                      icon: Icons.currency_rupee,
                      text: 'Estimated project price range',
                    ),
                    _FeatureRow(
                      icon: Icons.public,
                      text: 'Research sources and estimate confidence',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kSelectedBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Estimates are planning ranges, not guaranteed '
                  'prices or delivery dates. Validate assumptions '
                  'and market rates before committing.',
                  style: TextStyle(
                    color: _kTextDark,
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
              ),

              // Preserve all existing generated-plan cards.
              if (_generatedPlan != null) ...[
                const SizedBox(height: 28),

                _sectionTitle('Generated AI Project Plan', Icons.auto_awesome),
                const SizedBox(height: 12),

                _infoCard(
                  'Project Summary',
                  _displayValue(_generatedPlan!['projectSummary']),
                  Icons.description_outlined,
                ),
                const SizedBox(height: 12),

                _infoCard(
                  'Research Findings',
                  _displayValue(_generatedPlan!['researchFindings']),
                  Icons.travel_explore_outlined,
                ),
                const SizedBox(height: 12),

                _infoCard(
                  'Confirmed Requirements',
                  _displayValue(_generatedPlan!['confirmedRequirements']),
                  Icons.checklist_outlined,
                ),
                const SizedBox(height: 12),

                _infoCard(
                  'Recommended Architecture',
                  _displayValue(_generatedPlan!['recommendedArchitecture']),
                  Icons.account_tree_outlined,
                ),
                const SizedBox(height: 12),

                _infoCard(
                  'Modules and Tasks',
                  _displayValue(_generatedPlan!['modules']),
                  Icons.view_module_outlined,
                ),
                const SizedBox(height: 12),

                _infoCard(
                  'Team Recommendation',
                  _displayValue(_generatedPlan!['team']),
                  Icons.people_outline,
                ),
                const SizedBox(height: 12),

                _infoCard(
                  'Effort, Cost and Timeline Estimate',
                  _displayValue(_generatedPlan!['estimate']),
                  Icons.currency_rupee,
                ),
                const SizedBox(height: 12),

                _infoCard(
                  'Delivery Phases',
                  _displayValue(_generatedPlan!['deliveryPhases']),
                  Icons.calendar_month_outlined,
                ),
                const SizedBox(height: 12),

                _infoCard(
                  'Risks',
                  _displayValue(_generatedPlan!['risks']),
                  Icons.warning_amber_outlined,
                ),
                const SizedBox(height: 12),

                _infoCard(
                  'Clarification Questions',
                  _displayValue(_generatedPlan!['clarificationQuestions']),
                  Icons.help_outline,
                ),
                const SizedBox(height: 12),

                _infoCard(
                  'Estimate Confidence',
                  _displayValue(_generatedPlan!['overallConfidence']),
                  Icons.verified_outlined,
                ),
              ],

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateEstimate,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _isGenerating
                        ? 'Generating Estimate...'
                        : _generatedPlan == null
                        ? 'Generate Initial Estimate'
                        : 'Regenerate Estimate',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _kPrimaryBlue.withValues(
                      alpha: 0.65,
                    ),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _displayValue(dynamic value) {
    if (value == null) return 'Not available';

    if (value is String) {
      return value.trim().isEmpty ? 'Not available' : value;
    }

    if (value is List) {
      if (value.isEmpty) return 'None listed';

      return value
          .map((item) {
            if (item is Map) {
              return item.entries
                  .map((entry) => '${entry.key}: ${entry.value}')
                  .join('\n');
            }

            return item.toString();
          })
          .join('\n\n');
    }

    if (value is Map) {
      if (value.isEmpty) return 'Not available';

      return value.entries
          .map((entry) {
            final item = entry.value;

            if (item is Map || item is List) {
              return '${entry.key}:\n${_displayValue(item)}';
            }

            return '${entry.key}: ${item ?? 'Not available'}';
          })
          .join('\n\n');
    }

    return value.toString();
  }

  static Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _kSelectedBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _kPrimaryBlue),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _kTextDark,
            ),
          ),
        ),
      ],
    );
  }

  static Widget _infoCard(String title, String value, IconData icon) {
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
            width: 40,
            height: 40,
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
                  value.trim().isEmpty ? 'Not provided' : value,
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
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _kPrimaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: _kTextDark),
            ),
          ),
        ],
      ),
    );
  }
}
