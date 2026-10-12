import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
  });

  @override
  State<ProjectEstimateResultScreen> createState() =>
      _ProjectEstimateResultScreenState();
}

class _ProjectEstimateResultScreenState
    extends State<ProjectEstimateResultScreen> {
  bool _isSubmitting = false;
  bool _isRegenerating = false;
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

  @override
  void initState() {
    super.initState();
    _currentPlan = Map<String, dynamic>.from(widget.plan);
    _currentPlanId = widget.planId;
  }

  @override
  void dispose() {
    _targetBudgetController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _estimate => _asMap(_currentPlan['estimate']);

  Map<String, dynamic> get _team => _asMap(_currentPlan['team']);

  List<dynamic> get _modules => _asList(_currentPlan['modules']);

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

  @override
  Widget build(BuildContext context) {
    final currency = _string(_estimate['currency']).isEmpty
        ? 'INR'
        : _string(_estimate['currency']);

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        title: const Text(
          'Project Estimate',
          style: TextStyle(color: _dark, fontWeight: FontWeight.w800),
        ),
        backgroundColor: _background,
        foregroundColor: _dark,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(),
              const SizedBox(height: 20),

              _sectionTitle('Estimate at a glance', Icons.analytics_outlined),
              const SizedBox(height: 12),
              _buildEstimateCards(currency),
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
                child: Text(
                  _string(_currentPlan['researchFindings']).isNotEmpty
                      ? _string(_currentPlan['researchFindings'])
                      : 'Research findings are shown below when provided by AI.',
                  style: const TextStyle(color: _dark, height: 1.6),
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
          if ((_currentPlanId ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              'Estimate ID: $_currentPlanId',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
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
          Text(
            confidence == null
                ? 'Not available'
                : confidence is Map || confidence is List
                ? _pretty(confidence)
                : confidence.toString(),
            style: const TextStyle(color: _secondary, height: 1.5),
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
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yes, my budget matches this estimate'),
            value: true,
            groupValue: _costChoice,
            onChanged: _isSubmitting || _isRegenerating || _isAccepted
                ? null
                : (value) {
                    setState(() {
                      _costChoice = value;
                      _acceptedCost = value == true;

                      // Clear the old budget when the client switches back to Yes.
                      if (value == true) {
                        _targetBudgetController.clear();
                      }
                    });
                  },
          ),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            title: const Text('No, I have a different budget'),
            value: false,
            groupValue: _costChoice,
            onChanged: _isSubmitting || _isRegenerating || _isAccepted
                ? null
                : (value) {
                    setState(() {
                      _costChoice = value;
                      _acceptedCost = false;
                    });
                  },
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
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Yes, the estimated timeline works for me'),
            value: true,
            groupValue: _timelineChoice,
            onChanged: _isSubmitting || _isRegenerating || _isAccepted
                ? null
                : (value) {
                    setState(() {
                      _timelineChoice = value;
                      _acceptedTimeline = value == true;

                      // Clear the old date when the client switches back to Yes.
                      if (value == true) {
                        _targetDeliveryDate = null;
                      }
                    });
                  },
          ),
          RadioListTile<bool>(
            contentPadding: EdgeInsets.zero,
            title: const Text('No, I need the project by a different date'),
            value: false,
            groupValue: _timelineChoice,
            onChanged: _isSubmitting || _isRegenerating || _isAccepted
                ? null
                : (value) {
                    setState(() {
                      _timelineChoice = value;
                      _acceptedTimeline = false;
                    });
                  },
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
      feedbackParts.add(
        'Additional client change request: $trimmedFeedback',
      );
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

    setState(() => _isRegenerating = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'generateAIProjectPlan',
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

      if (newPlan.isEmpty) {
        throw Exception('The server did not return a valid plan.');
      }

      if (!mounted) return;

      setState(() {
        _currentPlan = Map<String, dynamic>.from(newPlan);

        final returnedPlanId = _string(data['planId']);
        if (returnedPlanId.isNotEmpty) {
          _currentPlanId = returnedPlanId;
        }

        // All decisions must be made again for the new estimate.
        _acceptedCost = false;
        _acceptedTimeline = false;
        _acceptedTerms = false;
        _costChoice = null;
        _timelineChoice = null;
        _targetBudgetController.clear();
        _targetDeliveryDate = null;
        _submittedStatus = null;
      });

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

      String? createdProjectId;

      if (status == 'accepted') {
        // Create/update the project and record acceptance atomically.
        // A deterministic confirmation ID makes retries idempotent: a timeout
        // after a successful server write must not create a second project.
        final firestore = FirebaseFirestore.instance;
        final safePlanId = _currentPlanId!
            .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
        final confirmationRef = firestore
            .collection('projectEstimateConfirmations')
            .doc('${user.uid}_${safePlanId}');
        final requestedProjectId = widget.projectId?.trim();
        final newProjectRef = requestedProjectId != null &&
                requestedProjectId.isNotEmpty
            ? firestore.collection('projects').doc(requestedProjectId)
            : firestore.collection('projects').doc();

        createdProjectId = await firestore.runTransaction<String>(
          (transaction) async {
            final confirmationSnapshot =
                await transaction.get(confirmationRef);
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
              'estimate': _estimate,
              'acceptedScope': _scopeItems.map((item) => item.title).toList(),
              'acceptedCost': true,
              'acceptedTimeline': true,
              'acceptedTerms': true,
              'termsVersion': 'v1',
              'updatedAt': now,
            };
            if (!projectSnapshot.exists ||
                existingProject['createdAt'] == null) {
              projectData['createdAt'] = now;
            }
            final clientName = user.displayName?.trim() ?? '';
            if (clientName.isNotEmpty) {
              projectData['clientName'] = clientName;
            }

            // merge:true preserves fields owned by other project workflows.
            transaction.set(
              projectRef,
              projectData,
              SetOptions(merge: true),
            );
            transaction.set(
              confirmationRef,
              <String, dynamic>{
                ...doc,
                'projectId': projectRef.id,
                'createdAt': confirmationSnapshot.exists
                    ? (priorConfirmation['createdAt'] ?? now)
                    : now,
                'updatedAt': now,
              },
              SetOptions(merge: true),
            );

            return projectRef.id;
          },
        );
      } else {
        // Questions and change requests remain separate response records.
        await FirebaseFirestore.instance
            .collection('projectEstimateConfirmations')
            .add(doc);
      }

      if (!mounted) return;

      setState(() => _submittedStatus = status);

      _showMessage(
        status == 'accepted'
            ? 'Project created and estimate acceptance saved.'
            : 'Your response has been submitted.',
      );
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

  Widget _metricCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary, size: 25),
          const SizedBox(height: 10),
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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _dark,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card({required Widget child}) {
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
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _secondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(color: _dark, height: 1.5, fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _rateRange(Map<String, dynamic> member) {
    final min = _number(member['rateMinINRPerHour']);
    final max = _number(member['rateMaxINRPerHour']);

    if (min == null || max == null) return '';

    return '${_formatCurrency(min, 'INR')} – '
        '${_formatCurrency(max, 'INR')} per hour';
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
      return value.map(_pretty).where((e) => e.isNotEmpty).join(', ');
    }

    if (value is Map) {
      return value.entries
          .map((entry) {
            final child = _pretty(entry.value);
            return child.isEmpty ? '' : '${entry.key}: $child';
          })
          .where((e) => e.isNotEmpty)
          .join('\n');
    }

    return value.toString();
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
