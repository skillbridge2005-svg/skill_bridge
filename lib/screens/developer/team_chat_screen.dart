import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/team_chat_service.dart';

/// Team group chat styled to match the client chat experience.
///
/// Intentionally preserves the existing TeamChatService API and message
/// schema: senderId, senderName, text, type, imageUrl, and createdAt.
class TeamChatScreen extends StatefulWidget {
  const TeamChatScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  final String teamId;
  final String teamName;

  @override
  State<TeamChatScreen> createState() => _TeamChatScreenState();
}

class _TeamChatScreenState extends State<TeamChatScreen> {
  static const Color _page = Color(0xFFF6F8FC);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF64748B);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _border = Color(0xFFE5EAF2);

  final TeamChatService _chat = TeamChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _sending = false;
  bool _uploadingImage = false;
  bool _uploadingFile = false;
  String? _replyToMessageId;
  String? _replyToMessage;
  String? _replyToSenderName;
  bool _markingUnreadMessagesRead = false;
  bool _markReadAgain = false;
  bool _initialTeamReadCheckStarted = false;

  CollectionReference<Map<String, dynamic>> get _messages => FirebaseFirestore
      .instance
      .collection('teams')
      .doc(widget.teamId)
      .collection('messages');

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _messageController.clear();

    final replyId = _replyToMessageId;
    final replyText = _replyToMessage;
    final replyName = _replyToSenderName;
    setState(() {
      _replyToMessageId = null;
      _replyToMessage = null;
      _replyToSenderName = null;
    });

    try {
      await _chat.sendMessage(
        teamId: widget.teamId,
        text: text,
        replyToMessageId: replyId,
        replyToMessage: replyText,
        replyToSenderName: replyName,
      );
    } catch (error) {
      if (!mounted) return;
      _messageController.text = text;
      _messageController.selection = TextSelection.collapsed(
        offset: _messageController.text.length,
      );
      if (mounted && replyId != null) {
        setState(() {
          _replyToMessageId = replyId;
          _replyToMessage = replyText;
          _replyToSenderName = replyName;
        });
      }
      _showMessage('Could not send message: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _hasUnreadMessagesForCurrentUser(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
    String? currentUid,
  ) {
    if (currentUid == null) return false;

    return messages.any((message) {
      final data = message.data();
      final rawUnreadFor = data['unreadFor'];
      return data['senderId'] != currentUid &&
          rawUnreadFor is List &&
          rawUnreadFor.contains(currentUid);
    });
  }

  Future<void> _markTeamMessagesRead() async {
    if (_markingUnreadMessagesRead) {
      _markReadAgain = true;
      return;
    }

    _markingUnreadMessagesRead = true;
    try {
      do {
        _markReadAgain = false;
        await _chat.markMessagesRead(widget.teamId);
      } while (_markReadAgain && mounted);
    } catch (error) {
      debugPrint('Could not mark team messages as read: $error');
    } finally {
      _markingUnreadMessagesRead = false;
    }
  }

  void _handleUnreadMessages(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
    String? currentUid,
  ) {
    // Mark the initial unread backlog, including messages older than the
    // 100-message window returned by watchMessages().
    if (!_initialTeamReadCheckStarted) {
      _initialTeamReadCheckStarted = true;
      unawaited(_markTeamMessagesRead());
      return;
    }

    // New messages arriving while this screen is open are marked as read too.
    if (_hasUnreadMessagesForCurrentUser(messages, currentUid)) {
      unawaited(_markTeamMessagesRead());
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_uploadingImage) return;

    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (pickedFile == null || !mounted) return;

      final imageBytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      final shouldSend = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Send image?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 320,
              height: 280,
              child: Image.memory(
                imageBytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Text('Could not preview this image.')),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send image'),
            ),
          ],
        ),
      );

      if (shouldSend != true || !mounted) return;
      setState(() => _uploadingImage = true);

      // Keep the current service contract and storage behavior unchanged.
      await _chat.sendImageMessage(
        teamId: widget.teamId,
        imageBytes: imageBytes,
        fileName: pickedFile.name,
      );

      _showMessage('Image sent successfully.');
    } catch (error) {
      _showMessage('Could not upload image: $error');
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    if (_uploadingFile) return;

    try {
      final file = await FilePicker.pickFile(type: FileType.any);

      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        _showMessage('The selected file is empty or could not be read.');
        return;
      }

      // Maximum file size: 20 MB
      if (bytes.length > 20 * 1024 * 1024) {
        _showMessage('Please select a file smaller than 20 MB.');
        return;
      }

      // Confirm before sharing
      final confirm = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Share this file?'),
          content: Row(
            children: [
              const Icon(
                Icons.insert_drive_file_rounded,
                color: _blue,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _readableSize(bytes.length),
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.send_rounded),
              label: const Text('Share'),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;

      setState(() => _uploadingFile = true);

      final mimeType = file.extension == null
          ? 'application/octet-stream'
          : _mimeFromExtension(file.extension!);

      // Upload file to Supabase through TeamChatService.
      // This service also saves the message metadata in Firestore.
      await _chat.sendFileMessage(
        teamId: widget.teamId,
        bytes: bytes,
        fileName: file.name,
        contentType: mimeType,
      );

      if (mounted) {
        _showMessage('File shared successfully.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Could not share file: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingFile = false);
      }
    }
  }

  String _readableSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _mimeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
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

      case 'csv':
        return 'text/csv';

      case 'zip':
        return 'application/zip';

      case 'mp3':
        return 'audio/mpeg';

      case 'mp4':
        return 'video/mp4';

      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _chooseMessageAction({
    required String messageId,
    required Map<String, dynamic> data,
    required bool isMine,
  }) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: _blue),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(sheetContext, 'reply'),
            ),
            if (isMine && data['type'] == 'text')
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
            if (isMine)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
                title: const Text(
                  'Delete message',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    final text =
        (data['text'] ??
                (data['type'] == 'image'
                    ? 'Image'
                    : data['fileName'] ?? 'Attachment'))
            .toString();
    final sender = (data['senderName'] ?? 'Team member').toString();
    final messageRef = _messages.doc(messageId);
    if (choice == 'reply') {
      setState(() {
        _replyToMessageId = messageId;
        _replyToMessage = text;
        _replyToSenderName = sender;
      });
      return;
    }
    if (choice == 'edit') {
      final controller = TextEditingController(text: text);
      final edited = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Edit message'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Update your message'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
      controller.dispose();
      if (edited == null || edited.isEmpty) return;
      try {
        await messageRef.update({
          'text': edited,
          'isEdited': true,
          'editedAt': FieldValue.serverTimestamp(),
        });
        _showMessage('Message updated.');
      } catch (error) {
        _showMessage('Could not edit message: $error');
      }
      return;
    }
    if (choice == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Delete message?'),
          content: const Text(
            'This message will be removed from the team chat.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await messageRef.delete();
        _showMessage('Message deleted.');
      } catch (error) {
        _showMessage('Could not delete message: $error');
      }
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    if (parts.isEmpty) return 'T';
    if (parts.length == 1) {
      final value = parts.first;
      return value.length > 1
          ? value.substring(0, 2).toUpperCase()
          : value.toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _formatTime(dynamic value, BuildContext context) {
    if (value is Timestamp) {
      return TimeOfDay.fromDateTime(value.toDate()).format(context);
    }
    return 'Sending…';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    if (messageDay == today) return 'Today';
    if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Widget _datePill(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required String messageId,
    required Map<String, dynamic> data,
    required bool isMine,
    required String time,
  }) {
    final isImage = data['type'] == 'image';
    final isFile = data['type'] == 'file';
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final fileUrl = (data['fileUrl'] ?? '').toString();
    final fileName = (data['fileName'] ?? 'Attachment').toString();
    final senderName = (data['senderName'] ?? 'Team member').toString();
    final messageText = (data['text'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            Container(
              width: 31,
              height: 31,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE0EAFE), Color(0xFFF0EAFE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(senderName),
                style: const TextStyle(
                  color: _blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.76,
              ),
              child: Column(
                crossAxisAlignment: isMine
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 5),
                      child: Text(
                        senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: isMine
                          ? const LinearGradient(
                              colors: [Color(0xFF3478F6), Color(0xFF2458D8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isMine
                          ? null
                          : Colors.white.withValues(alpha: 0.97),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isMine ? 20 : 6),
                        bottomRight: Radius.circular(isMine ? 6 : 20),
                      ),
                      border: isMine ? null : Border.all(color: _border),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A)
                              .withValues(alpha: isMine ? 0.09 : 0.045),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isImage ? 7 : 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((data['replyToMessage'] ?? '')
                              .toString()
                              .isNotEmpty)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border(
                                  left: BorderSide(
                                    color: isMine ? Colors.white70 : _blue,
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (data['replyToSenderName'] ?? 'Team member')
                                        .toString(),
                                    style: TextStyle(
                                      color: isMine ? Colors.white : _blue,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    data['replyToMessage'].toString(),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isMine ? Colors.white70 : _muted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isImage)
                            if (imageUrl.isNotEmpty)
                              GestureDetector(
                                onTap: () => showDialog<void>(
                                  context: context,
                                  builder: (dialogContext) => Dialog(
                                    backgroundColor: Colors.black,
                                    insetPadding: const EdgeInsets.all(14),
                                    child: Stack(
                                      children: [
                                        InteractiveViewer(
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox(
                                                  height: 240,
                                                  child: Center(
                                                    child: Text(
                                                      'Unable to load image.',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 8,
                                          top: 8,
                                          child: IconButton.filledTonal(
                                            onPressed: () =>
                                                Navigator.of(dialogContext)
                                                    .pop(),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    imageUrl,
                                    width: 230,
                                    height: 205,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, progress) {
                                      if (progress == null) return child;
                                      return const SizedBox(
                                        width: 230,
                                        height: 180,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(
                                          width: 230,
                                          height: 100,
                                          child: Center(
                                            child: Text(
                                              'Unable to load image.',
                                            ),
                                          ),
                                        ),
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Image unavailable',
                                  style: TextStyle(
                                    color: isMine ? Colors.white : _ink,
                                  ),
                                ),
                              ),
                          if (isFile)
                            InkWell(
                              onTap: fileUrl.isEmpty
                                  ? null
                                  : () async {
                                      final uri = Uri.tryParse(fileUrl);
                                      if (uri != null) {
                                        final opened = await launchUrl(
                                          uri,
                                          mode: LaunchMode.platformDefault,
                                        );
                                        if (!opened)
                                          _showMessage(
                                            'Could not open this attachment.',
                                          );
                                      }
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 190,
                                  maxWidth: 250,
                                ),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isMine
                                      ? Colors.white.withValues(alpha: 0.13)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.insert_drive_file_rounded,
                                      color: isMine ? Colors.white : _blue,
                                      size: 30,
                                    ),
                                    const SizedBox(width: 9),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fileName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isMine
                                                  ? Colors.white
                                                  : _ink,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            _readableSize(
                                              (data['fileSize'] as num?)
                                                      ?.toInt() ??
                                                  0,
                                            ),
                                            style: TextStyle(
                                              color: isMine
                                                  ? Colors.white70
                                                  : _muted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.download_rounded,
                                      color: isMine ? Colors.white70 : _muted,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (!isImage && !isFile && messageText.isNotEmpty)
                            Text(
                              messageText,
                              style: TextStyle(
                                color: isMine ? Colors.white : _ink,
                                fontSize: 14,
                                height: 1.42,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (data['isEdited'] == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'edited',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontStyle: FontStyle.italic,
                                  color: isMine ? Colors.white70 : _muted,
                                ),
                              ),
                            ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isMine
                                      ? Colors.white.withValues(alpha: 0.76)
                                      : _muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isMine) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  data['isRead'] == true
                                      ? Icons.done_all_rounded
                                      : Icons.done_rounded,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ],
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
          const SizedBox(width: 2),
          SizedBox(
            width: 30,
            height: 32,
            child: IconButton(
              tooltip: 'Message options',
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.more_horiz_rounded,
                size: 19,
                color: _muted,
              ),
              onPressed: () => _chooseMessageAction(
                messageId: messageId,
                data: data,
                isMine: isMine,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_replyToMessageId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply_rounded, color: _blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replying to ${_replyToSenderName ?? 'Team member'}',
                            style: const TextStyle(
                              color: _blue,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            _replyToMessage ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() {
                        _replyToMessageId = null;
                        _replyToMessage = null;
                        _replyToSenderName = null;
                      }),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x080F172A),
                    blurRadius: 20,
                    offset: Offset(0, 7),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Material(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _uploadingImage ? null : _pickAndSendImage,
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 43,
                        height: 43,
                        child: Center(
                          child: _uploadingImage
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: _blue,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: _uploadingFile ? null : _pickAndSendFile,
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 39,
                        height: 43,
                        child: Center(
                          child: _uploadingFile
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.attach_file_rounded,
                                  color: _blue,
                                  size: 21,
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message your team…',
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3478F6), Color(0xFF2458D8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x302563EB),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      tooltip: 'Send message',
                      onPressed: _sending ? null : _send,
                      color: Colors.white,
                      icon: _sending
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
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

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _page,
      body: Stack(
        children: [
          const Positioned.fill(
            child: Image(
              image: AssetImage('assets/images/chat_background.png.jpeg'),
              fit: BoxFit.cover,
              errorBuilder: _backgroundFallback,
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.white.withValues(alpha: 0.52)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Container(
                    height: 68,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.97),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(color: _border),
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
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE5EDFF), Color(0xFFF0EAFE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.groups_rounded,
                            color: _blue,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.teamName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.25,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 7,
                                    color: Color(0xFF22C55E),
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Team group chat',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(13),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: () => Navigator.of(context).maybePop(),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(color: _border),
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
                Expanded(
                  child: StreamBuilder<bool>(
                    stream: _chat.watchMembership(widget.teamId),
                    builder: (context, membershipSnapshot) {
                      if (membershipSnapshot.hasError) {
                        return _stateCard(
                          icon: Icons.lock_outline_rounded,
                          title: 'Could not verify membership',
                          subtitle: 'Check your connection and try again.',
                        );
                      }
                      if (!membershipSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(color: _blue),
                        );
                      }
                      if (membershipSnapshot.data != true) {
                        return _stateCard(
                          icon: Icons.group_outlined,
                          title: 'Team members only',
                          subtitle: 'Only accepted team members can access this chat.',
                        );
                      }

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _chat.watchMessages(widget.teamId),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _stateCard(
                              icon: Icons.cloud_off_rounded,
                              title: 'Could not load messages',
                              subtitle:
                                  'Please check your connection and try again.',
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(color: _blue),
                            );
                          }

                          final messages = snapshot.data!.docs;
                          _handleUnreadMessages(messages, currentUid);
                          if (messages.isEmpty) {
                            return Center(
                              child: Container(
                                margin: const EdgeInsets.all(28),
                                padding: const EdgeInsets.all(25),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.94),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: _border),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x080F172A),
                                      blurRadius: 20,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _EmptyChatIllustration(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Start the conversation',
                                      style: TextStyle(
                                        color: _ink,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(height: 7),
                                    Text(
                                      'Say hello, share an update, or send an image to your team.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // Keep the existing service/query ordering unchanged. The original
                          // screen uses reverse: true with these documents.
                          final orderedMessages = messages;

                          return Stack(
                            children: [
                              const Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _MessagesAmbientPainter(),
                                  ),
                                ),
                              ),
                              ListView.builder(
                                controller: _scrollController,
                                reverse: true,
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  18,
                                ),
                                itemCount: orderedMessages.length,
                                itemBuilder: (context, index) {
                                  final doc = orderedMessages[index];
                                  final data = doc.data();
                                  final isMine = data['senderId'] == currentUid;
                                  final timestamp = data['createdAt'];
                                  final time = _formatTime(timestamp, context);

                                  final bubble = GestureDetector(
                                    onLongPress: () => _chooseMessageAction(
                                      messageId: doc.id,
                                      data: data,
                                      isMine: isMine,
                                    ),
                                    child: _buildMessageBubble(
                                      messageId: doc.id,
                                      data: data,
                                      isMine: isMine,
                                      time: time,
                                    ),
                                  );

                                  // Date labels are only added when a valid
                                  // timestamp is present.
                                  final date = timestamp is Timestamp
                                      ? _formatDate(timestamp.toDate())
                                      : null;
                                  final nextIndex = index + 1;
                                  String? previousDate;
                                  if (nextIndex < orderedMessages.length) {
                                    final previousTimestamp =
                                        orderedMessages[nextIndex]
                                            .data()['createdAt'];
                                    if (previousTimestamp is Timestamp) {
                                      previousDate = _formatDate(
                                        previousTimestamp.toDate(),
                                      );
                                    }
                                  }

                                  return Column(
                                    children: [
                                      if (date != null && date != previousDate)
                                        _datePill(date),
                                      bubble,
                                    ],
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
                _buildComposer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _backgroundFallback(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  ) {
    return const ColoredBox(color: _page);
  }

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _blue, size: 34),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatIllustration extends StatelessWidget {
  const _EmptyChatIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE5EDFF), Color(0xFFF1EAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Icon(
        Icons.forum_rounded,
        size: 34,
        color: Color(0xFF2563EB),
      ),
    );
  }
}

class _MessagesAmbientPainter extends CustomPainter {
  const _MessagesAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFFBBD1FF).withValues(alpha: 0.14);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.18), 74, paint);

    paint.color = const Color(0xFFD9C7FF).withValues(alpha: 0.13);
    canvas.drawCircle(Offset(size.width * 0.93, size.height * 0.42), 94, paint);

    paint.color = const Color(0xFFB9E7F8).withValues(alpha: 0.12);
    canvas.drawCircle(Offset(size.width * 0.24, size.height * 0.91), 82, paint);

    final dotPaint = Paint()
      ..color = const Color(0xFF8AAAF0).withValues(alpha: 0.17)
      ..style = PaintingStyle.fill;

    for (var row = 0; row < 6; row++) {
      for (var col = 0; col < 5; col++) {
        final x = size.width * 0.62 + col * 18.0;
        final y = size.height * 0.12 + row * 18.0;
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MessagesAmbientPainter oldDelegate) => false;
}
