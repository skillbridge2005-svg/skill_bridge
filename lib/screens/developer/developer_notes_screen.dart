import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/developer_note.dart';
import '../../services/developer_notes_service.dart';
import 'note_editor_screen.dart';

enum _SortMode { recent, oldest, title }

class DeveloperNotesScreen extends StatefulWidget {
  const DeveloperNotesScreen({super.key});

  @override
  State<DeveloperNotesScreen> createState() => _DeveloperNotesScreenState();
}

class _DeveloperNotesScreenState extends State<DeveloperNotesScreen> {
  final DeveloperNotesService _service = DeveloperNotesService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'all';
  String _searchQuery = '';
  _SortMode _sortMode = _SortMode.recent;

  static const Color _primary = Color(0xFF2563EB);
  static const Color _navy = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _line = Color(0xFFE2E8F0);

  static const String _blankNote = '_blank';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _openEditor({DeveloperNote? note, String? category}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(note: note, initialCategory: category),
      ),
    );
  }

  Future<void> _chooseNewNoteType() async {
    HapticFeedback.selectionClick();

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        Widget option({
          required String value,
          required String title,
          required String subtitle,
          required IconData icon,
          required List<Color> colors,
        }) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => Navigator.pop(sheetContext, value),
                child: Ink(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: colors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: Colors.white, size: 23),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: _navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'What are you capturing?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _navy,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pick a type and the editor opens ready for it.',
                  style: TextStyle(fontSize: 12.5, color: _muted),
                ),
                const SizedBox(height: 16),
                option(
                  value: DeveloperNote.projectIdea,
                  title: 'Project Idea',
                  subtitle: 'Problem, solution and technologies',
                  icon: Icons.lightbulb_rounded,
                  colors: const [Color(0xFF7C3AED), Color(0xFFA78BFA)],
                ),
                option(
                  value: DeveloperNote.bugSolution,
                  title: 'Bug & Solution',
                  subtitle: 'Cause, reproduction steps and the fix',
                  icon: Icons.bug_report_rounded,
                  colors: const [Color(0xFFDC2626), Color(0xFFF87171)],
                ),
                option(
                  value: DeveloperNote.dailyWork,
                  title: 'Daily Work',
                  subtitle: 'What you did, learned and plan next',
                  icon: Icons.edit_calendar_rounded,
                  colors: const [Color(0xFF059669), Color(0xFF34D399)],
                ),
                option(
                  value: _blankNote,
                  title: 'Open the editor',
                  subtitle: 'Start without a preset type',
                  icon: Icons.edit_note_rounded,
                  colors: const [Color(0xFF2563EB), Color(0xFF60A5FA)],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null || !mounted) return;

    await _openEditor(category: choice == _blankNote ? null : choice);
  }

  /// Shows the confirmation dialog and deletes the note.
  /// Returns true only if the note was actually deleted.
  Future<bool> _deleteNote(DeveloperNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Delete Note?'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return false;

    try {
      await _service.deleteNote(note.id);

      if (!mounted) return true;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note deleted successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete note: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
  }

  Future<void> _togglePin(DeveloperNote note) async {
    HapticFeedback.selectionClick();

    try {
      await _service.togglePin(noteId: note.id, isPinned: note.isPinned);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update pin: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DATA HELPERS
  // ---------------------------------------------------------------------------

  DateTime? _stamp(DeveloperNote n) => n.updatedAt ?? n.createdAt;

  List<DeveloperNote> _filterNotes(List<DeveloperNote> notes) {
    var result = notes;

    if (_selectedCategory != 'all') {
      result = result
          .where((note) => note.category == _selectedCategory)
          .toList();
    }

    result = List<DeveloperNote>.of(_service.searchNotes(result, _searchQuery));

    int byDate(DeveloperNote a, DeveloperNote b) {
      final ad = _stamp(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = _stamp(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    }

    switch (_sortMode) {
      case _SortMode.recent:
        result.sort(byDate);
        break;
      case _SortMode.oldest:
        result.sort((a, b) => byDate(b, a));
        break;
      case _SortMode.title:
        result.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
    }

    return result;
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case DeveloperNote.projectIdea:
        return Icons.lightbulb_rounded;
      case DeveloperNote.bugSolution:
        return Icons.bug_report_rounded;
      case DeveloperNote.dailyWork:
        return Icons.edit_calendar_rounded;
      default:
        return Icons.sticky_note_2_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case DeveloperNote.projectIdea:
        return const Color(0xFF7C3AED);
      case DeveloperNote.bugSolution:
        return const Color(0xFFDC2626);
      case DeveloperNote.dailyWork:
        return const Color(0xFF059669);
      default:
        return _primary;
    }
  }

  List<Color> _categoryGradient(String category) {
    switch (category) {
      case DeveloperNote.projectIdea:
        return const [Color(0xFF7C3AED), Color(0xFFA78BFA)];
      case DeveloperNote.bugSolution:
        return const [Color(0xFFDC2626), Color(0xFFF87171)];
      case DeveloperNote.dailyWork:
        return const [Color(0xFF059669), Color(0xFF34D399)];
      default:
        return const [Color(0xFF2563EB), Color(0xFF60A5FA)];
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Just now';

    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  String _relative(DateTime? date) {
    if (date == null) return 'Just now';

    final diff = DateTime.now().difference(date.toLocal());

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return _formatDate(date);
  }

  int _readMinutes(String content) {
    final words = content
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;
    return math.max(1, (words / 200).ceil());
  }

  /// Notes touched on each of the last 7 days, oldest first.
  List<int> _weekActivity(List<DeveloperNote> notes) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final counts = List<int>.filled(7, 0);

    for (final n in notes) {
      final d = _stamp(n);
      if (d == null) continue;
      final local = d.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      final ago = today.difference(day).inDays;
      if (ago >= 0 && ago < 7) {
        counts[6 - ago]++;
      }
    }

    return counts;
  }

  String _detailLabel(String key) {
    switch (key) {
      case 'problem':
        return 'Problem';
      case 'solution':
        return 'Solution';
      case 'technologies':
        return 'Technologies';
      case 'possibleCause':
        return 'Possible cause';
      case 'stepsToReproduce':
        return 'Reproduction steps';
      case 'completed':
        return 'Completed';
      case 'challenges':
        return 'Challenges';
      case 'learned':
        return 'Learned';
      case 'tomorrow':
        return 'Tomorrow';
      case 'technology':
        return 'Technology';
      default:
        return key;
    }
  }

  // ---------------------------------------------------------------------------
  // HERO
  // ---------------------------------------------------------------------------

  Widget _buildHero(List<DeveloperNote> allNotes) {
    final week = _weekActivity(allNotes);
    final weekTotal = week.fold<int>(0, (s, c) => s + c);
    final maxDay = week.fold<int>(0, math.max);
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.28),
            blurRadius: 26,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(right: -50, top: -60, child: _bubble(160, 0.07)),
          Positioned(left: -40, bottom: -70, child: _bubble(140, 0.06)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_stories_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'SECOND BRAIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Your Ideas.\nYour Knowledge.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: allNotes.length.toDouble(),
                          ),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => Text(
                            v.round().toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          allNotes.length == 1 ? 'note saved' : 'notes saved',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          weekTotal == 0
                              ? 'Nothing touched this week yet'
                              : '$weekTotal ${weekTotal == 1 ? 'update' : 'updates'} in the last 7 days',
                          style: const TextStyle(
                            color: Color(0xFFC7D2FE),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 138,
                    height: 82,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (i) {
                        final count = week[i];
                        final target = count == 0
                            ? 5.0
                            : 14.0 + 40.0 * (count / math.max(maxDay, 1));
                        final isToday = i == 6;
                        final weekday = today
                            .subtract(Duration(days: 6 - i))
                            .weekday;

                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: target),
                                duration: Duration(milliseconds: 500 + i * 90),
                                curve: Curves.easeOutBack,
                                builder: (context, h, _) => Container(
                                  width: 12,
                                  height: math.max(h, 0),
                                  decoration: BoxDecoration(
                                    color: count == 0
                                        ? Colors.white.withValues(alpha: 0.22)
                                        : (isToday
                                              ? const Color(0xFFFDE68A)
                                              : Colors.white),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                dayLetters[weekday - 1],
                                style: TextStyle(
                                  color: isToday
                                      ? const Color(0xFFFDE68A)
                                      : Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bubble(double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CATEGORY FILTER CARDS
  // ---------------------------------------------------------------------------

  Widget _buildCategoryCards(List<DeveloperNote> allNotes) {
    int count(String c) => allNotes.where((n) => n.category == c).length;

    final cards = [
      _FilterCardData(
        value: 'all',
        label: 'All Notes',
        count: allNotes.length,
        icon: Icons.layers_rounded,
        colors: _categoryGradient('all'),
      ),
      _FilterCardData(
        value: DeveloperNote.projectIdea,
        label: 'Project Ideas',
        count: count(DeveloperNote.projectIdea),
        icon: Icons.lightbulb_rounded,
        colors: _categoryGradient(DeveloperNote.projectIdea),
      ),
      _FilterCardData(
        value: DeveloperNote.bugSolution,
        label: 'Bugs & Solutions',
        count: count(DeveloperNote.bugSolution),
        icon: Icons.bug_report_rounded,
        colors: _categoryGradient(DeveloperNote.bugSolution),
      ),
      _FilterCardData(
        value: DeveloperNote.dailyWork,
        label: 'Daily Work',
        count: count(DeveloperNote.dailyWork),
        icon: Icons.edit_calendar_rounded,
        colors: _categoryGradient(DeveloperNote.dailyWork),
      ),
    ];

    Widget cardAt(int i) {
      final data = cards[i];
      return Expanded(
        child: _FilterCard(
          data: data,
          selected: _selectedCategory == data.value,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedCategory = (_selectedCategory == data.value)
                  ? 'all'
                  : data.value;
            });
          },
        ),
      );
    }

    return Column(
      children: [
        Row(children: [cardAt(0), const SizedBox(width: 12), cardAt(1)]),
        const SizedBox(height: 12),
        Row(children: [cardAt(2), const SizedBox(width: 12), cardAt(3)]),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH
  // ---------------------------------------------------------------------------

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search notes, technologies, or tags...',
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
        prefixIcon: const Icon(Icons.search_rounded, color: _primary),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _primary, width: 1.4),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NOTE CARD
  // ---------------------------------------------------------------------------

  Widget _buildNoteCard(DeveloperNote note, int index) {
    final color = _categoryColor(note.category);

    final details = note.details.entries
        .where(
          (entry) =>
              entry.value != null && entry.value.toString().trim().isNotEmpty,
        )
        .take(2)
        .toList();

    final card = Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openEditor(note: note),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: note.isPinned ? color.withValues(alpha: 0.45) : _line,
              width: note.isPinned ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _navy.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _categoryGradient(note.category),
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: _categoryGradient(note.category),
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.30),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _categoryIcon(note.category),
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      note.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                        color: _navy,
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        note.categoryLabel,
                                        style: TextStyle(
                                          color: color,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: note.isPinned
                                  ? 'Unpin note'
                                  : 'Pin note',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _togglePin(note),
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: Icon(
                                  note.isPinned
                                      ? Icons.push_pin_rounded
                                      : Icons.push_pin_outlined,
                                  key: ValueKey(note.isPinned),
                                  color: note.isPinned
                                      ? color
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                color: Color(0xFF94A3B8),
                              ),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _openEditor(note: note);
                                } else if (value == 'delete') {
                                  _deleteNote(note);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined),
                                      SizedBox(width: 10),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 10),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            note.content,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              height: 1.55,
                              fontSize: 13.5,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                        if (details.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Column(
                              children: details.map((entry) {
                                return Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 7),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _detailLabel(entry.key).toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.9,
                                          color: color,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${entry.value}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                        if (note.tags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: note.tags.take(5).map((tag) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: const TextStyle(
                                      color: Color(0xFF475569),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _relative(_stamp(note)),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.menu_book_rounded,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${_readMinutes(note.content)} min read',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Open',
                              style: TextStyle(
                                fontSize: 12,
                                color: color,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 15,
                              color: color,
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Swipe right = pin / unpin, swipe left = delete (with confirmation).
    final swipeable = Dismissible(
      key: ValueKey('dismiss_${note.id}'),
      background: _swipeBackground(
        alignment: Alignment.centerLeft,
        color: _primary,
        icon: note.isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
        label: note.isPinned ? 'Unpin' : 'Pin',
      ),
      secondaryBackground: _swipeBackground(
        alignment: Alignment.centerRight,
        color: const Color(0xFFDC2626),
        icon: Icons.delete_rounded,
        label: 'Delete',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _togglePin(note);
        } else {
          await _deleteNote(note);
        }
        // The Firestore stream rebuilds the list, so never let the
        // Dismissible remove itself.
        return false;
      },
      child: card,
    );

    return _Reveal(
      key: ValueKey('reveal_${note.id}'),
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: swipeable,
      ),
    );
  }

  Widget _swipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    final left = alignment == Alignment.centerLeft;

    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: left
            ? [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(label, style: _swipeTextStyle),
              ]
            : [
                Text(label, style: _swipeTextStyle),
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white),
              ],
      ),
    );
  }

  static const TextStyle _swipeTextStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w800,
    fontSize: 13,
  );

  // ---------------------------------------------------------------------------
  // LIST HEADINGS + EMPTY STATE
  // ---------------------------------------------------------------------------

  Widget _sectionLabel(String text, IconData icon, {int? count}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _primary),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: _primary,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: _primary,
                ),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: _primary.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool hasNotes}) {
    final filtering = _selectedCategory != 'all' || _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (context, s, child) =>
                  Transform.scale(scale: s, child: child),
              child: Container(
                width: 98,
                height: 98,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _primary.withValues(alpha: 0.16),
                      const Color(0xFF7C3AED).withValues(alpha: 0.14),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  filtering && hasNotes
                      ? Icons.search_off_rounded
                      : Icons.edit_note_rounded,
                  size: 46,
                  color: _primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              filtering && hasNotes ? 'Nothing matches' : 'No notes found',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _navy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filtering && hasNotes
                  ? 'Try another search or clear the filter.'
                  : 'Save project ideas, bug fixes, and daily progress.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            if (filtering && hasNotes)
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'all';
                  });
                },
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Clear filters'),
              )
            else
              FilledButton.icon(
                onPressed: _chooseNewNoteType,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Your First Note'),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'Personal Notes',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
        foregroundColor: _navy,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _chooseNewNoteType,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Create Note',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<DeveloperNote>>(
          stream: _service.watchNotes(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        size: 46,
                        color: Color(0xFFEF4444),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Unable to load notes.\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final allNotes = snapshot.data ?? [];
            final notes = _filterNotes(allNotes);

            final pinned = notes.where((n) => n.isPinned).toList();
            final others = notes.where((n) => !n.isPinned).toList();

            var cardIndex = 0;

            return ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.all(20),
              children: [
                _Reveal(index: 0, child: _buildHero(allNotes)),
                const SizedBox(height: 20),
                _Reveal(index: 1, child: _buildCategoryCards(allNotes)),
                const SizedBox(height: 20),
                _Reveal(index: 2, child: _buildSearch()),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your Notes',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: _navy,
                        ),
                      ),
                    ),
                    Text(
                      '${notes.length} ${notes.length == 1 ? 'note' : 'notes'}',
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    PopupMenuButton<_SortMode>(
                      tooltip: 'Sort notes',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      icon: const Icon(Icons.sort_rounded, color: _primary),
                      initialValue: _sortMode,
                      onSelected: (mode) => setState(() => _sortMode = mode),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: _SortMode.recent,
                          child: Text('Newest first'),
                        ),
                        PopupMenuItem(
                          value: _SortMode.oldest,
                          child: Text('Oldest first'),
                        ),
                        PopupMenuItem(
                          value: _SortMode.title,
                          child: Text('Title A–Z'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (notes.isEmpty)
                  _buildEmptyState(hasNotes: allNotes.isNotEmpty)
                else ...[
                  if (pinned.isNotEmpty) ...[
                    _sectionLabel(
                      'PINNED',
                      Icons.push_pin_rounded,
                      count: pinned.length,
                    ),
                    ...pinned.map((n) => _buildNoteCard(n, cardIndex++)),
                  ],
                  if (others.isNotEmpty) ...[
                    if (pinned.isNotEmpty)
                      _sectionLabel(
                        'EVERYTHING ELSE',
                        Icons.notes_rounded,
                        count: others.length,
                      ),
                    ...others.map((n) => _buildNoteCard(n, cardIndex++)),
                  ],
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Center(
                      child: Text(
                        'Tip: swipe a note right to pin it, left to delete it.',
                        style: TextStyle(color: _muted, fontSize: 11.5),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 90),
              ],
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// SUPPORTING WIDGETS
// =============================================================================

class _Reveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _Reveal({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final ms = 360 + math.min(index, 8) * 80;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, value, c) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 22 * (1 - value)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

class _FilterCardData {
  final String value;
  final String label;
  final int count;
  final IconData icon;
  final List<Color> colors;

  const _FilterCardData({
    required this.value,
    required this.label,
    required this.count,
    required this.icon,
    required this.colors,
  });
}

class _FilterCard extends StatelessWidget {
  final _FilterCardData data;
  final bool selected;
  final VoidCallback onTap;

  const _FilterCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: data.colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Colors.transparent : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? data.colors.first.withValues(alpha: 0.32)
                    : const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: selected ? 16 : 12,
                offset: Offset(0, selected ? 8 : 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.22)
                      : data.colors.first.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  data.icon,
                  size: 19,
                  color: selected ? Colors.white : data.colors.first,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: data.count.toDouble()),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Text(
                        v.round().toString(),
                        style: TextStyle(
                          fontSize: 21,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white.withValues(alpha: 0.9)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
