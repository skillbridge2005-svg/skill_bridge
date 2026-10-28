import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

          return _MeetingDetails(
            meetingId: meetingId,
            data: snapshot.data!.data()!,
          );
        },
      ),
    );
  }
}

class _MeetingDetails extends StatelessWidget {
  final String meetingId;
  final Map<String, dynamic> data;

  const _MeetingDetails({required this.meetingId, required this.data});

  String _stringValue(dynamic value, {String fallback = ''}) {
    final result = value?.toString().trim() ?? '';
    return result.isEmpty ? fallback : result;
  }

  @override
  Widget build(BuildContext context) {
    final title = _stringValue(data['title'], fallback: 'Project Meeting');

    final projectTitle = _stringValue(data['projectTitle']);

    final status = _stringValue(data['status'], fallback: 'scheduled');

    final scheduledValue = data['scheduledAt'];

    final DateTime? scheduledAt = switch (scheduledValue) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      _ => null,
    };

    final duration = data['durationMinutes']?.toString();
    final agenda = _stringValue(data['agenda']);
    final meetingLink = _stringValue(data['meetingLink']);
    final organizerEmail = _stringValue(data['organizerEmail']);

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    final canRespond =
        currentUid != null && _isClientOrParticipant(currentUid, data);

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

                  // OPEN MEETING LINK
                  if (meetingLink.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Join Meeting',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(meetingLink);

                          if (uri == null ||
                              !uri.hasScheme ||
                              (uri.scheme != 'https' && uri.scheme != 'http')) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please check the meeting link.'),
                              ),
                            );
                            return;
                          }

                          try {
                            final launched = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );

                            if (!launched && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to open the meeting link.',
                                  ),
                                ),
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to open the meeting link.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.open_in_browser_rounded),
                        label: const Text('Open Meeting Link in Browser'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      meetingLink,
                      style: const TextStyle(color: Color(0xFF2563EB)),
                    ),
                  ],

                  const Divider(height: 36),

                  // MEETING RESPONSE SECTION
                  const Text(
                    'Meeting Response',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Share your attendance status or submit feedback '
                    'after the meeting.',
                    style: TextStyle(color: Color(0xFF667085), height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  if (canRespond)
                    _MeetingResponseForm(
                      meetingId: meetingId,
                      meetingData: data,
                    )
                  else
                    const Text(
                      'Sign in as an authorized meeting participant '
                      'to submit a response.',
                      style: TextStyle(color: Color(0xFF667085)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isClientOrParticipant(String uid, Map<String, dynamic> meetingData) {
    // These fields must match the participant fields saved
    // by your meeting scheduling screen.
    final participantIds = meetingData['participantIds'];

    final participants = participantIds is List
        ? participantIds.map((value) => value.toString()).toSet()
        : <String>{};

    final organizerId = meetingData['organizerId']?.toString() ?? '';

    final clientId = meetingData['clientId']?.toString() ?? '';

    return participants.contains(uid) || organizerId == uid || clientId == uid;
  }
}

class _MeetingResponseForm extends StatefulWidget {
  final String meetingId;
  final Map<String, dynamic> meetingData;

  const _MeetingResponseForm({
    required this.meetingId,
    required this.meetingData,
  });

  @override
  State<_MeetingResponseForm> createState() => _MeetingResponseFormState();
}

class _MeetingResponseFormState extends State<_MeetingResponseForm> {
  final _formKey = GlobalKey<FormState>();
  final _responseController = TextEditingController();

  String _attendance = 'attending';
  bool _submitting = false;

  Map<String, dynamic> get _existingResponse {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return {};

    final responses = widget.meetingData['responses'];

    if (responses is Map) {
      final response = responses[uid];

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
    }

    return {};
  }

  @override
  void initState() {
    super.initState();

    final existing = _existingResponse;

    final previousAttendance = existing['attendance']?.toString();

    if (previousAttendance == 'attending' ||
        previousAttendance == 'unable_to_join') {
      _attendance = previousAttendance!;
    }

    _responseController.text = existing['message']?.toString() ?? '';
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _submitResponse() async {
    if (_submitting) return;

    if (_attendance == 'attending' && !_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Please sign in first.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final message = _attendance == 'unable_to_join'
          ? (_responseController.text.trim().isEmpty
                ? 'I cannot join today’s meeting.'
                : _responseController.text.trim())
          : _responseController.text.trim();

      await FirebaseFirestore.instance
          .collection('projectMeetings')
          .doc(widget.meetingId)
          .set({
            'responses': {
              user.uid: {
                'userId': user.uid,
                'email': user.email ?? '',
                'attendance': _attendance,
                'message': message,
                'updatedAt': FieldValue.serverTimestamp(),
              },
            },
          }, SetOptions(merge: true));

      if (!mounted) return;

      _showMessage(
        _attendance == 'unable_to_join'
            ? 'Your absence message has been submitted.'
            : 'Your meeting response has been submitted.',
      );
    } catch (error) {
      if (mounted) {
        _showMessage('Unable to submit your response: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Will you attend this meeting?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF344054),
            ),
          ),
          const SizedBox(height: 8),

          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'attending',
            groupValue: _attendance,
            onChanged: _submitting
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _attendance = value);
                    }
                  },
            title: const Text('I will attend'),
            activeColor: const Color(0xFF2563EB),
          ),

          RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            value: 'unable_to_join',
            groupValue: _attendance,
            onChanged: _submitting
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _attendance = value);

                      if (_responseController.text.trim().isEmpty) {
                        _responseController.text =
                            'I cannot join today’s meeting.';
                      }
                    }
                  },
            title: const Text('I cannot join today’s meeting'),
            activeColor: const Color(0xFF2563EB),
          ),

          const SizedBox(height: 8),

          TextFormField(
            controller: _responseController,
            enabled: !_submitting,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: _attendance == 'unable_to_join'
                  ? 'Absence message (optional)'
                  : 'Meeting feedback / response',
              hintText: _attendance == 'unable_to_join'
                  ? 'Explain why you cannot attend...'
                  : 'Share your feedback, decisions, or next steps...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
            validator: (value) {
              if (_attendance == 'attending' &&
                  (value == null || value.trim().isEmpty)) {
                return 'Please enter your meeting response.';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitting ? null : _submitResponse,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Submitting...' : 'Submit Response'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),

          const SizedBox(height: 12),

          const Text(
            'Your response is saved with this meeting and can be '
            'updated later.',
            style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
        ],
      ),
    );
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
          const SizedBox(width: 0),
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
    final normalizedStatus = status.toLowerCase();

    final isCancelled = normalizedStatus == 'cancelled';

    final color = isCancelled
        ? const Color(0xFFB42318)
        : const Color(0xFF027A48);

    final backgroundColor = isCancelled
        ? const Color(0xFFFEF3F2)
        : const Color(0xFFECFDF3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
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
