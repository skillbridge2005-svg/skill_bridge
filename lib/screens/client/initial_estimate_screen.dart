import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InitialEstimateScreen extends StatefulWidget {
  final String title;
  final List<String> categories;
  final String description;
  final String requirements;
  final String technologies;
  final String analysis;

  const InitialEstimateScreen({
    super.key,
    required this.title,
    required this.categories,
    required this.description,
    required this.requirements,
    required this.technologies,
    required this.analysis,
  });

  @override
  State<InitialEstimateScreen> createState() => _InitialEstimateScreenState();
}

class _InitialEstimateScreenState extends State<InitialEstimateScreen> {
  static const double _contingencyRate = 0.10;

  static const Map<String, double> _hourlyRates = {
    'frontend': 400,
    'backend': 500,
    'database': 400,
    'testing': 300,
    'deployment': 400,
  };

  bool _loading = false;
  String? _errorMessage;
  _ProjectEstimate? _estimate;

  @override
  void initState() {
    super.initState();
    _loadEstimate();
  }

  Future<void> _loadEstimate() async {
    if (_loading) return;

    if (widget.title.trim().isEmpty ||
        widget.description.trim().isEmpty ||
        widget.requirements.trim().isEmpty) {
      setState(() {
        _errorMessage =
            'Please provide the project title, description, and requirements.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      if (FirebaseAuth.instance.currentUser == null) {
        throw StateError('Please log in to estimate project costs.');
      }

      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable(
        'estimateProjectCost',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      final result = await callable.call(<String, dynamic>{
        'title': widget.title,
        'categories': widget.categories,
        'description': widget.description,
        'requirements': widget.requirements,
        'technologies': widget.technologies,
      });

      final raw = result.data;
      if (raw is! Map) {
        throw const FormatException(
          'The estimate service returned an invalid response.',
        );
      }

      final data = Map<String, dynamic>.from(raw);
      final rawEstimate = data['estimate'];
      if (data['success'] != true || rawEstimate is! Map) {
        throw const FormatException(
          'The estimate service returned no estimate.',
        );
      }

      final estimate = _ProjectEstimate.fromMap(
        Map<String, dynamic>.from(rawEstimate),
      );

      if (!mounted) return;
      setState(() {
        _estimate = estimate;
      });
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint('Project cost estimate function failed: ${error.code}');
      debugPrint('Message: ${error.message}');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(error);
      });
    } catch (error, stackTrace) {
      debugPrint('Project cost estimation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _errorMessage = error is StateError
            ? error.message
            : 'Unable to estimate the project workload. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _friendlyError(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Please log in before estimating your project.';
      case 'invalid-argument':
        return error.message ?? 'Please check your project information.';
      case 'failed-precondition':
        return error.message ?? 'AI estimation is not configured correctly.';
      case 'unavailable':
        return 'The estimation service is unavailable. Please try again.';
      case 'deadline-exceeded':
        return 'Estimation took too long. Please try again.';
      case 'resource-exhausted':
        return 'The AI usage limit has been reached. Try again later.';
      default:
        return error.message ??
            'Unable to estimate the project cost. Please try again.';
    }
  }

  double get _baseCost {
    final estimate = _estimate!;
    return estimate.frontendHours * _hourlyRates['frontend']! +
        estimate.backendHours * _hourlyRates['backend']! +
        estimate.databaseHours * _hourlyRates['database']! +
        estimate.testingHours * _hourlyRates['testing']! +
        estimate.deploymentHours * _hourlyRates['deployment']!;
  }

  double get _contingencyAmount => _baseCost * _contingencyRate;

  double get _contingencyAdjustedCost => _baseCost + _contingencyAmount;

  double get _totalHours {
    final estimate = _estimate!;
    return estimate.frontendHours +
        estimate.backendHours +
        estimate.databaseHours +
        estimate.testingHours +
        estimate.deploymentHours;
  }

  String _formatCost(double value) {
    final rounded = value.round().toString();
    final formatted = rounded.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
    return '₹$formatted';
  }

  String _taskLabel(String field) {
    switch (field) {
      case 'frontend':
        return 'Frontend Development';
      case 'backend':
        return 'Backend Development';
      case 'database':
        return 'Database Integration';
      case 'testing':
        return 'Testing & Debugging';
      case 'deployment':
        return 'Deployment';
      default:
        return field;
    }
  }

  IconData _taskIcon(String field) {
    switch (field) {
      case 'frontend':
        return Icons.web_outlined;
      case 'backend':
        return Icons.dns_outlined;
      case 'database':
        return Icons.storage_outlined;
      case 'testing':
        return Icons.bug_report_outlined;
      case 'deployment':
        return Icons.cloud_upload_outlined;
      default:
        return Icons.work_outline;
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildEstimate(_ProjectEstimate estimate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimated Project Cost',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatCost(_contingencyAdjustedCost),
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Includes a ${(_contingencyRate * 100).round()}% '
                  'contingency allowance.',
                ),
                const SizedBox(height: 12),
                Chip(label: Text('${estimate.complexity} Complexity')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _summaryCard(
              title: 'Development effort',
              value: '${_totalHours.toStringAsFixed(0)} hrs',
              icon: Icons.schedule_outlined,
            ),
            _summaryCard(
              title: 'Estimated duration',
              value: '${estimate.durationWeeks} weeks',
              icon: Icons.calendar_month_outlined,
            ),
            _summaryCard(
              title: 'Suggested team size',
              value: '${estimate.teamSize} people',
              icon: Icons.groups_outlined,
            ),
            _summaryCard(
              title: 'Base development cost',
              value: _formatCost(_baseCost),
              icon: Icons.payments_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Project overview',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                estimate.summary.isEmpty
                    ? 'The estimate is based on the supplied project requirements.'
                    : estimate.summary,
              ),
              if (widget.analysis.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'AI analysis: ${widget.analysis}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Technologies: ${widget.technologies.trim().isEmpty ? 'Not specified' : widget.technologies.trim()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Cost breakdown',
          child: Column(
            children: [
              for (final item in [
                ('frontend', estimate.frontendHours),
                ('backend', estimate.backendHours),
                ('database', estimate.databaseHours),
                ('testing', estimate.testingHours),
                ('deployment', estimate.deploymentHours),
              ])
                _costRow(item.$1, item.$2),
              const Divider(),
              _detailRow('Base development cost', _formatCost(_baseCost)),
              _detailRow('Contingency (10%)', _formatCost(_contingencyAmount)),
              const Divider(),
              _detailRow(
                'Contingency-adjusted estimate',
                _formatCost(_contingencyAdjustedCost),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Estimation assumptions',
          child: estimate.assumptions.isEmpty
              ? const Text('No additional assumptions were provided.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final assumption in estimate.assumptions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 19),
                            const SizedBox(width: 8),
                            Expanded(child: Text(assumption)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          title: 'Estimate note',
          child: const Text(
            'This is an initial planning estimate, not a final quotation. '
            'Actual cost and delivery time may change after developers review '
            'the scope. Hosting fees, paid API usage, taxes, and other external '
            'expenses are not included.',
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _loading ? null : _loadEstimate,
          icon: const Icon(Icons.refresh),
          label: const Text('Recalculate estimate'),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return SizedBox(
      width: (MediaQuery.sizeOf(context).width - 52) / 2,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(title, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _costRow(String field, double hours) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(_taskIcon(field), color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _taskLabel(field),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${hours.toStringAsFixed(1)} hours × '
                  '${_formatCost(_hourlyRates[field]!)} / hour',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatCost(hours * _hourlyRates[field]!),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Initial Project Estimate')),
      body: SafeArea(
        child: _loading && _estimate == null
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 18),
                      Text(
                        'Gemini is estimating the project workload...',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : _errorMessage != null && _estimate == null
            ? Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 52),
                      const SizedBox(height: 12),
                      const Text(
                        'Unable to generate estimate',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(_errorMessage!, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _loading ? null : _loadEstimate,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        if (_errorMessage != null) ...[
                          Card(
                            color: Theme.of(context).colorScheme.errorContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(child: Text(_errorMessage!)),
                                  TextButton(
                                    onPressed: _loading ? null : _loadEstimate,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildEstimate(_estimate!),
                      ],
                    ),
                  ),
                  if (_loading) const LinearProgressIndicator(),
                ],
              ),
      ),
    );
  }
}

class _ProjectEstimate {
  final String complexity;
  final String summary;
  final double frontendHours;
  final double backendHours;
  final double databaseHours;
  final double testingHours;
  final double deploymentHours;
  final int durationWeeks;
  final int teamSize;
  final List<String> assumptions;

  const _ProjectEstimate({
    required this.complexity,
    required this.summary,
    required this.frontendHours,
    required this.backendHours,
    required this.databaseHours,
    required this.testingHours,
    required this.deploymentHours,
    required this.durationWeeks,
    required this.teamSize,
    required this.assumptions,
  });

  factory _ProjectEstimate.fromMap(Map<String, dynamic> data) {
    final complexity = data['complexity'];
    final summary = data['summary'];
    final durationWeeks = data['durationWeeks'];
    final teamSize = data['teamSize'];
    final assumptions = data['assumptions'];

    if (!['Low', 'Medium', 'High'].contains(complexity) ||
        summary is! String ||
        durationWeeks is! int ||
        durationWeeks < 1 ||
        durationWeeks > 104 ||
        teamSize is! int ||
        teamSize < 1 ||
        teamSize > 20 ||
        assumptions is! List) {
      throw const FormatException(
        'The estimate service returned invalid details.',
      );
    }

    return _ProjectEstimate(
      complexity: complexity,
      summary: summary,
      frontendHours: _readHours(data, 'frontendHours'),
      backendHours: _readHours(data, 'backendHours'),
      databaseHours: _readHours(data, 'databaseHours'),
      testingHours: _readHours(data, 'testingHours'),
      deploymentHours: _readHours(data, 'deploymentHours'),
      durationWeeks: durationWeeks,
      teamSize: teamSize,
      assumptions: assumptions.whereType<String>().take(5).toList(),
    );
  }

  static double _readHours(Map<String, dynamic> data, String field) {
    final value = data[field];
    if (value is! num || !value.isFinite || value < 0 || value > 100000) {
      throw FormatException('The estimate service returned invalid $field.');
    }
    return value.toDouble();
  }
}
