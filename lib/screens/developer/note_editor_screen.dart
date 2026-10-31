import 'package:flutter/material.dart';

import '../../models/developer_note.dart';
import '../../services/developer_notes_service.dart';
import 'developer_notes_screen.dart';

class NoteEditorScreen extends StatefulWidget {
  final DeveloperNote? note;
  final String? initialCategory;
  final String? projectId;

  const NoteEditorScreen({
    super.key,
    this.note,
    this.initialCategory,
    this.projectId,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesService = DeveloperNotesService();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagsController = TextEditingController();

  final _problemController = TextEditingController();
  final _solutionController = TextEditingController();
  final _technologiesController = TextEditingController();

  final _possibleCauseController = TextEditingController();
  final _stepsController = TextEditingController();

  final _completedController = TextEditingController();
  final _challengesController = TextEditingController();
  final _learnedController = TextEditingController();
  final _tomorrowController = TextEditingController();

  late String _category;
  bool _saving = false;

  static const Color _primary = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();

    final note = widget.note;

    _category =
        note?.category ?? widget.initialCategory ?? DeveloperNote.projectIdea;

    if (note != null) {
      _titleController.text = note.title;
      _contentController.text = note.content;
      _tagsController.text = note.tags.join(', ');

      final details = note.details;

      _problemController.text = details['problem'] ?? '';
      _solutionController.text = details['solution'] ?? '';
      _technologiesController.text = details['technologies'] ?? '';

      _possibleCauseController.text = details['possibleCause'] ?? '';
      _stepsController.text = details['stepsToReproduce'] ?? '';

      _completedController.text = details['completed'] ?? '';
      _challengesController.text = details['challenges'] ?? '';
      _learnedController.text = details['learned'] ?? '';
      _tomorrowController.text = details['tomorrow'] ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();

    _problemController.dispose();
    _solutionController.dispose();
    _technologiesController.dispose();

    _possibleCauseController.dispose();
    _stepsController.dispose();

    _completedController.dispose();
    _challengesController.dispose();
    _learnedController.dispose();
    _tomorrowController.dispose();

    super.dispose();
  }

  bool get _isProjectIdea => _category == DeveloperNote.projectIdea;

  bool get _isBugSolution => _category == DeveloperNote.bugSolution;

  bool get _isDailyWork => _category == DeveloperNote.dailyWork;

  String get _categoryLabel {
    if (_isProjectIdea) return 'Project Ideas';
    if (_isBugSolution) return 'Bugs & Solutions';
    return 'Daily Work';
  }

  IconData get _categoryIcon {
    if (_isProjectIdea) return Icons.lightbulb_outline;
    if (_isBugSolution) return Icons.bug_report_outlined;
    return Icons.edit_calendar_outlined;
  }

  Map<String, dynamic> _buildDetails() {
    if (_isProjectIdea) {
      return {
        'problem': _problemController.text.trim(),
        'solution': _solutionController.text.trim(),
        'technologies': _technologiesController.text.trim(),
      };
    }

    if (_isBugSolution) {
      return {
        'possibleCause': _possibleCauseController.text.trim(),
        'stepsToReproduce': _stepsController.text.trim(),
        'solution': _solutionController.text.trim(),
        'technology': _technologiesController.text.trim(),
      };
    }

    return {
      'completed': _completedController.text.trim(),
      'challenges': _challengesController.text.trim(),
      'learned': _learnedController.text.trim(),
      'tomorrow': _tomorrowController.text.trim(),
    };
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList();

      final details = _buildDetails();

      if (widget.note == null) {
        await _notesService.createNote(
          title: _titleController.text.trim(),
          category: _category,
          content: _contentController.text.trim(),
          details: details,
          tags: tags,
          projectId: widget.projectId,
        );
      } else {
        await _notesService.updateNote(
          noteId: widget.note!.id,
          title: _titleController.text.trim(),
          category: _category,
          content: _contentController.text.trim(),
          details: details,
          tags: tags,
          projectId: widget.projectId ?? widget.note!.projectId,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.note == null
                ? 'Note created successfully!'
                : 'Note updated successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to save note: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    String? hint,
    IconData? icon,
    int maxLines = 1,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: _inputDecoration(label, hint: hint, icon: icon),
        validator: required
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label is required';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 14),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFields() {
    if (_isProjectIdea) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Project Details'),
          _buildTextField(
            _problemController,
            'Problem or Idea',
            hint: 'What problem do you want to solve?',
            icon: Icons.report_problem_outlined,
            maxLines: 3,
          ),
          _buildTextField(
            _solutionController,
            'Proposed Solution',
            hint: 'How will your project solve it?',
            icon: Icons.tips_and_updates_outlined,
            maxLines: 4,
          ),
          _buildTextField(
            _technologiesController,
            'Technologies',
            hint: 'Java, Flutter, Firebase, MySQL...',
            icon: Icons.code,
            maxLines: 2,
          ),
        ],
      );
    }

    if (_isBugSolution) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Bug Details'),
          _buildTextField(
            _technologiesController,
            'Technology',
            hint: 'Flutter, Firebase, Java, SQL...',
            icon: Icons.developer_mode,
          ),
          _buildTextField(
            _contentController,
            'Problem or Error Message',
            hint: 'Describe the error you encountered',
            icon: Icons.error_outline,
            maxLines: 4,
            required: true,
          ),
          _buildTextField(
            _possibleCauseController,
            'Possible Cause',
            hint: 'What might have caused this error?',
            icon: Icons.search,
            maxLines: 3,
          ),
          _buildTextField(
            _stepsController,
            'Steps to Reproduce',
            hint: 'Steps required to reproduce the bug',
            icon: Icons.format_list_numbered,
            maxLines: 3,
          ),
          _buildTextField(
            _solutionController,
            'Solution',
            hint: 'How did you fix it?',
            icon: Icons.check_circle_outline,
            maxLines: 4,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Daily Progress'),
        _buildTextField(
          _completedController,
          'Tasks Completed',
          hint: 'What did you finish today?',
          icon: Icons.task_alt,
          maxLines: 3,
        ),
        _buildTextField(
          _challengesController,
          'Problems Encountered',
          hint: 'What difficulties did you face?',
          icon: Icons.warning_amber_outlined,
          maxLines: 3,
        ),
        _buildTextField(
          _learnedController,
          'What I Learned',
          hint: 'New concepts, tools, or techniques',
          icon: Icons.school_outlined,
          maxLines: 3,
        ),
        _buildTextField(
          _tomorrowController,
          'Tasks for Tomorrow',
          hint: 'What do you plan to do next?',
          icon: Icons.event_note,
          maxLines: 3,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.note != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Note' : 'Create Note'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            _categoryIcon,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditing ? 'Update Your Note' : 'New Note',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _categoryLabel,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('Basic Information'),

                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: _inputDecoration(
                      'Note Category',
                      icon: Icons.category_outlined,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: DeveloperNote.projectIdea,
                        child: Text('Project Ideas'),
                      ),
                      DropdownMenuItem(
                        value: DeveloperNote.bugSolution,
                        child: Text('Bugs & Solutions'),
                      ),
                      DropdownMenuItem(
                        value: DeveloperNote.dailyWork,
                        child: Text('Daily Work'),
                      ),
                    ],
                    onChanged: isEditing
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() {
                                _category = value;
                              });
                            }
                          },
                  ),

                  const SizedBox(height: 18),

                  _buildTextField(
                    _titleController,
                    'Note Title',
                    hint: _isProjectIdea
                        ? 'e.g. AI Resume Analyzer'
                        : _isBugSolution
                        ? 'e.g. Firebase Login Error'
                        : 'e.g. Development Progress',
                    icon: Icons.title,
                    required: true,
                  ),

                  if (!_isBugSolution)
                    _buildTextField(
                      _contentController,
                      _isProjectIdea ? 'Project Overview' : 'Work Summary',
                      hint: _isProjectIdea
                          ? 'Describe your project idea'
                          : 'Summarize your work today',
                      icon: Icons.description_outlined,
                      maxLines: 4,
                      required: true,
                    ),

                  _buildCategoryFields(),

                  _buildSectionTitle('Tags'),

                  _buildTextField(
                    _tagsController,
                    'Tags (comma-separated)',
                    hint: 'Flutter, Java, Firebase',
                    icon: Icons.sell_outlined,
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _saveNote,
                      icon: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _saving
                            ? 'Saving...'
                            : isEditing
                            ? 'Update Note'
                            : 'Save Note',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => DeveloperNotesScreen(
                              projectId: widget.projectId,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.notes_rounded),
                      label: const Text('Show Notes'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
