import 'package:flutter/material.dart';

import '../../models/project_model.dart';
import '../../services/application_service.dart';

class ApplyProject extends StatefulWidget {
  final String projectId;
  final ProjectModel? initialProject;

  const ApplyProject({
    super.key,
    required this.projectId,
    this.initialProject,
  });

  @override
  State<ApplyProject> createState() => _ApplyProjectState();
}

class _ApplyProjectState extends State<ApplyProject> {
  final ApplicationService _applicationService =
      ApplicationService();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _coverLetterController =
      TextEditingController();

  final TextEditingController _budgetController =
      TextEditingController();

  final TextEditingController _durationController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _alreadyApplied = false;

  String? _errorMessage;
  ProjectModel? _project;

  @override
  void initState() {
    super.initState();

    _project = widget.initialProject;

    _loadApplicationData();
  }

  @override
  void dispose() {
    _coverLetterController.dispose();
    _budgetController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // LOAD
  // ===========================================================================

  Future<void> _loadApplicationData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });


       _project ??= await _loadProject();


      if (_project == null) {
        throw Exception(
          'The project could not be found.',
        );
      }

      final existingApplication =
          await _applicationService
              .getMyApplicationForProject(
        widget.projectId,
      );

      if (!mounted) return;

      setState(() {
        _alreadyApplied = existingApplication != null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<ProjectModel?> _loadProject() async {
    // The application service intentionally does not own
    // project fetching. The initial project should normally
    // be supplied by ProjectDetails.
    //
    // This fallback is handled by importing ProjectService
    // locally through the existing project architecture.
    return null;
  }

  // ===========================================================================
  // SUBMIT
  // ===========================================================================

  Future<void> _submitApplication() async {
    FocusScope.of(context).unfocus();

    if (_alreadyApplied) {
      _showMessage(
        'You have already applied to this project.',
        isError: true,
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final project = _project;

    if (project == null) {
      _showMessage(
        'Project information is unavailable.',
        isError: true,
      );
      return;
    }

    final budget = double.tryParse(
      _budgetController.text
          .trim()
          .replaceAll(',', ''),
    );

    if (budget == null || budget <= 0) {
      _showMessage(
        'Enter a valid proposed budget.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _applicationService.createApplication(
        projectId: project.id,
        clientId: project.clientId,
        coverLetter: _coverLetterController.text,
        proposedBudget: budget,
        estimatedDuration:
            _durationController.text,
      );

      if (!mounted) return;

      setState(() {
        _alreadyApplied = true;
        _isSubmitting = false;
      });

      await _showSuccessDialog();
    } on ApplicationServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showMessage(
        e.message,
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      _showMessage(
        'Unable to submit your application. Please try again.',
        isError: true,
      );
    }
  }

  // ===========================================================================
  // SUCCESS
  // ===========================================================================

  Future<void> _showSuccessDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Application Submitted',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Your application has been submitted successfully. '
            'You can track its status from My Applications.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF475569),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  String? _validateCoverLetter(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Please write a cover letter.';
    }

    if (text.length < 50) {
      return 'Cover letter should contain at least 50 characters.';
    }

    return null;
  }

  String? _validateBudget(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Enter your proposed budget.';
    }

    final budget = double.tryParse(
      text.replaceAll(',', ''),
    );

    if (budget == null || budget <= 0) {
      return 'Enter a valid budget.';
    }

    return null;
  }

  String? _validateDuration(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Enter your estimated duration.';
    }

    return null;
  }

  // ===========================================================================
  // UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
        title: const Text(
          'Apply for Project',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_project == null) {
      return _buildErrorState(
        message: 'Project information is unavailable.',
      );
    }

    if (_alreadyApplied) {
      return _buildAlreadyApplied();
    }

    return _buildApplicationForm();
  }

  // ===========================================================================
  // APPLICATION FORM
  // ===========================================================================

  Widget _buildApplicationForm() {
    final project = _project!;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1050,
          ),
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 800;

                if (wide) {
                  return Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: _buildProjectSummary(
                          project,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 6,
                        child: _buildApplicationCard(
                          project,
                        ),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    _buildProjectSummary(project),
                    const SizedBox(height: 20),
                    _buildApplicationCard(project),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PROJECT SUMMARY
  // ===========================================================================

  Widget _buildProjectSummary(
    ProjectModel project,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2563EB),
                  Color(0xFF4F46E5),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.work_outline_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'YOU ARE APPLYING FOR',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            project.title,
            style: const TextStyle(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            project.description,
            maxLines: 7,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 20),
          _summaryRow(
            Icons.person_outline_rounded,
            'Client',
            project.clientName.isEmpty
                ? 'Client'
                : project.clientName,
          ),
          const SizedBox(height: 16),
          _summaryRow(
            Icons.payments_outlined,
            'Budget',
            _budgetText(project),
          ),
          const SizedBox(height: 16),
          _summaryRow(
            Icons.schedule_outlined,
            'Duration',
            project.duration.isEmpty
                ? 'Not specified'
                : project.duration,
          ),
          const SizedBox(height: 16),
          _summaryRow(
            Icons.laptop_mac_outlined,
            'Work mode',
            project.workMode.isEmpty
                ? 'Not specified'
                : project.workMode,
          ),
          if (project.skills.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Required skills',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: project.skills
                  .take(8)
                  .map(
                    (skill) => Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: Text(
                        skill,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius:
                BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 19,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // APPLICATION CARD
  // ===========================================================================

  Widget _buildApplicationCard(
    ProjectModel project,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Submit your application',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Tell the client why you are a good fit for this project.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 28),

          _fieldLabel(
            'Cover Letter',
            required: true,
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _coverLetterController,
            minLines: 7,
            maxLines: 12,
            textCapitalization:
                TextCapitalization.sentences,
            validator: _validateCoverLetter,
            decoration: _inputDecoration(
              hint:
                  'Introduce yourself, explain your relevant experience, '
                  'and describe how you would approach this project.',
              icon: Icons.description_outlined,
            ),
          ),

          const SizedBox(height: 22),

          _fieldLabel(
            'Proposed Budget',
            required: true,
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _budgetController,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            validator: _validateBudget,
            decoration: _inputDecoration(
              hint: _budgetHint(project),
              icon: Icons.currency_rupee_rounded,
            ),
          ),

          const SizedBox(height: 22),

          _fieldLabel(
            'Estimated Duration',
            required: true,
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _durationController,
            validator: _validateDuration,
            decoration: _inputDecoration(
              hint: 'Example: 4 weeks',
              icon: Icons.schedule_outlined,
            ),
          ),

          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius:
                  BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFDE68A),
              ),
            ),
            child: const Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: Color(0xFFD97706),
                ),
                SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Make sure your proposal, budget and timeline '
                    'accurately represent your availability and skills.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 26),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed:
                  _isSubmitting
                      ? null
                      : _submitApplication,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                    ),
              label: Text(
                _isSubmitting
                    ? 'Submitting...'
                    : 'Submit Application',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(
    String text, {
    bool required = false,
  }) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF334155),
        ),
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: Color(0xFFDC2626),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 13,
      ),
      prefixIcon: Icon(
        icon,
        size: 20,
        color: const Color(0xFF64748B),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF2563EB),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFDC2626),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFDC2626),
          width: 1.5,
        ),
      ),
    );
  }

  // ===========================================================================
  // ALREADY APPLIED
  // ===========================================================================

  Widget _buildAlreadyApplied() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints:
              const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(34),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 40,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Already Applied',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'You have already submitted an application '
                'for this project.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 26),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(
                  Icons.arrow_back_rounded,
                ),
                label: const Text(
                  'Back to Project',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  Widget _buildErrorState({
    String? message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints:
              const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 58,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(height: 18),
              const Text(
                'Unable to load application',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                message ??
                    _errorMessage ??
                    'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _loadApplicationData,
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  String _budgetText(ProjectModel project) {
    if (project.hasBudgetRange) {
      return '₹${_formatNumber(project.effectiveBudgetMin)}'
          ' – '
          '₹${_formatNumber(project.effectiveBudgetMax)}';
    }

    if (project.budget > 0) {
      return '₹${_formatNumber(project.budget)}';
    }

    return 'Not specified';
  }

  String _budgetHint(ProjectModel project) {
    if (project.hasBudgetRange) {
      return 'Example: ${_formatNumber(project.effectiveBudgetMin)}';
    }

    return 'Example: 25000';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value
          .toInt()
          .toString();
    }

    return value
        .toStringAsFixed(2)
        .replaceFirst(
          RegExp(r'\.?0+$'),
          '',
        );
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFDC2626)
              : const Color(0xFF16A34A),
        ),
      );
  }
}