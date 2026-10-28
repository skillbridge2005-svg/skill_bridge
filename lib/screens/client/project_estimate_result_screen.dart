import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:skill_bridge/services/supabase_storage_service.dart';

import 'client_home.dart';

const _primary = Color(0xFF2563EB);
const _indigo = Color(0xFF4F46E5);
const _background = Color(0xFFF5F7FB);
const _dark = Color(0xFF101828);
const _secondary = Color(0xFF667085);
const _border = Color(0xFFE5EAF2);
const _success = Color(0xFF15803D);
const _successBg = Color(0xFFDCFCE7);
const _warningBg = Color(0xFFFFF7ED);

class ProjectEstimateResultScreen extends StatefulWidget {
  final String? projectId;
  final String title;
  final List<String> categories;
  final String description;
  final String requirements;
  final String technologies;
  final Map<String, dynamic> plan;
  final String? planId;
  final List<String> designImageUrls;
  final List<Uint8List> generatedDesignImageBytes;
  final List<Uint8List> referenceImageBytesList;
  final List<String> referenceImageNames;
  final List<String> referenceImageMimeTypes;

  const ProjectEstimateResultScreen({
    super.key,
    this.projectId,
    required this.title,
    required this.categories,
    required this.description,
    required this.requirements,
    required this.technologies,
    required this.plan,
    this.planId,
    required this.designImageUrls,
    this.generatedDesignImageBytes = const [],
    this.referenceImageBytesList = const [],
    this.referenceImageNames = const [],
    this.referenceImageMimeTypes = const [],
  });

  @override
  State<ProjectEstimateResultScreen> createState() =>
      _ProjectEstimateResultScreenState();
}

class _ProjectEstimateResultScreenState
    extends State<ProjectEstimateResultScreen> {
  bool _isSubmitting = false;
  bool _isRegenerating = false;
  bool _isGeneratingRequirementsPdf = false;
  bool _acceptedCost = false;
  bool _acceptedTimeline = false;
  bool _acceptedTerms = false;

  // null = not answered, true = Yes, false = No.
  bool? _costChoice;
  bool? _timelineChoice;

  final TextEditingController _targetBudgetController = TextEditingController();

  DateTime? _targetDeliveryDate;
  String? _submittedStatus;

  late Map<String, dynamic> _currentPlan;
  String? _currentPlanId;
  Map<String, dynamic>? _previousPlan;

  @override
  void initState() {
    super.initState();
    _currentPlan = Map<String, dynamic>.from(widget.plan);
    _currentPlanId = widget.planId;

    // Save the generated estimate as a draft on the existing project.
    // This does not accept the estimate or create a new project.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _savePlanToExistingProject();
    });
  }

  Future<void> _savePlanToExistingProject() async {
    final projectId = widget.projectId?.trim();
    if (projectId == null || projectId.isEmpty || _currentPlan.isEmpty) {
      return;
    }

    try {
      final draftData = <String, dynamic>{
        'plan': _currentPlan,
        'estimate': _estimate,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final planId = _currentPlanId?.trim();
      if (planId != null && planId.isNotEmpty) {
        draftData['planId'] = planId;
      }

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .set(draftData, SetOptions(merge: true));
    } catch (error, stackTrace) {
      // Draft-save errors must not block estimate review or acceptance.
      debugPrint('PROJECT ESTIMATE DRAFT SAVE ERROR: $error');
      debugPrint('$stackTrace');
    }
  }

  @override
  void dispose() {
    _targetBudgetController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _estimate => _asMap(_currentPlan['estimate']);

  Map<String, dynamic> get _team => _asMap(_currentPlan['team']);

  List<String> get _teamRoleNames {
    final roles = _asList(_team['roles']);

    final entries = roles.isNotEmpty
        ? roles
        : _currentPlan['team'] is List
        ? _asList(_currentPlan['team'])
        : <dynamic>[];

    final names = entries
        .map((entry) {
          if (entry is String) return entry.trim();

          final member = _asMap(entry);
          final role = _string(member['role']).trim();

          if (role.isNotEmpty) return role;

          return _string(member['name']).trim();
        })
        .where((name) => name.isNotEmpty)
        .toList();

    return names.toSet().toList();
  }

  int get _teamRoleCount => _teamRoleNames.length;

  List<dynamic> get _modules => _asList(_currentPlan['modules']);

  List<String> _featureNames(Map<String, dynamic> plan) {
    final features = <String>[];

    void addFeature(dynamic value) {
      final text = value is String
          ? value.trim()
          : _firstNonEmpty([
              _asMap(value)['name'],
              _asMap(value)['title'],
              _asMap(value)['requirement'],
            ]);

      if (text.isNotEmpty &&
          !features.any((item) => item.toLowerCase() == text.toLowerCase())) {
        features.add(text);
      }
    }

    for (final item in _asList(plan['confirmedRequirements'])) {
      addFeature(item);
    }

    for (final item in _asList(plan['modules'])) {
      final module = _asMap(item);
      addFeature(module['name'] ?? module['title']);

      for (final task in _asList(module['tasks'])) {
        addFeature(task);
      }
    }

    return features;
  }

  List<String> _technologyNames(Map<String, dynamic> plan) {
    final technologies = <String>[];

    void collect(dynamic value) {
      if (value is String) {
        for (final item in value.split(RegExp(r'[,;\n]'))) {
          final name = item.trim();
          if (name.isNotEmpty) technologies.add(name);
        }
      } else if (value is List) {
        for (final item in value) {
          collect(item);
        }
      } else if (value is Map) {
        for (final entry in value.entries) {
          final key = entry.key.toString().toLowerCase();

          if (key.contains('technolog') ||
              key.contains('techstack') ||
              key == 'stack' ||
              key.contains('framework') ||
              key.contains('language') ||
              key.contains('database') ||
              key.contains('platform')) {
            collect(entry.value);
          }
        }
      }
    }

    collect(plan['technologies']);
    collect(plan['technologyStack']);
    collect(plan['recommendedTechnologies']);
    collect(plan['recommendedArchitecture']);

    return technologies
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  List<String> _findAdded(List<String> oldItems, List<String> newItems) {
    return newItems.where((item) {
      return !oldItems.any(
        (oldItem) => oldItem.toLowerCase() == item.toLowerCase(),
      );
    }).toList();
  }

  List<String> _findRemoved(List<String> oldItems, List<String> newItems) {
    return oldItems.where((item) {
      return !newItems.any(
        (newItem) => newItem.toLowerCase() == item.toLowerCase(),
      );
    }).toList();
  }

  Widget _buildRegenerationComparison() {
    final oldPlan = _previousPlan;
    if (oldPlan == null) return const SizedBox.shrink();

    final oldEstimate = _asMap(oldPlan['estimate']);
    final newEstimate = _asMap(_currentPlan['estimate']);

    final addedFeatures = _findAdded(
      _featureNames(oldPlan),
      _featureNames(_currentPlan),
    );
    final removedFeatures = _findRemoved(
      _featureNames(oldPlan),
      _featureNames(_currentPlan),
    );
    final removedTech = _findRemoved(
      _technologyNames(oldPlan),
      _technologyNames(_currentPlan),
    );

    // Read explicit replacement recommendations from the updated plan.
    // Supported field: technologyReplacements: [{from, to, reason, benefits,
    // tradeoffs, recommended}]
    final replacements = _asList(_currentPlan['technologyReplacements'])
        .map((item) => _asMap(item))
        .where((item) {
          final from = _string(
            item['from'] ?? item['oldTechnology'] ?? item['replaces'],
          );
          final to = _string(
            item['to'] ?? item['newTechnology'] ?? item['replacement'],
          );
          return from.isNotEmpty && to.isNotEmpty;
        })
        .toList();

    String cost(Map<String, dynamic> estimate) {
      final min = _number(estimate['costMinINR']);
      final max = _number(estimate['costMaxINR']);
      final currency = _string(estimate['currency']).isEmpty
          ? 'INR'
          : _string(estimate['currency']);

      if (min != null && max != null) {
        return '${_formatCurrency(min, currency)} – '
            '${_formatCurrency(max, currency)}';
      }

      final range = _string(estimate['costRange']);
      return range.isNotEmpty ? range : 'Not available';
    }

    final oldCost = cost(oldEstimate);
    final newCost = cost(newEstimate);

    final oldTimeline = _range(
      oldEstimate['timelineMinWeeks'],
      oldEstimate['timelineMaxWeeks'],
      'weeks',
    );
    final newTimeline = _range(
      newEstimate['timelineMinWeeks'],
      newEstimate['timelineMaxWeeks'],
      'weeks',
    );

    final budgetChanged = oldCost != newCost;
    final timelineChanged = oldTimeline != newTimeline;

    Widget sectionTitle(String title, String subtitle, IconData icon) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: _secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget metricCard({
      required String title,
      required String oldValue,
      required String newValue,
      required IconData icon,
      required bool changed,
    }) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: _primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _dark,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _comparisonValue('BEFORE', oldValue),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.south_rounded, color: _secondary, size: 18),
            ),
            _comparisonValue('UPDATED', newValue),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: changed
                    ? const Color(0xFFEFF6FF)
                    : const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                changed ? 'Estimate changed' : 'No change',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: changed
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF166534),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget infoCard({
      required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required List<String> items,
    }) {
      if (items.isEmpty) return const SizedBox.shrink();

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.45,
                          color: _secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, color: color, size: 7),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: _dark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget replacementCard(Map<String, dynamic> item) {
      final from = _string(
        item['from'] ?? item['oldTechnology'] ?? item['replaces'],
      );
      final to = _string(
        item['to'] ?? item['newTechnology'] ?? item['replacement'],
      );
      final reason = _string(item['reason'] ?? item['recommendationReason']);
      final benefits = _string(item['benefits']);
      final tradeoffs = _string(item['tradeoffs'] ?? item['limitations']);
      final recommended = item['recommended'] == true;

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: recommended
                ? const Color(0xFF86EFAC)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz_rounded, color: _primary, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Technology replacement',
                    style: TextStyle(
                      color: _dark,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (recommended)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Recommended',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'REPLACING',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFBE123C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          from,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: _primary,
                    size: 21,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'USING INSTEAD',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF047857),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          to,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _dark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (reason.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Why make this change?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                reason,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: _secondary,
                ),
              ),
            ],
            if (benefits.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(
                    Icons.thumb_up_alt_outlined,
                    color: Color(0xFF15803D),
                    size: 17,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Advantages of the new option',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                benefits,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: _secondary,
                ),
              ),
            ],
            if (tradeoffs.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFB45309), size: 17),
                  SizedBox(width: 7),
                  Text(
                    'Things to consider',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _dark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                tradeoffs,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: _secondary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_arrows_rounded, color: _primary, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'What Changed in Your Project?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _dark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Understand what is being replaced, what is recommended, '
            'and which features are no longer included.',
            style: TextStyle(fontSize: 12, height: 1.55, color: _secondary),
          ),

          const SizedBox(height: 22),
          sectionTitle(
            '1. Technology Replacements',
            'What we are using instead, and why the new option may be better.',
            Icons.swap_horiz_rounded,
          ),

          if (replacements.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'No explicit technology replacement was provided '
                'in the updated plan. We will not guess which '
                'technology replaces another.',
                style: TextStyle(fontSize: 12, height: 1.55, color: _secondary),
              ),
            )
          else
            ...replacements.map(replacementCard),

          const SizedBox(height: 12),
          sectionTitle(
            '2. Budget & Delivery',
            'Compare the previous estimate with the updated estimate.',
            Icons.calendar_month_rounded,
          ),

          LayoutBuilder(
            builder: (context, constraints) {
              final budget = metricCard(
                title: 'Estimated budget',
                oldValue: oldCost,
                newValue: newCost,
                icon: Icons.account_balance_wallet_outlined,
                changed: budgetChanged,
              );

              final timeline = metricCard(
                title: 'Expected timeline',
                oldValue: oldTimeline,
                newValue: newTimeline,
                icon: Icons.schedule_rounded,
                changed: timelineChanged,
              );

              if (constraints.maxWidth < 480) {
                return Column(
                  children: [budget, const SizedBox(height: 10), timeline],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: budget),
                  const SizedBox(width: 12),
                  Expanded(child: timeline),
                ],
              );
            },
          ),

          const SizedBox(height: 22),
          sectionTitle(
            '3. Features Added',
            'New capabilities included in the updated plan.',
            Icons.add_circle_outline_rounded,
          ),
          infoCard(
            title: 'New features',
            subtitle: 'These were not listed in the previous plan.',
            icon: Icons.add_circle_outline_rounded,
            color: Colors.green.shade700,
            items: addedFeatures,
          ),
          if (addedFeatures.isEmpty)
            const Text(
              'No newly added features detected.',
              style: TextStyle(fontSize: 12, color: _secondary),
            ),

          const SizedBox(height: 18),
          sectionTitle(
            '4. Features Removed',
            'These features are no longer listed in the updated plan.',
            Icons.remove_circle_outline_rounded,
          ),
          infoCard(
            title: 'Removed features',
            subtitle: 'Review these before approving the revised scope.',
            icon: Icons.remove_circle_outline_rounded,
            color: Colors.red.shade700,
            items: removedFeatures,
          ),
          if (removedFeatures.isEmpty)
            const Text(
              'No removed features detected.',
              style: TextStyle(fontSize: 12, color: _secondary),
            ),

          const SizedBox(height: 18),
          sectionTitle(
            '5. Technologies Removed',
            'Technologies no longer listed in the updated plan.',
            Icons.delete_outline_rounded,
          ),
          infoCard(
            title: 'Removed technologies',
            subtitle: 'These are separate from confirmed replacements above.',
            icon: Icons.delete_outline_rounded,
            color: Colors.deepOrange.shade700,
            items: removedTech,
          ),
          if (removedTech.isEmpty)
            const Text(
              'No removed technologies detected.',
              style: TextStyle(fontSize: 12, color: _secondary),
            ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFF92400E),
                  size: 20,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'A recommendation is only as reliable as its supporting '
                    'project data. Review the reasons and trade-offs before '
                    'approving a technology change.',
                    style: TextStyle(
                      color: Color(0xFF78350F),
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _comparisonValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            letterSpacing: 0.5,
            fontWeight: FontWeight.w700,
            color: _secondary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w800,
            color: _dark,
          ),
        ),
      ],
    );
  }

  List<dynamic> get _phases => _asList(_currentPlan['deliveryPhases']);

  List<dynamic> get _risks => _asList(_currentPlan['risks']);

  List<dynamic> get _requirements =>
      _asList(_currentPlan['confirmedRequirements']);

  List<dynamic> get _findings => _asList(_currentPlan['researchFindings']);

  List<dynamic> get _questions =>
      _asList(_currentPlan['clarificationQuestions']);

  // Preserve the existing scope data in the confirmation record.
  // This is no longer a separate client approval/rejection action.
  List<_ScopeItem> get _scopeItems {
    final result = <_ScopeItem>[];

    if (_requirements.isNotEmpty) {
      for (var i = 0; i < _requirements.length; i++) {
        final value = _requirements[i];
        final map = _asMap(value);

        final title = value is String
            ? value.trim()
            : _firstNonEmpty([
                map['requirement'],
                map['name'],
                map['title'],
                map['description'],
                map['question'],
              ]);

        if (title.isNotEmpty) {
          result.add(
            _ScopeItem(
              key: 'requirement_$i',
              title: title,
              description: _string(map['description']),
            ),
          );
        }
      }
    } else {
      for (var i = 0; i < _modules.length; i++) {
        final module = _asMap(_modules[i]);
        final title = _firstNonEmpty([
          module['name'],
          module['title'],
          module['purpose'],
        ]);

        if (title.isNotEmpty) {
          result.add(
            _ScopeItem(
              key: 'module_$i',
              title: title,
              description: _string(module['description']),
            ),
          );
        }
      }
    }

    return result;
  }

  bool get _isAccepted => _submittedStatus == 'accepted';

  bool get _needsRegeneration =>
      _costChoice == false || _timelineChoice == false;

  Future<Uint8List> _createRequirementsPdf() async {
    final pdf = pw.Document();
    final projectTitle = _sanitizePdfText(
      widget.title.trim().isEmpty ? 'Untitled Project' : widget.title.trim(),
    );
    final projectDescription = _pdfText(widget.description);
    final projectCategories = _pdfText(widget.categories);
    final projectRequirements = _pdfText(widget.requirements);
    final projectTechnologies = _pdfText(widget.technologies);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        maxPages: 100,
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.blue700, width: 1.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'SKILLBRIDGE',
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.Text(
                'PROJECT REQUIREMENTS',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
            ),
          ),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Text(
            projectTitle,
            style: pw.TextStyle(
              fontSize: 23,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Project Requirements and Estimate',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          _pdfSection('1. Project Overview'),
          _pdfLabelValue('Project Name', projectTitle),
          _pdfLabelValue('Categories', projectCategories),
          _pdfLabelValue('Description', projectDescription),
          _pdfSection('2. Project Requirements'),
          _pdfLabelValue('Submitted Requirements', projectRequirements),
          ..._pdfDataSection('Confirmed Requirements', _requirements),
          _pdfSection('3. Technologies'),
          _pdfLabelValue('Requested Technologies', projectTechnologies),
          ..._pdfDataSection(
            'Recommended Technologies',
            _technologyNames(_currentPlan),
          ),
          ..._pdfDataSection('4. Project Modules', _modules),
          _pdfSection('5. Project Estimate'),
          ..._pdfDataSection('Estimate Details', _estimate),
          _pdfSection('6. Recommended Team'),
          ..._pdfDataSection('Team Information', _team),
          ..._pdfDataSection('Recommended Team Roles', _teamRoleNames),
          ..._pdfDataSection('7. Delivery Phases', _phases),
          ..._pdfDataSection('8. Risks and Considerations', _risks),
          ..._pdfDataSection('9. Additional Findings', _findings),
          ..._pdfDataSection('10. Questions and Clarifications', _questions),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'This document summarizes the project information and estimate '
              'available in SkillBridge at the time of generation. Final scope, '
              'budget, and timeline should be confirmed by the client and '
              'development team.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue900),
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  String _pdfText(dynamic value) {
    if (value == null) return '';
    if (value is String) return _sanitizePdfText(value.trim());

    if (value is Map) {
      return value.entries
          .map((entry) {
            final item = _pdfText(entry.value);
            if (item.isEmpty) return '';
            return '${_sanitizePdfText(_pdfPrettyLabel(entry.key.toString()))}: $item';
          })
          .where((item) => item.isNotEmpty)
          .join('\n');
    }

    if (value is Iterable) {
      return value.map(_pdfText).where((item) => item.isNotEmpty).join('\n');
    }

    return _sanitizePdfText(value.toString());
  }

  String _sanitizePdfText(String text) {
    return text
        .replaceAll('\u2014', '-')
        .replaceAll('\u2013', '-')
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'")
        .replaceAll('\u201C', '"')
        .replaceAll('\u201D', '"')
        .replaceAll('\u2026', '...')
        .replaceAll('\u2022', '-')
        .replaceAll('\u20B9', 'INR');
  }

  String _pdfPrettyLabel(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll('_', ' ')
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }

  pw.Widget _pdfSection(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18, bottom: 10),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
    );
  }

  pw.Widget _pdfLabelValue(String label, String value) {
    if (value.trim().isEmpty) return pw.SizedBox();

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
          ),
        ],
      ),
    );
  }

  List<pw.Widget> _pdfDataSection(String title, dynamic data) {
    if (data == null) return [];

    final widgets = <pw.Widget>[];
    if (data is Map) {
      final entries = data.entries.where(
        (entry) => _pdfText(entry.value).isNotEmpty,
      );
      if (entries.isEmpty) return [];

      widgets.add(_pdfSection(title));
      for (final entry in entries) {
        widgets.add(
          _pdfLabelValue(
            _pdfPrettyLabel(entry.key.toString()),
            _pdfText(entry.value),
          ),
        );
      }
      return widgets;
    }

    if (data is Iterable) {
      final items = data
          .map(_pdfText)
          .where((item) => item.isNotEmpty)
          .toList();
      if (items.isEmpty) return [];

      widgets.add(_pdfSection(title));
      for (final item in items) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, bottom: 7),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '- ',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    item,
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return widgets;
    }

    final text = _pdfText(data);
    if (text.isEmpty) return [];

    widgets
      ..add(_pdfSection(title))
      ..add(
        pw.Text(text, style: const pw.TextStyle(fontSize: 10, lineSpacing: 3)),
      );
    return widgets;
  }

  String get _requirementsPdfFileName {
    final safeTitle = widget.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    final fileTitle = safeTitle.isEmpty ? 'SkillBridge_Project' : safeTitle;
    return '${fileTitle}_Requirements.pdf';
  }

  Future<void> _handleRequirementsPdf({required bool share}) async {
    if (_isGeneratingRequirementsPdf) return;

    setState(() => _isGeneratingRequirementsPdf = true);
    try {
      final bytes = await _createRequirementsPdf();
      if (!mounted) return;

      if (share) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: _requirementsPdfFileName,
        );
      } else {
        await Printing.layoutPdf(
          name: _requirementsPdfFileName,
          onLayout: (_) async => bytes,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Requirements PDF error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to ${share ? 'share' : 'download'} PDF. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGeneratingRequirementsPdf = false);
      }
    }
  }

  Future<void> _showRequirementsPdfOptions() async {
    if (_isGeneratingRequirementsPdf) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Project Requirements PDF',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.download_rounded,
                  color: Color(0xFF2563EB),
                ),
                title: const Text('Download PDF'),
                subtitle: const Text(
                  'Open the print dialog to save the document as PDF.',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleRequirementsPdf(share: false);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.share_rounded,
                  color: Color(0xFF2563EB),
                ),
                title: const Text('Share PDF'),
                subtitle: const Text(
                  'Share the generated requirements document.',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _handleRequirementsPdf(share: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = _string(_estimate['currency']).isEmpty
        ? 'INR'
        : _string(_estimate['currency']);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        toolbarHeight: 82,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: _background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _dark,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5EAF2)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x070F172A),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                // Back button
                Material(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Project estimate icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.request_quote_outlined,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),

                const SizedBox(width: 12),

                // Title and subtitle
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Estimate',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _dark,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'ESTIMATE OVERVIEW',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(),

              if (_previousPlan != null) ...[
                const SizedBox(height: 20),
                _buildRegenerationComparison(),
              ],

              const SizedBox(height: 20),

              _sectionTitle('Estimate at a glance', Icons.analytics_outlined),
              const SizedBox(height: 12),
              _buildEstimateCards(currency),
              const SizedBox(height: 12),
              _buildBudgetFeasibility(currency),
              const SizedBox(height: 12),
              _buildTaskRoleCostTable(currency),
              const SizedBox(height: 24),

              _sectionTitle('Project overview', Icons.description_outlined),
              const SizedBox(height: 12),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _labelValue('Project name', widget.title),
                    _labelValue('Categories', widget.categories.join(', ')),
                    _labelValue('Description', widget.description),
                    _labelValue('Requirements', widget.requirements),
                    _labelValue('Suggested technologies', widget.technologies),
                    _labelValue(
                      'AI summary',
                      _string(_currentPlan['projectSummary']),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              _sectionTitle('Confirmed requirements', Icons.checklist_outlined),
              const SizedBox(height: 12),
              _buildListSection(
                _requirements,
                emptyMessage: 'No structured requirements were returned.',
              ),
              const SizedBox(height: 24),

              // The separate project scope approval panel has been removed.
              // Requirements remain visible above and are included in the estimate.
              _sectionTitle(
                'Project modules and tasks',
                Icons.account_tree_outlined,
              ),
              const SizedBox(height: 12),
              if (_modules.isEmpty)
                _emptyCard('No structured modules are available.')
              else
                ..._modules.asMap().entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildModule(entry.value, entry.key),
                  );
                }),
              const SizedBox(height: 12),

              _sectionTitle('Recommended team', Icons.groups_outlined),
              const SizedBox(height: 12),
              _buildTeamSection(),
              const SizedBox(height: 24),

              _sectionTitle('Delivery phases', Icons.calendar_month_outlined),
              const SizedBox(height: 12),
              if (_phases.isEmpty)
                _emptyCard('No delivery phases were returned.')
              else
                ..._phases.asMap().entries.map((entry) {
                  final phase = _asMap(entry.value);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _numberTitle(
                            entry.key + 1,
                            _string(phase['name']).isEmpty
                                ? 'Delivery phase ${entry.key + 1}'
                                : _string(phase['name']),
                          ),
                          const SizedBox(height: 12),
                          _labelValue('Outcome', _string(phase['outcome'])),
                          _labelValue(
                            'Duration',
                            _range(
                              phase['durationWeeksMin'],
                              phase['durationWeeksMax'],
                              'weeks',
                            ),
                          ),
                          _labelValue('Purpose', _string(phase['purpose'])),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 12),

              _sectionTitle(
                'Research and evidence',
                Icons.travel_explore_outlined,
              ),
              const SizedBox(height: 12),
              _card(
                child: _formattedText(
                  _string(_currentPlan['researchFindings']).isNotEmpty
                      ? _string(_currentPlan['researchFindings'])
                      : 'Research findings are shown below when provided by AI.',
                ),
              ),
              const SizedBox(height: 12),
              if (_findings.isNotEmpty)
                ..._findings.map((finding) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildFinding(_asMap(finding)),
                  );
                }),
              _buildSourceList(),
              const SizedBox(height: 24),

              _sectionTitle(
                'Risks and assumptions',
                Icons.warning_amber_outlined,
              ),
              const SizedBox(height: 12),
              if (_risks.isEmpty)
                _emptyCard('No structured risks were returned.')
              else
                ..._risks.map((risk) {
                  final item = _asMap(risk);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFB45309),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _string(item['risk']).isEmpty
                                      ? _string(item['name'])
                                      : _string(item['risk']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _dark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          _labelValue('Impact', _string(item['impact'])),
                          _labelValue(
                            'Mitigation',
                            _string(item['mitigation']),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 24),

              // Keep the existing Questions to confirm section.
              _sectionTitle('Questions to confirm', Icons.help_outline),
              const SizedBox(height: 12),
              if (_questions.isEmpty)
                _emptyCard('No additional questions were returned.')
              else
                _buildListSection(
                  _questions,
                  emptyMessage: 'No questions available.',
                ),
              const SizedBox(height: 24),

              _buildConfidenceCard(),
              const SizedBox(height: 20),
              _buildConfirmationPanel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [_primary, _indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
          const SizedBox(height: 14),
          const Text(
            'Your project estimate is ready',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFFEFF4FF),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Review the proposed scope, delivery plan, team, '
            'budget and assumptions before confirming.',
            style: TextStyle(color: Color(0xFFEFF4FF), height: 1.5),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroPill(
                Icons.view_module_outlined,
                '${_modules.length} modules',
              ),
              _heroPill(Icons.groups_2_outlined, '$_teamRoleCount team roles'),
              _heroPill(
                Icons.flag_outlined,
                '${_phases.length} delivery phases',
              ),
            ],
          ),
          if (_teamRoleNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _teamRoleNames.map((role) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          if ((_currentPlanId ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                'Estimate ID  $_currentPlanId',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Displays the backend's feasibility decision when the backend supplies it.
  /// Supports the flag at plan or estimate level without inventing a result.
  Widget _buildBudgetFeasibility(String currency) {
    final dynamic feasibleValue =
        _currentPlan['budgetFeasible'] ?? _estimate['budgetFeasible'];
    if (feasibleValue is! bool) return const SizedBox.shrink();

    final rawBudget =
        _currentPlan['budgetMax'] ??
        _currentPlan['budgetMaxINR'] ??
        _estimate['budgetMax'] ??
        _estimate['budgetMaxINR'];
    final budget = _number(rawBudget);
    final actualMax = _number(_estimate['costMaxINR']);
    final withinBudget = feasibleValue;
    final color = withinBudget ? _success : const Color(0xFFB45309);
    final background = withinBudget ? _successBg : _warningBg;
    final title = withinBudget ? 'Within target budget' : 'Budget needs review';
    final detail = budget != null && actualMax != null
        ? withinBudget
              ? 'Estimated maximum ${_formatCurrency(actualMax, currency)} is within the target ${_formatCurrency(budget, currency)}.'
              : 'Estimated maximum ${_formatCurrency(actualMax, currency)} exceeds the target ${_formatCurrency(budget, currency)}. Review the scope or revise the budget.'
        : withinBudget
        ? 'The backend marked this estimate as within budget.'
        : 'The backend marked this estimate as exceeding the target budget. Review the scope or revise the budget.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            withinBudget
                ? Icons.check_circle_outline
                : Icons.warning_amber_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shows the backend's actual task-level prices and primary-role mapping
  /// in one table near the project estimate. Missing prices remain unavailable;
  /// they are never silently displayed as zero.
  Widget _buildTaskRoleCostTable(String currency) {
    final rows = <Map<String, String>>[];

    for (final moduleValue in _modules) {
      final module = _asMap(moduleValue);
      final moduleName = _firstNonEmpty([module['name'], module['title']]);
      for (final taskValue in _asList(module['tasks'])) {
        final task = _asMap(taskValue);
        final taskName = _firstNonEmpty([task['name'], task['title']]);
        final role = _string(task['primaryRole']).trim();
        final min = _number(task['priceMinINR']);
        final max = _number(task['priceMaxINR']);
        final effortMin = _number(task['effortHoursMin']);
        final effortMax = _number(task['effortHoursMax']);
        final price = min != null && max != null
            ? '${_formatCurrency(min, currency)} – ${_formatCurrency(max, currency)}'
            : 'Not available';
        final effort = effortMin != null && effortMax != null
            ? _range(effortMin, effortMax, 'h')
            : 'Not available';

        rows.add({
          'module': moduleName.isEmpty ? 'Module' : moduleName,
          'task': taskName.isEmpty ? 'Task' : taskName,
          'role': role.isEmpty ? 'Not assigned' : role,
          'price': price,
          'effort': effort,
        });
      }
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.table_chart_outlined, color: _primary, size: 22),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Task & Role Cost Breakdown',
                  style: TextStyle(
                    color: _dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Task prices and roles returned by the backend. These are task-level estimates; contingency is included in the overall project estimate separately.',
            style: TextStyle(color: _secondary, fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowHeight: 44,
              dataRowMinHeight: 54,
              dataRowMaxHeight: 84,
              columns: const [
                DataColumn(label: Text('Module / Task')),
                DataColumn(label: Text('Primary role')),
                DataColumn(label: Text('Task cost')),
                DataColumn(label: Text('Effort')),
              ],
              rows: rows.map((row) {
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 210,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row['module']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _secondary,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              row['task']!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _dark,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(SizedBox(width: 125, child: Text(row['role']!))),
                    DataCell(SizedBox(width: 145, child: Text(row['price']!))),
                    DataCell(Text(row['effort']!)),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          _buildRoleWiseCosts(currency),
        ],
      ),
    );
  }

  Widget _buildRoleWiseCosts(String currency) {
    final roleWiseCosts = _asMap(_currentPlan['roleWiseCosts']);

    if (roleWiseCosts.isEmpty) {
      return const SizedBox.shrink();
    }

    final roles = roleWiseCosts.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Role-wise Cost Breakdown',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _dark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Task prices grouped by the primary role responsible for each task. '
            'Contingency is shown separately in the project estimate.',
            style: TextStyle(color: _secondary, height: 1.5, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...roles.map((entry) {
            final roleCost = _asMap(entry.value);
            final min = _number(roleCost['costMinINR']);
            final max = _number(roleCost['costMaxINR']);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _labelValue(
                entry.key,
                min != null && max != null
                    ? '${_formatCurrency(min, currency)} – '
                          '${_formatCurrency(max, currency)}'
                    : 'Cost unavailable',
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEstimateCards(String currency) {
    final effort = _range(
      _estimate['effortHoursMin'],
      _estimate['effortHoursMax'],
      'hours',
    );

    final timeline = _range(
      _estimate['timelineMinWeeks'],
      _estimate['timelineMaxWeeks'],
      'weeks',
    );

    final costMin = _number(_estimate['costMinINR']);
    final costMax = _number(_estimate['costMaxINR']);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                icon: Icons.schedule,
                title: 'Effort',
                value: effort,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                icon: Icons.calendar_month,
                title: 'Timeline',
                value: timeline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.currency_rupee, color: _primary, size: 28),
              const SizedBox(height: 10),
              const Text(
                'Estimated project cost',
                style: TextStyle(
                  color: _secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                costMin != null && costMax != null
                    ? '${_formatCurrency(costMin, currency)} – '
                          '${_formatCurrency(costMax, currency)}'
                    : _string(_estimate['costRange']).isNotEmpty
                    ? _string(_estimate['costRange'])
                    : 'Unavailable — request a revised estimate',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: _dark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This is a planning estimate, not a binding quote.',
                style: TextStyle(color: _secondary, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Calculation notes',
                style: TextStyle(fontWeight: FontWeight.w800, color: _dark),
              ),
              const SizedBox(height: 8),
              Text(
                _string(_estimate['calculationNotes']).isEmpty
                    ? 'See the detailed task breakdown and confirm the scope before accepting.'
                    : _string(_estimate['calculationNotes']),
                style: const TextStyle(color: _secondary, height: 1.6),
              ),
              _labelValue(
                'Contingency',
                _estimate['contingencyPercent'] == null
                    ? ''
                    : '${_estimate['contingencyPercent']}%',
              ),
              _labelValue(
                'Market rate verification',
                _string(_estimate['marketRateStatus']),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModule(dynamic value, int index) {
    final module = _asMap(value);
    final tasks = _asList(module['tasks']);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _numberTitle(
            index + 1,
            _string(module['name']).isEmpty
                ? 'Module ${index + 1}'
                : _string(module['name']),
          ),
          _labelValue('Purpose', _string(module['purpose'])),
          _labelValue('Description', _string(module['description'])),
          if (tasks.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Tasks',
              style: TextStyle(fontWeight: FontWeight.w800, color: _dark),
            ),
            const SizedBox(height: 10),
            ...tasks.asMap().entries.map((entry) {
              final task = _asMap(entry.value);
              final taskPriceMin = _number(task['priceMinINR']);
              final taskPriceMax = _number(task['priceMaxINR']);
              final taskPrimaryRole = _string(task['primaryRole']);
              final currency = _string(_estimate['currency']).isEmpty
                  ? 'INR'
                  : _string(_estimate['currency']);

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _string(task['name']).isEmpty
                            ? 'Task ${entry.key + 1}'
                            : _string(task['name']),
                        style: const TextStyle(
                          color: _dark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      _labelValue('Description', _string(task['description'])),
                      _labelValue('Deliverable', _string(task['deliverable'])),
                      if (taskPriceMin != null && taskPriceMax != null)
                        _labelValue(
                          'Fixed price',
                          '${_formatCurrency(taskPriceMin, currency)} – '
                              '${_formatCurrency(taskPriceMax, currency)}',
                        ),
                      if (taskPrimaryRole.isNotEmpty)
                        _labelValue('Primary role', taskPrimaryRole),
                      _labelValue(
                        'Effort',
                        _range(
                          task['effortHoursMin'],
                          task['effortHoursMax'],
                          'hours',
                        ),
                      ),
                      _labelValue('Roles', _pretty(task['roles'])),
                      _labelValue(
                        'Dependencies',
                        _pretty(task['dependencies']),
                      ),
                      _labelValue('Risks', _pretty(task['risks'])),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamSection() {
    final roles = _asList(_team['roles']);
    final entries = roles.isNotEmpty
        ? roles
        : _currentPlan['team'] is List
        ? _asList(_currentPlan['team'])
        : <dynamic>[];

    if (entries.isEmpty) {
      return _emptyCard('No structured team roles were returned by the AI.');
    }

    return Column(
      children: entries.map((entry) {
        final member = _asMap(entry);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _string(member['role']).isEmpty
                      ? _string(member['name']).isEmpty
                            ? 'Team role'
                            : _string(member['name'])
                      : _string(member['role']),
                  style: const TextStyle(
                    color: _dark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _labelValue('Headcount', _string(member['headcount'])),
                _labelValue(
                  'Responsibilities',
                  _pretty(member['responsibilities']),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFinding(Map<String, dynamic> finding) {
    final title = _string(finding['title']).isNotEmpty
        ? _string(finding['title'])
        : _string(finding['finding']);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Research finding' : title,
            style: const TextStyle(color: _dark, fontWeight: FontWeight.w800),
          ),
          _labelValue('Confidence', _string(finding['confidence'])),
          _labelValue('Details', _string(finding['details'])),
          _labelValue('Finding', _string(finding['finding'])),
          _sourceLinks(finding['sourceUrls']),
        ],
      ),
    );
  }

  Widget _buildSourceList() {
    final sources = _asList(_currentPlan['sources']);

    if (sources.isEmpty) return const SizedBox.shrink();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Research sources',
            style: TextStyle(color: _dark, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...sources.map((source) {
            if (source is String) return _sourceLink(source);

            final item = _asMap(source);
            final url = _string(item['url']).isNotEmpty
                ? _string(item['url'])
                : _string(item['sourceUrl']);

            if (url.isEmpty) return const SizedBox.shrink();

            return _sourceLink(url, title: _string(item['title']));
          }),
        ],
      ),
    );
  }

  Widget _sourceLinks(dynamic value) {
    final urls = _asList(value);

    if (urls.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        const Text(
          'Sources',
          style: TextStyle(color: _secondary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...urls.map((url) => _sourceLink(url.toString())),
      ],
    );
  }

  Widget _sourceLink(String url, {String? title}) {
    final uri = Uri.tryParse(url);

    final valid =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: valid ? () => _openSource(uri) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.open_in_new, color: _primary, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title != null && title.isNotEmpty ? title : url,
                style: const TextStyle(
                  color: _primary,
                  decoration: TextDecoration.underline,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSource(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && mounted) {
        _showMessage('Could not open this source link.');
      }
    } catch (_) {
      if (mounted) _showMessage('Could not open this source link.');
    }
  }

  Widget _buildListSection(
    List<dynamic> items, {
    required String emptyMessage,
  }) {
    if (items.isEmpty) return _emptyCard(emptyMessage);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.asMap().entries.map((entry) {
          final value = entry.value;
          final item = _asMap(value);

          final text = value is String
              ? value
              : _firstNonEmpty([
                  item['requirement'],
                  item['question'],
                  item['description'],
                  value,
                ]);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 27,
                  height: 27,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text.isEmpty ? 'Details not available' : text,
                    style: const TextStyle(color: _dark, height: 1.5),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConfidenceCard() {
    final confidence = _currentPlan['overallConfidence'];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estimate confidence',
            style: TextStyle(
              color: _dark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          _formattedText(
            confidence == null
                ? 'Not available'
                : confidence is Map || confidence is List
                ? _pretty(confidence)
                : confidence.toString(),
            muted: true,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _warningBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Review all assumptions, task estimates and requirements before '
              'accepting. The AI estimate is not a guaranteed price or delivery date.',
              style: TextStyle(
                color: Color(0xFF92400E),
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionLoadingAnimation() {
    final isRegenerating = _isRegenerating;

    final title = isRegenerating
        ? 'AI is revising your project'
        : 'Confirming your estimate';

    final subtitle = isRegenerating
        ? 'Reviewing your budget, timeline, features and team...'
        : 'Saving your acceptance and preparing your project...';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      child: Container(
        key: ValueKey(isRegenerating),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A2563EB),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              width: 78,
              height: 78,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isRegenerating ? _indigo : _success,
                      ),
                      backgroundColor: _border,
                    ),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.85, end: 1.0),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeInOut,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Icon(
                      isRegenerating
                          ? Icons.auto_awesome_rounded
                          : Icons.verified_rounded,
                      color: isRegenerating ? _indigo : _success,
                      size: 34,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: _secondary,
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: const LinearProgressIndicator(
                minHeight: 5,
                backgroundColor: Color(0xFFEFF4FF),
                valueColor: AlwaysStoppedAnimation<Color>(_primary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Please wait. Do not close this screen.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: _secondary),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Client confirmation: cost Yes/No, timeline Yes/No, Terms checkbox only.
  // Selecting No reveals the relevant input and changes the primary action
  // from "Accept Estimate" to "Regenerate Estimate".
  // ---------------------------------------------------------------------------

  Widget _buildConfirmationPanel() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isSubmitting || _isRegenerating) ...[
            _buildActionLoadingAnimation(),
          ],
          const Text(
            'Client confirmation',
            style: TextStyle(
              color: _dark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Review the estimate details below. If the cost or delivery date does '
            'not work for you, choose No and share your target so the AI can '
            'regenerate the estimate.',
            style: TextStyle(color: _secondary, height: 1.6),
          ),
          if (_submittedStatus != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isAccepted ? _successBg : _background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isAccepted
                    ? 'Your estimate acceptance has been recorded.'
                    : 'Your response has been recorded: $_submittedStatus',
                style: TextStyle(
                  color: _isAccepted ? _success : _dark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Confirm estimate details',
            style: TextStyle(
              color: _dark,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),

          // COST: Yes / No.
          const Text(
            'Estimated project cost',
            style: TextStyle(color: _dark, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          RadioGroup<bool>(
            groupValue: _costChoice,
            onChanged: (value) {
              if (_isSubmitting || _isRegenerating || _isAccepted) {
                return;
              }

              setState(() {
                _costChoice = value;
                _acceptedCost = value == true;

                if (value == true) {
                  _targetBudgetController.clear();
                }
              });
            },
            child: const Column(
              children: [
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Yes, my budget matches this estimate'),
                  value: true,
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('No, I have a different budget'),
                  value: false,
                ),
              ],
            ),
          ),
          if (_costChoice == false) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 12),
              child: TextField(
                controller: _targetBudgetController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                enabled: !_isSubmitting && !_isRegenerating && !_isAccepted,
                decoration: const InputDecoration(
                  labelText: 'Your target budget (₹)',
                  hintText: 'Enter your maximum budget',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],

          const Divider(height: 24),

          // TIMELINE: Yes / No.
          const Text(
            'Estimated project timeline',
            style: TextStyle(color: _dark, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          RadioGroup<bool>(
            groupValue: _timelineChoice,
            onChanged: (value) {
              if (_isSubmitting || _isRegenerating || _isAccepted) {
                return;
              }

              setState(() {
                _timelineChoice = value;
                _acceptedTimeline = value == true;

                if (value == true) {
                  _targetDeliveryDate = null;
                }
              });
            },
            child: const Column(
              children: [
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Yes, the estimated timeline works for me'),
                  value: true,
                ),
                RadioListTile<bool>(
                  contentPadding: EdgeInsets.zero,
                  title: Text('No, I need the project by a different date'),
                  value: false,
                ),
              ],
            ),
          ),
          if (_timelineChoice == false) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 12),
              child: OutlinedButton.icon(
                onPressed: _isSubmitting || _isRegenerating || _isAccepted
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final selected = await showDatePicker(
                          context: context,
                          initialDate:
                              _targetDeliveryDate ??
                              now.add(const Duration(days: 30)),
                          firstDate: DateTime(now.year, now.month, now.day),
                          lastDate: DateTime(now.year + 10),
                        );

                        if (selected != null && mounted) {
                          setState(() => _targetDeliveryDate = selected);
                        }
                      },
                icon: const Icon(Icons.calendar_month),
                label: Text(
                  _targetDeliveryDate == null
                      ? 'Choose required delivery date'
                      : 'Required by: '
                            '${_targetDeliveryDate!.day.toString().padLeft(2, '0')}/'
                            '${_targetDeliveryDate!.month.toString().padLeft(2, '0')}/'
                            '${_targetDeliveryDate!.year}',
                ),
              ),
            ),
          ],

          // Terms & Conditions is the only checkbox.
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _acceptedTerms,
            onChanged: _isSubmitting || _isRegenerating || _isAccepted
                ? null
                : (value) => setState(() => _acceptedTerms = value ?? false),
            title: const Text('I agree to the Terms & Conditions.'),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _isGeneratingRequirementsPdf
                  ? null
                  : _showRequirementsPdfOptions,
              icon: _isGeneratingRequirementsPdf
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                _isGeneratingRequirementsPdf
                    ? 'Generating PDF...'
                    : 'Download & Share Requirements',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary, width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // The main action switches based on the client's cost/timeline choices.
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  _isSubmitting ||
                      _isRegenerating ||
                      _isAccepted ||
                      _costChoice == null ||
                      _timelineChoice == null ||
                      (!_needsRegeneration && !_acceptedTerms)
                  ? null
                  : _needsRegeneration
                  ? _regenerateEstimate
                  : _confirmAcceptance,
              icon: Icon(
                _needsRegeneration ? Icons.refresh : Icons.check_circle_outline,
              ),
              label: Text(
                _isSubmitting
                    ? 'Submitting...'
                    : _isRegenerating
                    ? 'Regenerating...'
                    : _isAccepted
                    ? 'Estimate Accepted'
                    : _needsRegeneration
                    ? 'Regenerate Estimate'
                    : 'Accept Estimate',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _needsRegeneration ? _primary : _success,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isSubmitting || _isRegenerating || _isAccepted
                  ? null
                  : () => _submitTextResponse(
                      status: 'changes_requested',
                      heading: 'Request changes',
                      hint: 'Describe the features, scope, budget, timeline, or requirements you want changed. The AI will prepare a revised estimate.',
                    ),
              icon: const Icon(Icons.edit_note),
              label: const Text('Request Changes'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _isSubmitting || _isRegenerating || _isAccepted
                  ? null
                  : () => _submitTextResponse(
                      status: 'question_submitted',
                      heading: 'Ask a question',
                      hint: 'Write your question about the scope, price, team or delivery plan.',
                    ),
              icon: const Icon(Icons.help_outline),
              label: const Text('Ask a Question'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _dark,
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAcceptance() async {
    if (_costChoice != true || _timelineChoice != true || !_acceptedTerms) {
      _showMessage(
        'Please answer Yes for cost and timeline and accept the Terms & Conditions.',
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please sign in before accepting the estimate.');
      return;
    }

    if ((_currentPlanId ?? '').trim().isEmpty) {
      _showMessage(
        'Estimate ID is missing. Please regenerate the estimate before accepting.',
      );
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Accept this estimate?'),
          content: const Text(
            'This records your acceptance of the proposed scope, cost range, '
            'timeline and assumptions. It does not by itself create a contract or payment.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Review Again'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm Acceptance'),
            ),
          ],
        );
      },
    );

    if (accepted != true || !mounted) return;

    await _saveResponse(
      status: 'accepted',
      message: 'Client accepted the estimate, cost, timeline and Terms & Conditions.',
    );
  }

  Future<void> _submitTextResponse({
    required String status,
    required String heading,
    required String hint,
  }) async {
    final controller = TextEditingController();

    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(heading),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(dialogContext, text);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (message == null || !mounted) return;

    if (status == 'changes_requested') {
      await _regenerateEstimate(additionalFeedback: message);
      return;
    }

    await _saveResponse(status: status, message: message);
  }

  Future<void> _regenerateEstimate({String? additionalFeedback}) async {
    if (_isRegenerating || _isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please sign in before regenerating the estimate.');
      return;
    }

    final hasAdditionalFeedback = (additionalFeedback ?? '').trim().isNotEmpty;

    // Replanning is available for budget/timeline changes or written scope feedback.
    if (!_needsRegeneration && !hasAdditionalFeedback) {
      _showMessage(
        'Choose No for the cost or timeline, or describe the changes you need.',
      );
      return;
    }

    // Validate and parse the budget so the backend receives a numeric value.
    num? targetBudget;
    if (_costChoice == false) {
      targetBudget = _number(_targetBudgetController.text);

      if (targetBudget == null || targetBudget <= 0) {
        _showMessage('Please enter a valid target budget greater than zero.');
        return;
      }
    }

    if (_timelineChoice == false && _targetDeliveryDate == null) {
      _showMessage('Please select your required delivery date.');
      return;
    }

    final targetDeadline = _timelineChoice == false
        ? '${_targetDeliveryDate!.year.toString().padLeft(4, '0')}-'
              '${_targetDeliveryDate!.month.toString().padLeft(2, '0')}-'
              '${_targetDeliveryDate!.day.toString().padLeft(2, '0')}'
        : null;

    final feedbackParts = <String>[];
    final trimmedFeedback = (additionalFeedback ?? '').trim();
    if (trimmedFeedback.isNotEmpty) {
      feedbackParts.add('Additional client change request: $trimmedFeedback');
    }

    if (_costChoice == false) {
      feedbackParts.add(
        'Budget preference: The client target maximum budget is '
        '₹${targetBudget!.toString()}. Regenerate the estimate to fit this '
        'budget as closely as possible. Prioritize the most important '
        'requirements and clearly explain any necessary scope trade-offs.',
      );
    }

    if (_timelineChoice == false) {
      feedbackParts.add(
        'Delivery date preference: The client needs the project by '
        '$targetDeadline. Regenerate the plan and estimate to fit this '
        'deadline as closely as reasonably possible. Explain any timeline '
        'constraints or trade-offs.',
      );
    }

    final previousPlan = Map<String, dynamic>.from(_currentPlan);
    setState(() => _isRegenerating = true);

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

      final callable = functions.httpsCallable(
        'generateAIProjectPlan',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 320)),
      );

      final result = await callable.call({
        'mode': 'replan',
        'title': widget.title,
        'categories': widget.categories,
        'description': widget.description,
        'requirements': widget.requirements,
        'technologies': widget.technologies,
        'analysis': _currentPlan['analysis']?.toString() ?? '',
        'previousPlan': _currentPlan,

        // Structured constraints for the backend.
        // A target budget is treated as the client's maximum budget.
        'budgetMax': targetBudget,
        'deadline': targetDeadline,

        // Keep the natural-language explanation as well.
        'clientFeedback': feedbackParts.join('\n\n'),
      });

      final data = _asMap(result.data);
      final newPlan = _asMap(data['plan']);
      final returnedPlanId = _string(data['planId']).trim();

      if (newPlan.isEmpty) {
        throw Exception('The server did not return a valid plan.');
      }

      if (returnedPlanId.isEmpty) {
        throw Exception(
          'The server did not return an estimate ID. '
          'The previous estimate has been preserved.',
        );
      }

      if (!mounted) return;

      setState(() {
        _previousPlan = previousPlan;
        _currentPlan = Map<String, dynamic>.from(newPlan);
        _currentPlanId = returnedPlanId;

        // Reset all decisions for the newly generated estimate.
        _acceptedCost = false;
        _acceptedTimeline = false;
        _acceptedTerms = false;
        _costChoice = null;
        _timelineChoice = null;
        _targetBudgetController.clear();
        _targetDeliveryDate = null;
        _submittedStatus = null;
      });

      await _savePlanToExistingProject();

      _showMessage(
        'Updated estimate generated. Please review the new estimate and answer again.',
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint('REGENERATE ESTIMATE ERROR: ${e.code} ${e.message}');
      if (mounted) {
        _showMessage(e.message ?? 'Could not regenerate the estimate.');
      }
    } catch (e, stackTrace) {
      debugPrint('REGENERATE ESTIMATE ERROR: $e');
      debugPrint('$stackTrace');
      if (mounted) {
        _showMessage('Could not regenerate the estimate. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  Future<void> _saveResponse({
    required String status,
    required String message,
  }) async {
    if (_isSubmitting) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please sign in before submitting your response.');
      return;
    }

    if ((_currentPlanId ?? '').trim().isEmpty) {
      _showMessage('Estimate ID is missing. Please regenerate the estimate.');
      return;
    }

    if (status == 'accepted' &&
        (_costChoice != true || _timelineChoice != true || !_acceptedTerms)) {
      _showMessage(
        'Please answer Yes for cost and timeline and accept the Terms & Conditions first.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Upload images only after the client confirms acceptance.
      List<String> finalDesignImageUrls = List<String>.from(
        widget.designImageUrls,
      );

      if (status == 'accepted') {
        // Step 1: Configure the authenticated role for this user.
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

        await functions.httpsCallable('ensureSupabaseRole').call();

        // Step 2: Refresh the Firebase ID token.
        await user.getIdToken(true);

        // Step 3: Verify the refreshed token contains the role.
        final tokenResult = await user.getIdTokenResult();
        final role = tokenResult.claims?['role'];

        debugPrint('SUPABASE JWT ROLE AFTER REFRESH: $role');

        if (role != 'authenticated') {
          throw StateError('Firebase token is missing role=authenticated.');
        }

        // Step 4: Upload generated and reference images.
        final storage = SupabaseStorageService.instance;

        final safePlanId = _currentPlanId!.replaceAll(
          RegExp(r'[^A-Za-z0-9_-]'),
          '_',
        );

        final uploadProjectId = 'accepted_${user.uid}_$safePlanId';

        for (int i = 0; i < widget.generatedDesignImageBytes.length; i++) {
          final url = await storage.uploadProjectImage(
            bytes: widget.generatedDesignImageBytes[i],
            fileName: 'generated_design_${i + 1}.png',
            projectId: uploadProjectId,
            contentType: 'image/png',
          );

          finalDesignImageUrls.add(url);
        }

        for (int i = 0; i < widget.referenceImageBytesList.length; i++) {
          final fileName = i < widget.referenceImageNames.length
              ? widget.referenceImageNames[i]
              : 'reference_image_${i + 1}.jpg';

          final mimeType = i < widget.referenceImageMimeTypes.length
              ? widget.referenceImageMimeTypes[i]
              : 'image/jpeg';

          final url = await storage.uploadProjectImage(
            bytes: widget.referenceImageBytesList[i],
            fileName: fileName,
            projectId: uploadProjectId,
            contentType: mimeType,
          );

          finalDesignImageUrls.add(url);
        }
      }
      final doc = <String, dynamic>{
        // Nullable: a draft estimate can be reviewed before a project exists.
        'projectId': widget.projectId,
        'planId': _currentPlanId,
        'projectTitle': widget.title,
        'clientUid': user.uid,
        'status': status,
        'message': message,
        'estimate': _estimate,

        // Preserve this existing field for compatibility with stored responses.
        'acceptedScope': _scopeItems.map((item) => item.title).toList(),

        'acceptedCost': status == 'accepted' && _acceptedCost,
        'acceptedTimeline': status == 'accepted' && _acceptedTimeline,
        'costChoice': _costChoice,
        'timelineChoice': _timelineChoice,
        'targetBudget': _costChoice == false
            ? _targetBudgetController.text.trim()
            : null,
        'targetDeliveryDate':
            _timelineChoice == false && _targetDeliveryDate != null
            ? Timestamp.fromDate(_targetDeliveryDate!)
            : null,
        'acceptedTerms': status == 'accepted' && _acceptedTerms,
        'termsVersion': 'v1',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'accepted') {
        // Create/update the project and record acceptance atomically.
        // A deterministic confirmation ID makes retries idempotent: a timeout
        // after a successful server write must not create a second project.
        final firestore = FirebaseFirestore.instance;
        final safePlanId = _currentPlanId!.replaceAll(
          RegExp(r'[^A-Za-z0-9_-]'),
          '_',
        );
        final confirmationRef = firestore
            .collection('projectEstimateConfirmations')
            .doc('${user.uid}_$safePlanId');
        final requestedProjectId = widget.projectId?.trim();
        final newProjectRef =
            requestedProjectId != null && requestedProjectId.isNotEmpty
            ? firestore.collection('projects').doc(requestedProjectId)
            : firestore.collection('projects').doc();

        await firestore.runTransaction<String>((transaction) async {
          final confirmationSnapshot = await transaction.get(confirmationRef);
          final priorConfirmation = confirmationSnapshot.data() ?? {};
          final priorProjectId =
              priorConfirmation['projectId']?.toString().trim() ?? '';

          // Reuse the ID from a previous successful attempt if present.
          final projectRef = priorProjectId.isNotEmpty
              ? firestore.collection('projects').doc(priorProjectId)
              : newProjectRef;
          final projectSnapshot = await transaction.get(projectRef);
          final existingProject = projectSnapshot.data() ?? {};

          // If both records already exist, this acceptance was completed
          // earlier. Return the same project rather than creating another.
          if (confirmationSnapshot.exists &&
              priorConfirmation['status'] == 'accepted' &&
              projectSnapshot.exists) {
            return projectRef.id;
          }

          final now = FieldValue.serverTimestamp();
          final projectData = <String, dynamic>{
            'projectId': projectRef.id,
            'clientId': user.uid,
            'title': widget.title.trim(),
            'categories': widget.categories,
            'description': widget.description.trim(),
            'requirements': widget.requirements.trim(),
            'technologies': widget.technologies.trim(),
            'status': existingProject['status'] ?? 'requirement',
            'planId': _currentPlanId,
            'plan': _currentPlan,
            'designImageUrls': finalDesignImageUrls,
            'estimate': _estimate,
            'acceptedScope': _scopeItems.map((item) => item.title).toList(),
            'acceptedCost': true,
            'acceptedTimeline': true,
            'acceptedTerms': true,
            'termsVersion': 'v1',
            'updatedAt': now,
          };
          if (!projectSnapshot.exists || existingProject['createdAt'] == null) {
            projectData['createdAt'] = now;
          }
          final clientName = user.displayName?.trim() ?? '';
          if (clientName.isNotEmpty) {
            projectData['clientName'] = clientName;
          }

          // merge:true preserves fields owned by other project workflows.
          transaction.set(projectRef, projectData, SetOptions(merge: true));
          transaction.set(confirmationRef, <String, dynamic>{
            ...doc,
            'projectId': projectRef.id,
            'createdAt': confirmationSnapshot.exists
                ? (priorConfirmation['createdAt'] ?? now)
                : now,
            'updatedAt': now,
          }, SetOptions(merge: true));

          return projectRef.id;
        });
      } else {
        // Questions and change requests remain separate response records.
        await FirebaseFirestore.instance
            .collection('projectEstimateConfirmations')
            .add(doc);
      }

      if (!mounted) return;

      setState(() => _submittedStatus = status);

      if (status == 'accepted') {
        _showMessage('Project created successfully!');

        await Future<void>.delayed(const Duration(milliseconds: 700));

        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const ClientHome()),
          (route) => false,
        );

        return;
      }

      _showMessage('Your response has been submitted.');
    } catch (e, stackTrace) {
      debugPrint('ESTIMATE RESPONSE SAVE ERROR: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      _showMessage('Could not save your response. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _heroPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primary, _indigo]),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: _secondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            value.isEmpty ? 'Not available' : value,
            style: const TextStyle(
              color: _dark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEFF4FF), Color(0xFFE0E7FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _dark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _emptyCard(String message) {
    return _card(
      child: Text(
        message,
        style: const TextStyle(color: _secondary, height: 1.5),
      ),
    );
  }

  Widget _numberTitle(int number, String title) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              title,
              style: const TextStyle(
                color: _dark,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _labelValue(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _secondary,
              fontSize: 11,
              letterSpacing: 0.65,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          _formattedText(value),
        ],
      ),
    );
  }

  /// Renders AI-generated Markdown as readable, selectable content instead of
  /// showing raw Markdown markers or one dense block of text.
  Widget _formattedText(String value, {bool muted = false}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    final baseColor = muted ? _secondary : _dark;
    final baseStyle = TextStyle(color: baseColor, fontSize: 14, height: 1.65);

    return MarkdownBody(
      data: value.trim(),
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle.copyWith(height: 1.65),
        h1: const TextStyle(
          color: _dark,
          fontSize: 20,
          height: 1.35,
          fontWeight: FontWeight.w800,
        ),
        h2: const TextStyle(
          color: _dark,
          fontSize: 17,
          height: 1.4,
          fontWeight: FontWeight.w800,
        ),
        h3: const TextStyle(
          color: _dark,
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w800,
        ),
        strong: const TextStyle(color: _dark, fontWeight: FontWeight.w800),
        listBullet: baseStyle.copyWith(fontWeight: FontWeight.w700),
        blockquote: baseStyle.copyWith(color: _secondary),
        code: const TextStyle(
          color: _indigo,
          fontSize: 13,
          fontFamily: 'monospace',
          backgroundColor: Color(0xFFF1F5F9),
        ),
        blockquoteDecoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          border: Border(left: BorderSide(color: _primary, width: 3)),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        listIndent: 22,
        blockSpacing: 8,
      ),
    );
  }

  String _range(dynamic min, dynamic max, String unit) {
    if (min == null && max == null) return '';
    if (min == null) return '$max $unit';
    if (max == null) return '$min $unit';
    return '$min–$max $unit';
  }

  String _formatCurrency(num value, String currency) {
    final formatted = value.round().toString();
    final symbol = currency == 'INR' ? '₹' : '$currency ';
    return '$symbol$formatted';
  }

  String _pretty(dynamic value) {
    if (value == null) return '';

    if (value is String) return value.trim();

    if (value is List) {
      final items = value
          .map(_pretty)
          .where((item) => item.trim().isNotEmpty)
          .toList();
      if (items.isEmpty) return '';
      if (items.length == 1) return items.first;
      return items
          .map((item) => '- ${item.replaceAll('\n', '\n  ')}')
          .join('\n');
    }

    if (value is Map) {
      return value.entries
          .map((entry) {
            final child = _pretty(entry.value);
            if (child.isEmpty) return '';
            final label = _humanizeKey(entry.key.toString());
            if (child.contains('\n')) {
              return '**$label:**\n${child.split('\n').map((line) => '  $line').join('\n')}';
            }
            return '**$label:** $child';
          })
          .where((entry) => entry.isNotEmpty)
          .join('\n\n');
    }

    return value.toString();
  }

  String _humanizeKey(String key) {
    final spaced = key
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();
    if (spaced.isEmpty) return key;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  String _string(dynamic value) {
    if (value == null) return '';
    if (value is Map || value is List) return _pretty(value);
    return value.toString().trim();
  }

  String _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _string(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  num? _number(dynamic value) {
    if (value is num) return value;

    if (value is String) {
      return num.tryParse(value.replaceAll(',', '').trim());
    }

    return null;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return [value];
    return <dynamic>[];
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _ScopeItem {
  final String key;
  final String title;
  final String description;

  const _ScopeItem({
    required this.key,
    required this.title,
    this.description = '',
  });
}
