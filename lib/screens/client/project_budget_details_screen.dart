import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProjectBudgetDetailsScreen extends StatefulWidget {
  final String title;
  final List<String> categories;
  final String description;
  final String requirements;

  const ProjectBudgetDetailsScreen({
    super.key,
    required this.title,
    required this.categories,
    required this.description,
    required this.requirements,
  });

  @override
  State<ProjectBudgetDetailsScreen> createState() =>
      _ProjectBudgetDetailsScreenState();
}

class _ProjectBudgetDetailsScreenState
    extends State<ProjectBudgetDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _budgetController = TextEditingController();
  final _additionalInfoController = TextEditingController();

  String _budgetType = 'Fixed Price';
  String _duration = '2-4 weeks';
  String _experienceLevel = 'Intermediate';
  String _workMode = 'Remote';
  String _priority = 'Medium';

  DateTime? _deadline;

  bool _isSubmitting = false;

  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF667085);
  static const Color _pink = Color(0xFFEC4899);

  static const List<String> _months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];

  final List<String> _durations = [
    'Less than 1 week',
    '1-2 weeks',
    '2-4 weeks',
    '1-2 months',
    '3-6 months',
    'More than 6 months',
    'Flexible',
  ];

  static const List<int> _quickBudgets = [5000, 10000, 25000, 50000, 100000];

  @override
  void initState() {
    super.initState();
    // Keeps the live budget card in sync with the field.
    _budgetController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _budgetController.dispose();
    _additionalInfoController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------- HELPERS
  /// Formats a number with Indian digit grouping, e.g. 1234567 -> 12,34,567
  String _formatInr(double value) {
    final isWhole = value == value.roundToDouble();
    final text = isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    final parts = text.split('.');
    final digits = parts.first;

    String grouped;
    if (digits.length <= 3) {
      grouped = digits;
    } else {
      final last3 = digits.substring(digits.length - 3);
      var rest = digits.substring(0, digits.length - 3);
      final chunks = <String>[];
      while (rest.length > 2) {
        chunks.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) chunks.insert(0, rest);
      grouped = '${chunks.join(',')},$last3';
    }

    return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _priorityColor(String p) {
    switch (p) {
      case 'Low':
        return const Color(0xFF059669);
      case 'Medium':
        return const Color(0xFFF59E0B);
      case 'High':
        return const Color(0xFFEA580C);
      default:
        return const Color(0xFFDC2626);
    }
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryColor),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
    );
  }

  // ------------------------------------------------------ SECTION WIDGETS
  Widget _sectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _ink,
      ),
    ),
  );

  /// Pill-style chips for choosing one value.
  Widget _chipSelector({
    required List<String> items,
    required String value,
    required ValueChanged<String> onChanged,
    Color Function(String)? colorFor,
    Map<String, IconData>? icons,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final selected = item == value;
        final color = colorFor?.call(item) ?? primaryColor;
        return GestureDetector(
          onTap: _isSubmitting ? null : () => onChanged(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? color : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: selected ? color : const Color(0xFFE2E8F0),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.30),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icons != null && icons[item] != null) ...[
                  Icon(
                    icons[item],
                    size: 16,
                    color: selected ? Colors.white : _muted,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  item,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : _ink,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Segmented toggle that fills the width (2-3 options).
  Widget _segmented({
    required List<String> items,
    required String value,
    required ValueChanged<String> onChanged,
    Map<String, IconData>? icons,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: items.map((item) {
          final selected = item == value;
          return Expanded(
            child: GestureDetector(
              onTap: _isSubmitting ? null : () => onChanged(item),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Color(0x1A0F172A),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icons != null && icons[item] != null) ...[
                      Icon(
                        icons[item],
                        size: 17,
                        color: selected ? primaryColor : _muted,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        item,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: selected ? primaryColor : _muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _selectDeadline() async {
    final today = DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _deadline ?? today.add(const Duration(days: 30)),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 5),
      helpText: 'Select project deadline',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _deadline = selectedDate;
    });
  }

  // -------------------------------------------------------------- SUBMIT
  Future<void> _submitProject() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in again to continue.')),
      );
      return;
    }

    final budget = double.tryParse(_budgetController.text.trim());

    if (budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid project budget.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final projectRef = firestore.collection('projects').doc();

      final projectData = <String, dynamic>{
        'projectId': projectRef.id,
        'clientId': user.uid,

        // Information from the previous screen.
        'title': widget.title,
        'categories': widget.categories,
        'description': widget.description,
        'requirements': widget.requirements,

        // Budget and payment details.
        'budget': budget,
        'budgetType': _budgetType,
        'currency': 'INR',

        // Timeline and project details.
        'estimatedDuration': _duration,
        'deadline': _deadline == null ? null : Timestamp.fromDate(_deadline!),
        'experienceLevel': _experienceLevel,
        'workMode': _workMode,
        'priority': _priority,
        'additionalInfo': _additionalInfoController.text.trim(),

        // Project status and timestamps.
        'status': 'requirement',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Save the project.
      await projectRef.set(projectData);

      // Create a notification for the client.
      await firestore
          .collection('users')
          .doc(user.uid)
          .collection('notifications')
          .add({
            'title': 'Project Created Successfully',
            'message': 'Your project "${widget.title}" has been created.',
            'type': 'project',
            'isRead': false,
            'createdAt': FieldValue.serverTimestamp(),
            'projectId': projectRef.id,
          });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project created successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Return true to the previous screen.
      // CreateProjectScreen will then close itself.
      Navigator.pop(context, true);
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to create project: ${e.message ?? e.code}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  // --------------------------------------------------------------- BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Project Details',
          style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: 1,
            minHeight: 4,
            backgroundColor: const Color(0xFFE5E7EB),
            valueColor: const AlwaysStoppedAnimation(primaryColor),
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryHeader(),
                  const SizedBox(height: 18),
                  _buildBudgetSection(),
                  _buildTimelineSection(),
                  _buildPreferencesSection(),
                  _buildNotesSection(),
                  const SizedBox(height: 4),
                  _buildSubmitButton(),
                  const SizedBox(height: 12),
                  const Text(
                    'Review your project details before submitting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF98A2B3)),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------ SUMMARY HEADER
  Widget _buildSummaryHeader() {
    final budget = double.tryParse(_budgetController.text.trim());
    final hasBudget = budget != null && budget > 0;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF312E81), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.30),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: _bubble(120, Colors.white.withOpacity(0.07)),
          ),
          Positioned(
            right: 40,
            bottom: -28,
            child: _bubble(66, _pink.withOpacity(0.28)),
          ),
          Positioned(
            left: -36,
            bottom: -50,
            child: _bubble(100, Colors.white.withOpacity(0.05)),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.rocket_launch_rounded,
                        size: 15,
                        color: Color(0xFFFDE68A),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'LAST STEP  •  ALMOST THERE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: widget.categories.map((category) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE5E7EB),
                    height: 1.5,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                // Live "price tag" that updates as the client types
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sell_rounded,
                        color: Color(0xFFA5B4FC),
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YOUR BUDGET',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 10.5,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                hasBudget ? '₹${_formatInr(budget)}' : '₹ —',
                                key: ValueKey(hasBudget ? budget : -1),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _budgetType == 'Hourly' ? 'PER HOUR' : 'FIXED',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  // -------------------------------------------------------------- BUDGET
  Widget _buildBudgetSection() {
    return _sectionCard(
      title: 'Budget & Payment',
      subtitle: 'Set your budget and payment preferences.',
      icon: Icons.currency_rupee_rounded,
      gradient: const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: _decoration(
              label: _budgetType == 'Hourly'
                  ? 'Hourly Rate (₹)'
                  : 'Total Budget (₹)',
              hint: 'e.g. 25000',
              icon: Icons.currency_rupee_rounded,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your project budget.';
              }

              final amount = double.tryParse(value.trim());

              if (amount == null || amount <= 0) {
                return 'Enter a valid positive amount.';
              }

              return null;
            },
          ),
          const SizedBox(height: 12),
          const Text(
            'Quick pick',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _muted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickBudgets.map((amount) {
              final selected = _budgetController.text.trim() == '$amount';
              return ActionChip(
                label: Text('₹${_formatInr(amount.toDouble())}'),
                backgroundColor: selected
                    ? primaryColor.withOpacity(0.12)
                    : const Color(0xFFF1F5F9),
                side: BorderSide(
                  color: selected ? primaryColor : Colors.transparent,
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? primaryColor : _ink,
                ),
                onPressed: _isSubmitting
                    ? null
                    : () => _budgetController.text = '$amount',
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _label('Payment Type'),
          _segmented(
            items: const ['Fixed Price', 'Hourly'],
            value: _budgetType,
            icons: const {
              'Fixed Price': Icons.lock_outline_rounded,
              'Hourly': Icons.hourglass_bottom_rounded,
            },
            onChanged: (v) => setState(() => _budgetType = v),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ TIMELINE
  Widget _buildTimelineSection() {
    return _sectionCard(
      title: 'Project Timeline',
      subtitle: 'How long do you expect the project to take?',
      icon: Icons.calendar_month_rounded,
      gradient: const [Color(0xFF0EA5E9), Color(0xFF4F46E5)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Estimated Duration'),
          _chipSelector(
            items: _durations,
            value: _duration,
            onChanged: (v) => setState(() => _duration = v),
          ),
          const SizedBox(height: 20),
          _label('Project Deadline (Optional)'),
          InkWell(
            onTap: _isSubmitting ? null : _selectDeadline,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _deadline == null
                    ? const Color(0xFFF8FAFC)
                    : primaryColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _deadline == null
                      ? const Color(0xFFE5E7EB)
                      : primaryColor,
                  width: _deadline == null ? 1 : 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: _deadline == null
                          ? const Color(0xFFE2E8F0)
                          : primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _deadline == null
                              ? '--'
                              : _deadline!.day.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: _deadline == null ? _muted : Colors.white,
                          ),
                        ),
                        Text(
                          _deadline == null
                              ? 'DATE'
                              : _months[_deadline!.month - 1],
                          style: TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w800,
                            color: _deadline == null ? _muted : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _deadline == null
                          ? 'Choose a deadline'
                          : _formatDate(_deadline!),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _deadline == null
                            ? const Color(0xFF98A2B3)
                            : _ink,
                      ),
                    ),
                  ),
                  if (_deadline != null)
                    IconButton(
                      tooltip: 'Clear deadline',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _deadline = null),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded, color: _muted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------- PREFERENCES
  Widget _buildPreferencesSection() {
    return _sectionCard(
      title: 'Developer Preferences',
      subtitle: 'Describe the type of developer you need.',
      icon: Icons.engineering_rounded,
      gradient: const [Color(0xFFEC4899), Color(0xFF7C3AED)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Experience Level'),
          _chipSelector(
            items: const ['Beginner', 'Intermediate', 'Expert'],
            value: _experienceLevel,
            icons: const {
              'Beginner': Icons.eco_rounded,
              'Intermediate': Icons.bolt_rounded,
              'Expert': Icons.workspace_premium_rounded,
            },
            onChanged: (v) => setState(() => _experienceLevel = v),
          ),
          const SizedBox(height: 20),
          _label('Work Arrangement'),
          _segmented(
            items: const ['Remote', 'Hybrid', 'On-site'],
            value: _workMode,
            icons: const {
              'Remote': Icons.home_work_outlined,
              'Hybrid': Icons.swap_horiz_rounded,
              'On-site': Icons.apartment_rounded,
            },
            onChanged: (v) => setState(() => _workMode = v),
          ),
          const SizedBox(height: 20),
          _label('Project Priority'),
          _chipSelector(
            items: const ['Low', 'Medium', 'High', 'Urgent'],
            value: _priority,
            colorFor: _priorityColor,
            icons: const {
              'Low': Icons.flag_outlined,
              'Medium': Icons.flag_outlined,
              'High': Icons.flag_rounded,
              'Urgent': Icons.local_fire_department_rounded,
            },
            onChanged: (v) => setState(() => _priority = v),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- NOTES
  Widget _buildNotesSection() {
    return _sectionCard(
      title: 'Additional Information',
      subtitle: 'Include any extra instructions for developers.',
      icon: Icons.notes_rounded,
      gradient: const [Color(0xFF059669), Color(0xFF0EA5E9)],
      child: TextFormField(
        controller: _additionalInfoController,
        maxLines: 5,
        maxLength: 1500,
        decoration: _decoration(
          label: 'Additional Instructions (Optional)',
          hint:
              'Mention preferred technologies, milestones, '
              'special requirements, or other details...',
          icon: Icons.edit_note_rounded,
        ),
      ),
    );
  }

  // -------------------------------------------------------------- SUBMIT
  Widget _buildSubmitButton() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isSubmitting
              ? [Colors.grey.shade400, Colors.grey.shade500]
              : const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: _isSubmitting
            ? null
            : [
                BoxShadow(
                  color: primaryColor.withOpacity(0.38),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
      ),
      child: FilledButton.icon(
        onPressed: _isSubmitting ? null : _submitProject,
        icon: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.rocket_launch_rounded),
        label: Text(
          _isSubmitting ? 'Creating Project...' : 'Create Project',
          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
