import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/notification_service.dart';

class ProjectMeetingScreen extends StatefulWidget {
  final String projectId;
  final String projectTitle;

  const ProjectMeetingScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ProjectMeetingScreen> createState() => _ProjectMeetingScreenState();
}

class _ProjectMeetingScreenState extends State<ProjectMeetingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _agendaController = TextEditingController();
  final _linkController = TextEditingController();

  final Set<String> _selectedMembers = {};
  final NotificationService _notificationService = NotificationService();
  late Future<List<Map<String, dynamic>>> _participantsFuture;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  int _durationMinutes = 30;
  bool _saving = false;

  // Palette
  final Color _primaryColor = const Color(0xFF2563EB);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _violet = Color(0xFF7C3AED);
  static const Color _pink = Color(0xFFEC4899);

  static const List<int> _durations = [15, 30, 45, 60, 90, 120];
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

  @override
  void initState() {
    super.initState();
    _participantsFuture = _loadProjectParticipants();
    // Keeps the live preview card in sync with the title field.
    _titleController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _agendaController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- LOGIC
  Future<void> _selectDate() async {
    final now = DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );

    if (date != null && mounted) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (time != null && mounted) {
      setState(() => _selectedTime = time);
    }
  }

  DateTime? get _meetingDateTime {
    if (_selectedDate == null || _selectedTime == null) {
      return null;
    }

    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  Future<List<Map<String, dynamic>>> _loadProjectParticipants() async {
    final firestore = FirebaseFirestore.instance;

    final projectSnapshot = await firestore
        .collection('projects')
        .doc(widget.projectId)
        .get();

    if (!projectSnapshot.exists) {
      throw StateError('Project not found.');
    }

    final projectData = projectSnapshot.data();

    if (projectData == null) {
      throw StateError('Project data is unavailable.');
    }

    final participantIds = <String>{};
    final clientId = projectData['clientId']?.toString().trim() ?? '';
    final assignedDeveloperId =
        projectData['developerId']?.toString().trim() ?? '';

    if (clientId.isNotEmpty) {
      participantIds.add(clientId);
    }

    if (assignedDeveloperId.isNotEmpty) {
      participantIds.add(assignedDeveloperId);
    }

    final teamsSnapshot = await firestore
        .collection('teams')
        .where('projectId', isEqualTo: widget.projectId)
        .get();

    for (final team in teamsSnapshot.docs) {
      final teamData = team.data();

      if (teamData['status']?.toString().trim().toLowerCase() != 'active') {
        continue;
      }

      final memberIds = teamData['memberIds'];

      if (memberIds is List) {
        for (final memberId in memberIds) {
          final id = memberId.toString().trim();

          if (id.isNotEmpty) {
            participantIds.add(id);
          }
        }
      }
    }

    final participants = await Future.wait(
      participantIds.map((participantId) async {
        final userSnapshot = await firestore
            .collection('users')
            .doc(participantId)
            .get();
        final userData = userSnapshot.data() ?? <String, dynamic>{};
        final role = participantId == clientId ? 'Client' : 'Developer';
        final storedName = (userData['name'] ?? userData['displayName'] ?? '')
            .toString()
            .trim();

        return <String, dynamic>{
          'id': participantId,
          'name': storedName.isEmpty ? 'Project Participant' : storedName,
          'email': (userData['email'] ?? '').toString(),
          'role': role,
        };
      }),
    );

    participants.sort((a, b) {
      if (a['role'] == 'Client') return -1;
      if (b['role'] == 'Client') return 1;

      return (a['name'] as String).compareTo(b['name'] as String);
    });

    return participants;
  }

  Future<void> _scheduleMeeting() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      _showMessage('Please select the meeting date and time.');
      return;
    }

    final meetingDateTime = _meetingDateTime!;

    if (!meetingDateTime.isAfter(DateTime.now())) {
      _showMessage('Please select a future date and time.');
      return;
    }

    if (_selectedMembers.isEmpty) {
      _showMessage('Please select at least one team member.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please log in to schedule a meeting.');
      return;
    }

    setState(() => _saving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final allParticipants = await _loadProjectParticipants();
      final selectedParticipants = allParticipants
          .where((participant) => _selectedMembers.contains(participant['id']))
          .map((participant) {
            return <String, dynamic>{
              'participantId': participant['id'],
              'name': participant['name'],
              'email': participant['email'],
              'role': participant['role'],
            };
          })
          .toList();

      if (selectedParticipants.isEmpty) {
        _showMessage('Please select at least one participant.');
        return;
      }

      final meetingRef = await firestore.collection('projectMeetings').add({
        'projectId': widget.projectId,
        'projectTitle': widget.projectTitle,
        'title': _titleController.text.trim(),
        'agenda': _agendaController.text.trim(),
        'scheduledAt': Timestamp.fromDate(meetingDateTime),
        'durationMinutes': _durationMinutes,
        'meetingLink': _linkController.text.trim(),
        'organizerId': user.uid,
        'organizerEmail': user.email ?? '',
        'participants': selectedParticipants,
        'participantIds': selectedParticipants
            .map((participant) => participant['participantId'])
            .toList(),
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      var failedInvitations = 0;
      for (final participant in selectedParticipants) {
        try {
          final participantId = participant['participantId']?.toString() ?? '';
          final isClient = participant['role'] == 'Client';

          if (isClient) {
            await firestore
                .collection('users')
                .doc(participantId)
                .collection('notifications')
                .add({
                  'title': 'New Project Meeting',
                  'message': 'You have been invited to a project meeting.',
                  'type': 'meeting_invitation',
                  'projectId': widget.projectId,
                  'meetingId': meetingRef.id,
                  'isRead': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });
          } else {
            await _notificationService.createNotification(
              developerId: participantId,
              title: 'New Project Meeting',
              body: 'You have been invited to a project meeting.',
              type: 'meeting_invitation',
              projectId: widget.projectId,
              meetingId: meetingRef.id,
            );
          }
        } catch (e) {
          failedInvitations++;
          debugPrint('Failed to notify a meeting participant: $e');
        }
      }

      if (!mounted) return;

      _titleController.clear();
      _agendaController.clear();
      _linkController.clear();

      setState(() {
        _selectedMembers.clear();
        _selectedDate = null;
        _selectedTime = null;
        _durationMinutes = 30;
      });

      _showMessage(
        failedInvitations == 0
            ? 'Meeting scheduled successfully!'
            : 'Meeting scheduled, but $failedInvitations invitation(s) could not be sent.',
      );
    } catch (e) {
      _showMessage('Failed to schedule meeting: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');

    return '$d/$m/${date.year}';
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return h == 1 ? '1 hr' : '$h hrs';
    return '$h hr $m min';
  }

  // --------------------------------------------------------------- BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text(
          'Schedule Meeting',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: _ink,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 750),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildPreviewCard(),
                  const SizedBox(height: 18),
                  _buildMeetingForm(),
                  const SizedBox(height: 30),
                  _buildUpcomingMeetings(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- HEADER
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.30),
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
            child: _bubble(120, Colors.white.withValues(alpha: 0.08)),
          ),
          Positioned(
            right: 50,
            bottom: -26,
            child: _bubble(64, _pink.withValues(alpha: 0.30)),
          ),
          Positioned(
            left: -36,
            bottom: -50,
            child: _bubble(100, Colors.white.withValues(alpha: 0.06)),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.video_call_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Plan Your Project\nMeeting 🗓️',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.folder_open_rounded,
                        size: 15,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          widget.projectTitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
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

  // ------------------------------------------------------- LIVE PREVIEW
  Widget _buildPreviewCard() {
    final title = _titleController.text.trim();
    final date = _selectedDate;
    final time = _selectedTime;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date badge
          Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: date == null
                    ? [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)]
                    : [_primaryColor, _violet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  date == null ? '--' : date.day.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  date == null ? 'DATE' : _months[date.month - 1],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MEETING PREVIEW',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title.isEmpty ? 'Untitled meeting' : title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: title.isEmpty ? _muted : _ink,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _miniChip(
                      Icons.access_time_rounded,
                      time == null ? 'Pick time' : time.format(context),
                    ),
                    _miniChip(
                      Icons.timelapse_rounded,
                      _durationLabel(_durationMinutes),
                    ),
                    _miniChip(
                      Icons.group_rounded,
                      _selectedMembers.isEmpty
                          ? 'No invitees'
                          : '${_selectedMembers.length} invited',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _primaryColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- FORM
  Widget _sectionHeader(int number, String title, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_primaryColor, _violet]),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildMeetingForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(1, 'What\'s it about?'),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _titleController,
              label: 'Meeting Title',
              hint: 'e.g. Project Progress Discussion',
              icon: Icons.event,
            ),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _agendaController,
              label: 'Meeting Agenda',
              hint: 'What will you discuss?',
              icon: Icons.notes,
              maxLines: 3,
            ),
            const SizedBox(height: 26),
            _buildTeamHeader(),
            const SizedBox(height: 12),
            _buildTeamSelector(),
            const SizedBox(height: 26),
            _sectionHeader(3, 'When?'),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _pickerTile(
                    icon: Icons.calendar_month_rounded,
                    label: 'Date',
                    value: _selectedDate == null
                        ? 'Select date'
                        : _formatDate(_selectedDate!),
                    selected: _selectedDate != null,
                    onTap: _selectDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _pickerTile(
                    icon: Icons.access_time_rounded,
                    label: 'Time',
                    value: _selectedTime == null
                        ? 'Select time'
                        : _selectedTime!.format(context),
                    selected: _selectedTime != null,
                    onTap: _selectTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Duration',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: _ink,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _durations.map((m) {
                final selected = _durationMinutes == m;
                return ChoiceChip(
                  label: Text(_durationLabel(m)),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: _primaryColor,
                  backgroundColor: const Color(0xFFF1F5F9),
                  side: BorderSide.none,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    color: selected ? Colors.white : _ink,
                  ),
                  onSelected: (_) => setState(() => _durationMinutes = m),
                );
              }).toList(),
            ),
            const SizedBox(height: 26),
            _sectionHeader(4, 'Where?'),
            const SizedBox(height: 14),
            _buildTextField(
              controller: _linkController,
              label: 'Online Meeting Link (Optional)',
              hint: 'https://meet.google.com/...',
              icon: Icons.link,
              required: false,
            ),
            const SizedBox(height: 26),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required String value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? _primaryColor.withValues(alpha: 0.07) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? _primaryColor : const Color(0xFFE2E8F0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _primaryColor : _muted, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: selected ? _ink : _muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _saving
              ? [Colors.grey.shade400, Colors.grey.shade500]
              : [_primaryColor, _violet],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _saving
            ? null
            : [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ElevatedButton.icon(
        onPressed: _saving ? null : _scheduleMeeting,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.event_available),
        label: Text(
          _saving ? 'Scheduling...' : 'Schedule Meeting',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool required = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _primaryColor, width: 1.6),
        ),
      ),
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return '$label is required';
        }

        return null;
      },
    );
  }

  // ---------------------------------------------------------------- TEAM
  Widget _buildTeamHeader() {
    return _sectionHeader(
      2,
      'Invite team members',
      trailing: _selectedMembers.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_selectedMembers.length} selected',
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
    );
  }

  Widget _buildTeamSelector() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _participantsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text(
            'Unable to load project participants: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final participants = snapshot.data ?? <Map<String, dynamic>>[];

        if (participants.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No project participants were found.'),
          );
        }

        final allSelected = participants.every(
          (participant) => _selectedMembers.contains(participant['id']),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Select Meeting Participants',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (allSelected) {
                        _selectedMembers.clear();
                      } else {
                        _selectedMembers.addAll(
                          participants.map(
                            (participant) => participant['id'] as String,
                          ),
                        );
                      }
                    });
                  },
                  icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
                  label: Text(allSelected ? 'Clear all' : 'Select all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...participants.map((participant) {
              final id = participant['id'] as String;
              final name = participant['name'] as String;
              final email = participant['email'] as String;
              final role = participant['role'] as String;
              final selected = _selectedMembers.contains(id);
              final isClient = role == 'Client';

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: selected ? _primaryColor : const Color(0xFFE2E8F0),
                  ),
                ),
                child: CheckboxListTile(
                  value: selected,
                  activeColor: _primaryColor,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedMembers.add(id);
                      } else {
                        _selectedMembers.remove(id);
                      }
                    });
                  },
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isClient
                              ? const Color(0xFFDCFCE7)
                              : const Color(0xFFDBEAFE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isClient
                                ? const Color(0xFF166534)
                                : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    email.isEmpty ? id : email,
                    style: const TextStyle(fontSize: 12, color: _muted),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------ MEETINGS
  Widget _buildUpcomingMeetings() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.event_note_rounded, color: _ink),
            SizedBox(width: 8),
            Text(
              'Project Meetings',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('projectMeetings')
              .where('projectId', isEqualTo: widget.projectId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Unable to load project meetings.');
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final meetings = [...?snapshot.data?.docs];

            meetings.sort((a, b) {
              final aTime =
                  (a.data()['scheduledAt'] as Timestamp?)?.toDate() ??
                  DateTime(2000);
              final bTime =
                  (b.data()['scheduledAt'] as Timestamp?)?.toDate() ??
                  DateTime(2000);

              return aTime.compareTo(bTime);
            });

            if (meetings.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 44,
                      color: _primaryColor.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'No meetings scheduled for this project yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _muted),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: meetings
                  .map((doc) => _buildMeetingCard(doc, user))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMeetingCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    User user,
  ) {
    final meeting = doc.data();

    final scheduledAt = (meeting['scheduledAt'] as Timestamp?)?.toDate();

    final status = (meeting['status'] ?? 'scheduled').toString();
    final cancelled = status == 'cancelled';
    final duration = meeting['durationMinutes'] ?? 30;
    final agenda = (meeting['agenda'] ?? '').toString();
    final link = (meeting['meetingLink'] ?? '').toString();
    final participants = (meeting['participants'] as List?) ?? const [];
    final rawResponses = meeting['responses'];
    final Map<String, dynamic> responses = rawResponses is Map
        ? Map<String, dynamic>.from(rawResponses)
        : <String, dynamic>{};

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date badge
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: cancelled
                    ? [Colors.grey.shade400, Colors.grey.shade500]
                    : [_primaryColor, _violet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  scheduledAt == null
                      ? '--'
                      : scheduledAt.day.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  scheduledAt == null ? '' : _months[scheduledAt.month - 1],
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (meeting['title'] ?? 'Meeting').toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: cancelled ? _muted : _ink,
                          decoration: cancelled
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statusBadge(status),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (scheduledAt != null)
                      _miniChip(
                        Icons.access_time_rounded,
                        '${_formatDate(scheduledAt)} • '
                        '${TimeOfDay.fromDateTime(scheduledAt).format(context)}',
                      ),
                    _miniChip(Icons.timelapse_rounded, '$duration min'),
                    if (participants.isNotEmpty)
                      _miniChip(
                        Icons.group_rounded,
                        '${participants.length} invited',
                      ),
                  ],
                ),
                if (agenda.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    agenda,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: _muted,
                    ),
                  ),
                ],
                if (link.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.only(left: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SelectableText(
                            link,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy link',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.copy_rounded, size: 16),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: link));
                            _showMessage('Meeting link copied.');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                if (link.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.tryParse(link.trim());

                        if (uri == null ||
                            !uri.hasScheme ||
                            (uri.scheme != 'https' && uri.scheme != 'http')) {
                          _showMessage('Please check the meeting link.');
                          return;
                        }

                        try {
                          final opened = await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );

                          if (!opened && mounted) {
                            _showMessage('Unable to open the meeting link.');
                          }
                        } catch (e) {
                          debugPrint('Unable to open meeting link: $e');
                          if (mounted) {
                            _showMessage('Unable to open the meeting link.');
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_browser_rounded),
                      label: const Text('Open Meeting Link'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
                if (responses.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.forum_outlined,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Meeting Responses',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDBEAFE),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${responses.length} response(s)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...responses.entries.map((entry) {
                          final response = entry.value;

                          if (response is! Map) {
                            return const SizedBox.shrink();
                          }

                          final attendance =
                              (response['attendance'] ?? 'unknown').toString();
                          final message = (response['message'] ?? '')
                              .toString()
                              .trim();
                          final email = (response['email'] ?? '')
                              .toString()
                              .trim();
                          final isUnableToJoin = attendance == 'unable_to_join';
                          final label = isUnableToJoin
                              ? 'Cannot attend'
                              : attendance == 'attending'
                              ? 'Will attend'
                              : attendance;
                          final statusColor = isUnableToJoin
                              ? const Color(0xFFB42318)
                              : const Color(0xFF027A48);
                          final statusBackground = isUnableToJoin
                              ? const Color(0xFFFEF3F2)
                              : const Color(0xFFECFDF3);

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.person_outline_rounded,
                                      size: 17,
                                      color: Color(0xFF64748B),
                                    ),
                                    Text(
                                      email.isEmpty
                                          ? 'Meeting participant'
                                          : email,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF344054),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusBackground,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        label,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (message.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Response:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF475467),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.5,
                                      color: Color(0xFF475467),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
                if (meeting['organizerId'] == user.uid &&
                    status == 'scheduled') ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            _rescheduleMeeting(doc.id, scheduledAt),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.edit_calendar, size: 18),
                        label: const Text('Reschedule'),
                      ),
                      TextButton.icon(
                        onPressed: () => _cancelMeeting(doc.id),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                        ),
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final cancelled = status == 'cancelled';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cancelled ? Colors.red.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: cancelled ? Colors.red : Colors.green.shade700,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> _rescheduleMeeting(
    String meetingId,
    DateTime? existingDate,
  ) async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: existingDate != null && existingDate.isAfter(now)
          ? existingDate
          : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: existingDate != null
          ? TimeOfDay.fromDateTime(existingDate)
          : TimeOfDay.now(),
    );

    if (pickedTime == null || !mounted) return;

    final newDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!newDateTime.isAfter(DateTime.now())) {
      _showMessage('Please choose a future date and time.');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('projectMeetings')
          .doc(meetingId)
          .update({
            'scheduledAt': Timestamp.fromDate(newDateTime),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _showMessage('Meeting rescheduled successfully.');
    } catch (e) {
      _showMessage('Unable to reschedule meeting: $e');
    }
  }

  Future<void> _cancelMeeting(String meetingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Meeting?'),
          content: const Text('Are you sure you want to cancel this meeting?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep Meeting'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Cancel Meeting'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('projectMeetings')
          .doc(meetingId)
          .update({
            'status': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      _showMessage('Meeting cancelled.');
    } catch (e) {
      _showMessage('Unable to cancel meeting: $e');
    }
  }
}


