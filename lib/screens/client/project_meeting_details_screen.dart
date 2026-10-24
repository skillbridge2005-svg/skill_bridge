import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProjectMeetingDetailsScreen extends StatelessWidget {
  final String meetingId;

  const ProjectMeetingDetailsScreen({super.key, required this.meetingId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text('Meeting Details'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('projectMeetings')
            .doc(meetingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              message: 'Unable to load meeting details: ${snapshot.error}',
              icon: Icons.error_outline_rounded,
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const _MessageState(
              message: 'This meeting could not be found.',
              icon: Icons.event_busy_outlined,
            );
          }

          return _MeetingDetails(data: snapshot.data!.data()!);
        },
      ),
    );
  }
}

class _MeetingDetails extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MeetingDetails({required this.data});

  @override
  Widget build(BuildContext context) {
    final title = _stringValue(data['title'], fallback: 'Project Meeting');
    final projectTitle = _stringValue(data['projectTitle']);
    final status = _stringValue(data['status'], fallback: 'scheduled');
    final scheduledValue = data['scheduledAt'];
    final scheduledAt = switch (scheduledValue) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      _ => null,
    };
    final duration = data['durationMinutes']?.toString();
    final agenda = _stringValue(data['agenda']);
    final meetingLink = _stringValue(data['meetingLink']);
    final organizerEmail = _stringValue(data['organizerEmail']);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _StatusBadge(status: status),
                    ],
                  ),
                  if (projectTitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _DetailLine(
                      icon: Icons.work_outline_rounded,
                      text: projectTitle,
                    ),
                  ],
                  const Divider(height: 28),
                  _DetailLine(
                    icon: Icons.calendar_today_outlined,
                    text: scheduledAt == null
                        ? 'Date and time not available'
                        : '${MaterialLocalizations.of(context).formatMediumDate(scheduledAt)} '
                              'at ${TimeOfDay.fromDateTime(scheduledAt).format(context)}',
                  ),
                  if (duration != null)
                    _DetailLine(
                      icon: Icons.timelapse_rounded,
                      text: 'Duration: $duration minutes',
                    ),
                  if (organizerEmail.isNotEmpty)
                    _DetailLine(
                      icon: Icons.person_outline_rounded,
                      text: 'Organizer: $organizerEmail',
                    ),
                  if (agenda.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Agenda',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      agenda,
                      style: const TextStyle(
                        height: 1.5,
                        color: Color(0xFF475467),
                      ),
                    ),
                  ],
                  if (meetingLink.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Meeting link',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      meetingLink,
                      style: const TextStyle(color: Color(0xFF2563EB)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF667085)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF475467), height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isCancelled = status.toLowerCase() == 'cancelled';
    final color = isCancelled
        ? const Color(0xFFB42318)
        : const Color(0xFF027A48);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCancelled ? const Color(0xFFFEF3F2) : const Color(0xFFECFDF3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final IconData icon;

  const _MessageState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: const Color(0xFF667085)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
