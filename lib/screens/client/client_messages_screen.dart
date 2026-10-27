import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../localization/app_localizations.dart';

class ClientMessagesScreen extends StatelessWidget {
  const ClientMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: Text(
          l10n.loginAgain,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFFF6F8FC),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _MessagesAmbientPainter()),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .where('clientId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: _MessagesLoader());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _MessagesErrorCard(
                      message:
                          '${l10n.unableToLoadMessages}\n${snapshot.error}',
                    ),
                  ),
                );
              }

              final projects = snapshot.data?.docs ?? [];

              if (projects.isEmpty) {
                return const _EmptyMessages();
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const _MessagesSectionHeading(),
                        const SizedBox(height: 16),
                        Column(
                          children: projects
                              .map(
                                (projectDoc) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _ConversationCard(
                                    projectId: projectDoc.id,
                                    projectTitle:
                                        projectDoc
                                            .data()['title']
                                            ?.toString() ??
                                        l10n.project,
                                    category:
                                        projectDoc
                                            .data()['category']
                                            ?.toString() ??
                                        '',
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MessagesSectionHeading extends StatelessWidget {
  const _MessagesSectionHeading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.messages.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.25,
            color: Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.messages,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.continueConversations,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final String projectId;
  final String projectTitle;
  final String category;

  const _ConversationCard({
    required this.projectId,
    required this.projectTitle,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        String lastMessage = l10n.noMessagesYet;
        String senderName = '';

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final message = snapshot.data!.docs.first.data();

          lastMessage = message['message']?.toString() ?? l10n.noMessagesYet;

          senderName = message['senderName']?.toString() ?? '';
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClientProjectChat(
                    projectId: projectId,
                    projectTitle: projectTitle,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(22),
            child: Ink(
              width: double.infinity,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x070F172A),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.all(Radius.circular(17)),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_rounded,
                      color: Color(0xFF4F46E5),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          projectTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (category.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: senderName.isEmpty
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                senderName.isEmpty
                                    ? lastMessage
                                    : '$senderName: $lastMessage',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.arrow_outward_rounded,
                      size: 17,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ClientProjectChat extends StatefulWidget {
  final String projectId;
  final String projectTitle;

  const ClientProjectChat({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  @override
  State<ClientProjectChat> createState() => _ClientProjectChatState();
}

class _ClientProjectChatState extends State<ClientProjectChat> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _typingTimer;
  bool _isTyping = false;
  bool _isSending = false;
  bool _isUploading = false;
  String? _replyToMessageId;
  String? _replyToMessage;
  String? _replyToSenderName;

  void _startReply({
    required String messageId,
    required String message,
    required String senderName,
  }) {
    setState(() {
      _replyToMessageId = messageId;
      _replyToMessage = message;
      _replyToSenderName = senderName;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessageId = null;
      _replyToMessage = null;
      _replyToSenderName = null;
    });
  }

  Widget _buildReplyPreview() {
    if (_replyToMessageId == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFF4F46E5), width: 4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyToSenderName ?? 'User'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _replyToMessage ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _cancelReply,
            icon: const Icon(Icons.close),
            tooltip: 'Cancel reply',
          ),
        ],
      ),
    );
  }

  Future<void> _updateTypingStatus(bool typing) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final typingRef = _firestore
          .collection('projects')
          .doc(widget.projectId)
          .collection('typing')
          .doc(user.uid);

      await typingRef.set({
        'userId': user.uid,
        'userName': user.displayName ?? 'User',
        'isTyping': typing,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _isTyping = typing;
    } on FirebaseException catch (error) {
      debugPrint('Typing status error: ${error.message}');
    }
  }

  void _handleTyping(String text) {
    final typing = text.trim().isNotEmpty;

    if (typing && !_isTyping) {
      unawaited(_updateTypingStatus(true));
    }

    _typingTimer?.cancel();

    if (typing) {
      _typingTimer = Timer(
        const Duration(seconds: 2),
        () => unawaited(_updateTypingStatus(false)),
      );
    } else {
      unawaited(_updateTypingStatus(false));
    }
  }

  Widget _buildTypingIndicator() {
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('projects')
          .doc(widget.projectId)
          .collection('typing')
          .where('isTyping', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || currentUser == null) {
          return const SizedBox.shrink();
        }

        final typingUsers = snapshot.data!.docs.where((doc) {
          final data = doc.data();

          return doc.id != currentUser.uid && data['isTyping'] == true;
        }).toList();

        if (typingUsers.isEmpty) {
          return const SizedBox.shrink();
        }

        final name =
            typingUsers.first.data()['userName']?.toString() ?? 'Someone';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text(
                '$name is typing...',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPresenceIndicator(String otherUserId) {
    if (otherUserId.isEmpty) {
      return const Text(
        'Offline',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('userPresence')
          .doc(otherUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Status unavailable',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          );
        }

        final presence = snapshot.data;
        final data = presence?.data();
        final lastSeenValue = data?['lastSeen'];
        final lastSeen = lastSeenValue is Timestamp
            ? lastSeenValue.toDate()
            : null;
        final heartbeatFresh =
            lastSeen != null &&
            DateTime.now().difference(lastSeen).inSeconds < 90;
        final isOnline = data?['isOnline'] == true && heartbeatFresh;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isOnline
                  ? 'Online'
                  : lastSeen != null
                  ? 'Last seen ${_formatLastSeen(lastSeen)}'
                  : 'Offline',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        );
      },
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final difference = DateTime.now().difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    return '${difference.inDays} days ago';
  }

  Widget _buildOtherParticipantPresence(String? currentUserId) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('projects')
          .doc(widget.projectId)
          .snapshots(),
      builder: (context, snapshot) {
        final project = snapshot.data?.data();
        if (project == null || currentUserId == null) {
          return const SizedBox.shrink();
        }

        final clientId = project['clientId']?.toString().trim() ?? '';
        final developerId =
            (project['developerId'] ?? project['assignedDeveloperId'])
                ?.toString()
                .trim() ??
            '';
        final otherUserId = currentUserId == clientId ? developerId : clientId;

        return _buildPresenceIndicator(otherUserId);
      },
    );
  }

  Future<bool> _isAuthorizedProjectMember({
    required String userId,
    required String userRole,
    required String clientId,
    required String developerId,
  }) async {
    if (userRole == 'client' && clientId == userId) {
      return true;
    }

    if (userRole == 'developer' && developerId == userId) {
      return true;
    }

    if (userRole == 'developer') {
      final teamSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('projectId', isEqualTo: widget.projectId)
          .where('memberIds', arrayContains: userId)
          .get();

      return teamSnapshot.docs.any((team) {
        final data = team.data();

        return data['status']?.toString().trim().toLowerCase() == 'active';
      });
    }

    return false;
  }

  Future<void> _markMessagesAsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final unreadMessages = messages.where((doc) {
      final data = doc.data();

      final senderId = data['senderId']?.toString() ?? '';
      final isRead = data['isRead'] == true;

      return senderId != user.uid && !isRead;
    }).toList();

    if (unreadMessages.isEmpty) {
      return;
    }

    await Future.wait(
      unreadMessages.map((doc) => doc.reference.update({'isRead': true})),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    unawaited(_updateTypingStatus(false));
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final replyToMessageId = _replyToMessageId;
    final replyToMessage = _replyToMessage;
    final replyToSenderName = _replyToSenderName;

    if (text.isEmpty || _isSending || _isUploading) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    final l10n = AppLocalizations.of(context);

    setState(() {
      _isSending = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final projectSnapshot = await firestore
          .collection('projects')
          .doc(widget.projectId)
          .get();

      if (!projectSnapshot.exists) {
        throw StateError('Project not found.');
      }

      final projectData = projectSnapshot.data();
      final projectClientId = projectData?['clientId']?.toString().trim() ?? '';
      final projectDeveloperId =
          projectData?['developerId']?.toString().trim() ?? '';
      final userSnapshot = await firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userSnapshot.data();
      final userRole = userData?['role']?.toString().trim().toLowerCase() ?? '';

      final isAuthorized = await _isAuthorizedProjectMember(
        userId: user.uid,
        userRole: userRole,
        clientId: projectClientId,
        developerId: projectDeveloperId,
      );

      if (!isAuthorized) {
        throw StateError('You are not authorized to message this project.');
      }

      final profileName = (userData?['name'] ?? userData?['displayName'] ?? '')
          .toString()
          .trim();
      final senderName = profileName.isNotEmpty
          ? profileName
          : user.displayName ?? user.email ?? 'User';

      final messageRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'messageId': messageRef.id,
        'projectId': widget.projectId,
        'clientId': projectClientId,
        'senderId': user.uid,
        'senderName': senderName,
        'senderRole': userRole,
        'message': text,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'replyToMessageId': replyToMessageId,
        'replyToMessage': replyToMessage,
        'replyToSenderName': replyToSenderName,
      });

      _messageController.clear();
      _handleTyping('');
      if (mounted && replyToMessageId != null) {
        _cancelReply();
      }
    } on FirebaseException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.unableToSendMessage}\n'
            '${e.message ?? e.code}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.somethingWentWrong}\n$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _uploadAndSendFile({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please log in again.')));
      }
      return;
    }

    if (bytes.isEmpty) {
      _showAttachmentMessage('The selected file is empty.');
      return;
    }

    const maxFileSize = 15 * 1024 * 1024;
    if (bytes.length > maxFileSize) {
      _showAttachmentMessage('Files must be 15 MB or smaller.');
      return;
    }

    if (_isUploading || _isSending) return;

    setState(() => _isUploading = true);
    Reference? uploadedRef;

    try {
      final projectSnapshot = await _firestore
          .collection('projects')
          .doc(widget.projectId)
          .get();

      if (!projectSnapshot.exists) {
        throw StateError('Project not found.');
      }

      final projectData = projectSnapshot.data();
      final clientId = projectData?['clientId']?.toString().trim() ?? '';
      final developerId =
          (projectData?['developerId'] ?? projectData?['assignedDeveloperId'])
              ?.toString()
              .trim() ??
          '';
      final userSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userSnapshot.data();
      final userRole = userData?['role']?.toString().trim().toLowerCase() ?? '';

      final authorized = await _isAuthorizedProjectMember(
        userId: user.uid,
        userRole: userRole,
        clientId: clientId,
        developerId: developerId,
      );

      if (!authorized) {
        throw StateError('You are not authorized to share files in this chat.');
      }

      final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      uploadedRef = FirebaseStorage.instance
          .ref()
          .child('project_chat')
          .child(widget.projectId)
          .child(user.uid)
          .child('${DateTime.now().microsecondsSinceEpoch}_$safeFileName');

      final uploadSnapshot = await uploadedRef.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await uploadSnapshot.ref.getDownloadURL();
      final profileName = (userData?['name'] ?? userData?['displayName'] ?? '')
          .toString()
          .trim();
      final senderName = profileName.isNotEmpty
          ? profileName
          : user.displayName ?? user.email ?? 'User';
      final isImage = contentType.startsWith('image/');
      final messageRef = _firestore
          .collection('projects')
          .doc(widget.projectId)
          .collection('messages')
          .doc();

      await messageRef.set({
        'messageId': messageRef.id,
        'projectId': widget.projectId,
        'clientId': clientId,
        'senderId': user.uid,
        'senderName': senderName,
        'senderRole': userRole,
        'message': '${isImage ? 'Image' : 'File'}: $fileName',
        'messageType': isImage ? 'image' : 'file',
        'fileName': fileName,
        'fileUrl': downloadUrl,
        'contentType': contentType,
        'fileSize': bytes.length,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'replyToMessageId': _replyToMessageId,
        'replyToMessage': _replyToMessage,
        'replyToSenderName': _replyToSenderName,
      });

      if (mounted && _replyToMessageId != null) {
        _cancelReply();
      }
    } on FirebaseException catch (error) {
      if (uploadedRef != null) {
        try {
          await uploadedRef.delete();
        } on FirebaseException catch (cleanupError) {
          debugPrint(
            'Unable to remove orphaned chat upload: ${cleanupError.message}',
          );
        }
      }
      _showAttachmentMessage(
        'Unable to upload file: ${error.message ?? error.code}',
      );
    } catch (error) {
      if (uploadedRef != null) {
        try {
          await uploadedRef.delete();
        } on FirebaseException catch (cleanupError) {
          debugPrint(
            'Unable to remove orphaned chat upload: ${cleanupError.message}',
          );
        }
      }
      _showAttachmentMessage('Unable to upload file: $error');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );

      if (image == null || !mounted) return;

      final Uint8List bytes = await image.readAsBytes();

      if (!mounted) return;

      if (bytes.isEmpty) {
        _showAttachmentMessage('Unable to read the selected image.');
        return;
      }

      final bool? shouldSend = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Preview Image'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.send),
                label: const Text('Send Image'),
              ),
            ],
          );
        },
      );

      if (shouldSend != true || !mounted) return;

      await _uploadAndSendFile(
        bytes: bytes,
        fileName: image.name,
        contentType: image.mimeType ?? 'image/jpeg',
      );
    } catch (error, stackTrace) {
      debugPrint('Image preview error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showAttachmentMessage('Unable to preview or send image.');
    }
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'xls',
          'xlsx',
          'pptx',
          'zip',
        ],
      );

      if (file == null || !mounted) return;

      const maxFileSize = 15 * 1024 * 1024;
      final fileSize = await file.length();

      if (!mounted) return;

      if (fileSize == null) {
        _showAttachmentMessage('Unable to determine the selected file size.');
        return;
      }

      if (fileSize > maxFileSize) {
        _showAttachmentMessage('Files must be 15 MB or smaller.');
        return;
      }

      final bytes = await file.readAsBytes();

      if (!mounted) return;

      if (bytes.isEmpty) {
        _showAttachmentMessage('Unable to read the selected file.');
        return;
      }

      if (bytes.length > maxFileSize) {
        _showAttachmentMessage('Files must be 15 MB or smaller.');
        return;
      }

      final bool? shouldSend = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Preview Attachment'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getFileIcon(file.extension),
                    size: 56,
                    color: const Color(0xFF4F46E5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    file.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatFileSize(bytes.length),
                    style: const TextStyle(color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.send),
                label: const Text('Send File'),
              ),
            ],
          );
        },
      );

      if (shouldSend != true || !mounted) return;

      await _uploadAndSendFile(
        bytes: bytes,
        fileName: file.name,
        contentType: _getContentType(file.extension),
      );
    } catch (error, stackTrace) {
      debugPrint('File preview error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showAttachmentMessage('Unable to preview or send the file.');
    }
  }

  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'zip':
        return Icons.folder_zip_outlined;
      case 'txt':
        return Icons.text_snippet_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String _getContentType(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'zip':
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }

  void _showAttachmentMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openAttachment(String fileUrl) async {
    try {
      final uri = Uri.tryParse(fileUrl.trim());
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host != 'firebasestorage.googleapis.com' ||
          uri.userInfo.isNotEmpty ||
          uri.hasPort) {
        throw const FormatException('Invalid attachment URL.');
      }

      final pathSegments = uri.pathSegments;
      if (pathSegments.length < 5 ||
          pathSegments[0] != 'v0' ||
          pathSegments[1] != 'b' ||
          pathSegments[2] != FirebaseStorage.instance.bucket ||
          pathSegments[3] != 'o') {
        throw const FormatException('Attachment is not in Firebase Storage.');
      }

      final objectPath = pathSegments.skip(4).join('/');
      if (!objectPath.startsWith('project_chat/${widget.projectId}/')) {
        throw const FormatException(
          'Attachment is not part of this project chat.',
        );
      }

      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        _showAttachmentMessage('Unable to open the attachment.');
      }
    } catch (error, stackTrace) {
      debugPrint('Open attachment error: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showAttachmentMessage('Failed to open attachment.');
    }
  }

  Future<void> _editMessage({
    required String messageId,
    required String currentMessage,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final controller = TextEditingController(text: currentMessage);
    String? newMessage;

    try {
      newMessage = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Edit Message',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter your message',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF4F46E5)),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final text = controller.text.trim();

                  if (text.isEmpty) return;

                  Navigator.pop(dialogContext, text);
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }

    if (!mounted || newMessage == null || newMessage == currentMessage) return;

    try {
      final messageRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('messages')
          .doc(messageId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final messageSnapshot = await transaction.get(messageRef);

        if (!messageSnapshot.exists) {
          throw StateError('This message no longer exists.');
        }

        final messageData = messageSnapshot.data();

        if (messageData?['senderId'] != user.uid) {
          throw StateError('You can only edit your own messages.');
        }

        transaction.update(messageRef, {
          'message': newMessage,
          'isEdited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to edit message: ${error.message ?? error.code}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to edit message: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteMessage({required String messageId}) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Message?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Are you sure you want to delete this message? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    try {
      final messageRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('messages')
          .doc(messageId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final messageSnapshot = await transaction.get(messageRef);

        if (!messageSnapshot.exists) {
          throw StateError('This message no longer exists.');
        }

        final messageData = messageSnapshot.data();

        if (messageData?['senderId'] != user.uid) {
          throw StateError('You can only delete your own messages.');
        }

        transaction.delete(messageRef);
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to delete message: ${error.message ?? error.code}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to delete message: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(82),
        child: Container(
          color: const Color(0xFFF5F7FB),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
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
                    // Chat icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF4FF),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Color(0xFF2563EB),
                        size: 21,
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Project title and subtitle
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.projectTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          _buildOtherParticipantPresence(user?.uid),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Close button
                    Material(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(13),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(13),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: const Color(0xFFE5EAF2)),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: Color(0xFF475569),
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
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: Image(
              image: AssetImage('assets/images/chat_background.png.jpeg'),
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.white.withValues(alpha: 0.35)),
          ),
          Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: _MessagesAmbientPainter()),
                      ),
                    ),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('projects')
                          .doc(widget.projectId)
                          .collection('messages')
                          .orderBy('createdAt')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: _MessagesLoader());
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: _MessagesErrorCard(
                                message:
                                    '${l10n.unableToLoadConversation}\n'
                                    '${snapshot.error}',
                              ),
                            ),
                          );
                        }

                        final messages = snapshot.data?.docs ?? [];

                        if (messages.isNotEmpty) {
                          Future.microtask(() => _markMessagesAsRead(messages));
                        }

                        if (messages.isEmpty) {
                          return const _EmptyChatState();
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final messageDoc = messages[index];
                            final data = messageDoc.data();

                            final message = data['message']?.toString() ?? '';

                            final senderId = data['senderId']?.toString() ?? '';

                            final senderName =
                                data['senderName']?.toString() ?? '';

                            final isMine = senderId == user?.uid;
                            final isRead = data['isRead'] == true;
                            final isEdited = data['isEdited'] == true;
                            final replyToMessage = data['replyToMessage']
                                ?.toString();
                            final replyToSenderName = data['replyToSenderName']
                                ?.toString();
                            final messageType =
                                data['messageType']?.toString() ?? 'text';
                            final fileUrl = data['fileUrl']?.toString();
                            final fileName =
                                data['fileName']?.toString() ?? 'Attachment';
                            final createdAt = data['createdAt'];
                            final timestamp = createdAt is Timestamp
                                ? createdAt.toDate()
                                : null;

                            return _MessageBubble(
                              messageId: messageDoc.id,
                              message: message,
                              senderName: senderName,
                              isMine: isMine,
                              isRead: isRead,
                              isEdited: isEdited,
                              timestamp: timestamp,
                              replyToMessage: replyToMessage,
                              replyToSenderName: replyToSenderName,
                              messageType: messageType,
                              fileUrl: fileUrl,
                              fileName: fileName,
                              onOpenFile: fileUrl == null
                                  ? null
                                  : () => _openAttachment(fileUrl),
                              onReply: () => _startReply(
                                messageId: messageDoc.id,
                                message: message,
                                senderName: senderName,
                              ),
                              onEdit: isMine
                                  ? () => _editMessage(
                                      messageId: messageDoc.id,
                                      currentMessage: message,
                                    )
                                  : null,
                              onDelete: isMine
                                  ? () =>
                                        _deleteMessage(messageId: messageDoc.id)
                                  : null,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              _buildTypingIndicator(),
              _buildReplyPreview(),
              _MessageInput(
                controller: _messageController,
                isSending: _isSending,
                onSend: _sendMessage,
                onTyping: _handleTyping,
                isUploading: _isUploading,
                onPickImage: _pickImage,
                onPickFile: _pickFile,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final String messageId;
  final String message;
  final String senderName;
  final bool isMine;
  final bool isRead;
  final bool isEdited;
  final DateTime? timestamp;
  final String? replyToMessage;
  final String? replyToSenderName;
  final String messageType;
  final String? fileUrl;
  final String fileName;
  final VoidCallback? onOpenFile;
  final VoidCallback? onReply;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.messageId,
    required this.message,
    required this.senderName,
    required this.isMine,
    required this.isRead,
    required this.isEdited,
    required this.timestamp,
    required this.replyToMessage,
    required this.replyToSenderName,
    required this.messageType,
    required this.fileUrl,
    required this.fileName,
    required this.onOpenFile,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
  });

  String _initial() {
    if (senderName.trim().isEmpty) {
      return isMine ? 'C' : 'U';
    }

    return senderName.trim()[0].toUpperCase();
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  Future<void> _showMessageOptions(BuildContext context) async {
    if (onReply == null && onEdit == null && onDelete == null) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                if (onReply != null)
                  ListTile(
                    leading: const Icon(
                      Icons.reply_rounded,
                      color: Color(0xFF475569),
                    ),
                    title: const Text(
                      'Reply',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onReply?.call();
                    },
                  ),
                if (onEdit != null)
                  ListTile(
                    leading: const Icon(
                      Icons.edit_rounded,
                      color: Color(0xFF4F46E5),
                    ),
                    title: const Text(
                      'Edit Message',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onEdit?.call();
                    },
                  ),
                if (onDelete != null)
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626),
                    ),
                    title: const Text(
                      'Delete Message',
                      style: TextStyle(
                        color: Color(0xFFDC2626),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      onDelete?.call();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _initial(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF4338CA),
                ),
              ),
            ),
            const SizedBox(width: 9),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: onReply != null || isMine
                  ? () => _showMessageOptions(context)
                  : null,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 390),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  gradient: isMine
                      ? const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMine ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMine ? 18 : 5),
                    bottomRight: Radius.circular(isMine ? 5 : 18),
                  ),
                  border: isMine
                      ? null
                      : Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x060F172A),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMine && senderName.isNotEmpty) ...[
                      Text(
                        senderName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4F46E5),
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    if (replyToMessage != null &&
                        replyToMessage!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: const Border(
                            left: BorderSide(
                              color: Color(0xFF4F46E5),
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              replyToSenderName ?? 'User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              replyToMessage!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (messageType == 'image' &&
                        fileUrl != null &&
                        fileUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: fileUrl!,
                          width: 220,
                          height: 200,
                          fit: BoxFit.cover,
                          placeholder: (context, url) {
                            return Container(
                              width: 220,
                              height: 200,
                              alignment: Alignment.center,
                              color: const Color(0xFFF1F5F9),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            );
                          },
                          errorWidget: (context, url, error) {
                            return Container(
                              width: 220,
                              height: 120,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    size: 32,
                                    color: Color(0xFF64748B),
                                  ),
                                  SizedBox(height: 6),
                                  Text('Unable to load image'),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    else if (messageType == 'file' &&
                        fileUrl != null &&
                        fileUrl!.isNotEmpty)
                      InkWell(
                        onTap: onOpenFile,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 250,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.insert_drive_file_outlined,
                                size: 36,
                                color: Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fileName,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Tap to open',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.open_in_new,
                                size: 18,
                                color: Color(0xFF64748B),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: isMine
                              ? Colors.white
                              : const Color(0xFF334155),
                        ),
                      ),
                    if (messageType == 'image' &&
                        fileUrl != null &&
                        fileUrl!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMine ? Colors.white70 : Colors.blueGrey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isEdited) ...[
                          Text(
                            'Edited',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: isMine
                                  ? Colors.white70
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMine
                                ? Colors.white70
                                : const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    if (isMine) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            isRead ? Icons.done_all : Icons.done,
                            size: 16,
                            color: isRead
                                ? Colors.lightBlueAccent
                                : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isRead ? 'Read' : 'Sent',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (isMine || onReply != null) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: isMine ? 'Message options' : 'Reply to message',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              padding: EdgeInsets.zero,
              onPressed: () => _showMessageOptions(context),
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 19,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final bool isUploading;
  final VoidCallback onSend;
  final ValueChanged<String> onTyping;
  final VoidCallback onPickImage;
  final VoidCallback onPickFile;

  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.isUploading,
    required this.onSend,
    required this.onTyping,
    required this.onPickImage,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        boxShadow: [
          BoxShadow(
            color: Color(0x090F172A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Row(
              children: [
                IconButton(
                  onPressed: isSending || isUploading ? null : onPickImage,
                  tooltip: 'Send image',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                IconButton(
                  onPressed: isSending || isUploading ? null : onPickFile,
                  tooltip: 'Attach file',
                  visualDensity: VisualDensity.compact,
                  icon: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file, color: Color(0xFF4F46E5)),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    textInputAction: TextInputAction.send,
                    onChanged: onTyping,
                    onSubmitted: (_) => onSend(),
                    minLines: 1,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: l10n.writeMessage,
                      hintStyle: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF818CF8)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x254F46E5),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: isSending || isUploading ? null : onSend,
                    padding: EdgeInsets.zero,
                    icon: isSending
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const _MessagesSectionHeading(),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 52,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x070F172A),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const _EmptyMessageIcon(),
                    const SizedBox(height: 18),
                    Text(
                      l10n.noConversationsYet,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.continueConversations,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF6B7280),
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

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _EmptyMessageIcon(),
            const SizedBox(height: 18),
            Text(
              l10n.noMessagesYet,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.continueConversations,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMessageIcon extends StatelessWidget {
  const _EmptyMessageIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(
        Icons.forum_outlined,
        size: 32,
        color: Color(0xFF4F46E5),
      ),
    );
  }
}

class _MessagesLoader extends StatelessWidget {
  const _MessagesLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Color(0xFF4F46E5),
      ),
    );
  }
}

class _MessagesErrorCard extends StatelessWidget {
  final String message;

  const _MessagesErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1C2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesAmbientPainter extends CustomPainter {
  const _MessagesAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0x0B4F46E5);

    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.12),
      190,
      paint,
    );

    paint.color = const Color(0x087C3AED);

    canvas.drawCircle(
      Offset(size.width * 0.05, size.height * 0.78),
      155,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MessagesAmbientPainter oldDelegate) {
    return false;
  }
}
