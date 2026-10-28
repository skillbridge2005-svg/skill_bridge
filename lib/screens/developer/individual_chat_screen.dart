import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class IndividualChatService {
  IndividualChatService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _messages(String chatId) =>
      _firestore.collection('chats').doc(chatId).collection('messages');

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMessages(String chatId) =>
      _messages(chatId).orderBy('createdAt', descending: true).snapshots();

  Future<void> sendMessage({
    required String chatId,
    required String text,
    String? replyToMessageId,
    String? replyToMessage,
    String? replyToSenderName,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Please sign in to send messages.');

    await _messages(chatId).add({
      'senderId': user.uid,
      'senderName': user.displayName ?? user.email ?? 'User',
      'text': text,
      'type': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
      'replyToMessageId': replyToMessageId,
      'replyToMessage': replyToMessage,
      'replyToSenderName': replyToSenderName,
    });
  }

  Future<void> sendAttachment({
    required String chatId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Please sign in to send attachments.');
    if (bytes.isEmpty) throw StateError('The selected file is empty.');
    if (bytes.length > 15 * 1024 * 1024) {
      throw StateError('Files must be 15 MB or smaller.');
    }

    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('individual_chat')
        .child(chatId)
        .child(user.uid)
        .child('${DateTime.now().microsecondsSinceEpoch}_$safeName');

    final upload = await storageRef.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );

    try {
      final url = await upload.ref.getDownloadURL();
      final isImage = contentType.startsWith('image/');
      await _messages(chatId).add({
        'senderId': user.uid,
        'senderName': user.displayName ?? user.email ?? 'User',
        'text': isImage ? 'Image: $fileName' : 'File: $fileName',
        'type': isImage ? 'image' : 'file',
        'fileUrl': url,
        'fileName': fileName,
        'contentType': contentType,
        'fileSize': bytes.length,
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (_) {
      try {
        await storageRef.delete();
      } catch (cleanupError) {
        debugPrint('Attachment cleanup failed: $cleanupError');
      }
      rethrow;
    }
  }

  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String text,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Please sign in again.');
    final ref = _messages(chatId).doc(messageId);
    final snapshot = await ref.get();
    if (!snapshot.exists || snapshot.data()?['senderId'] != user.uid) {
      throw StateError('You can only edit your own messages.');
    }
    await ref.update({
      'text': text,
      'type': 'text',
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Please sign in again.');
    final ref = _messages(chatId).doc(messageId);
    final snapshot = await ref.get();
    if (!snapshot.exists || snapshot.data()?['senderId'] != user.uid) {
      throw StateError('You can only delete your own messages.');
    }
    await ref.delete();
  }

  Future<void> markMessagesRead(
    String chatId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> messages,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final unread = messages.where((doc) {
      final data = doc.data();
      return data['senderId'] != user.uid && data['isRead'] != true;
    }).toList();

    for (var i = 0; i < unread.length; i += 400) {
      final batch = _firestore.batch();
      for (final doc in unread.skip(i).take(400)) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }
}

class IndividualChatScreen extends StatefulWidget {
  const IndividualChatScreen({
    super.key,
    required this.chatId,
    required this.otherUid,
    required this.otherName,
  });

  final String chatId;
  final String otherUid;
  final String otherName;

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final IndividualChatService _service = IndividualChatService();
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;
  bool _uploadingAttachment = false;
  bool _markingRead = false;
  String? _replyId;
  String? _replyText;
  String? _replyName;

  static const Color _background = Color(0xFFF6F8FC);
  static const Color _indigo = Color(0xFF4F46E5);
  static const Color _darkIndigo = Color(0xFF4338CA);
  static const Color _primaryText = Color(0xFF111827);
  static const Color _secondaryText = Color(0xFF64748B);
  static const Color _border = Color(0xFFE5EAF2);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _initial(String value) {
    final name = value.trim();
    return name.isEmpty ? 'U' : name[0].toUpperCase();
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Sending…';
    final date = timestamp.toDate();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  Future<void> _send() async {
    if (_sending || _uploadingAttachment) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final replyId = _replyId;
    final replyText = _replyText;
    final replyName = _replyName;
    setState(() => _sending = true);
    _controller.clear();

    try {
      await _service.sendMessage(
        chatId: widget.chatId,
        text: text,
        replyToMessageId: replyId,
        replyToMessage: replyText,
        replyToSenderName: replyName,
      );
      if (mounted) {
        setState(() {
          _replyId = null;
          _replyText = null;
          _replyName = null;
        });
      }
    } catch (error) {
      if (mounted) _controller.text = text;
      _showError('Could not send message: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAttachment({required bool imageOnly}) async {
    if (_uploadingAttachment || _sending) return;
    try {
      // file_picker 12+ removed FilePicker.platform and the old
      // withData/allowMultiple parameters. Use the current single-file API.
      final file = await FilePicker.pickFile(
        type: imageOnly ? FileType.image : FileType.any,
      );
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        _showError('Unable to read the selected file.');
        return;
      }
      if (bytes.length > 15 * 1024 * 1024) {
        _showError('Files must be 15 MB or smaller.');
        return;
      }

      final contentType = imageOnly
          ? _imageContentType(file.extension)
          : _contentType(file.extension);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(imageOnly ? 'Send image?' : 'Send attachment?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (imageOnly)
                Image.memory(
                  bytes,
                  height: 190,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined, size: 48),
                )
              else
                const Icon(
                  Icons.insert_drive_file_rounded,
                  size: 48,
                  color: _indigo,
                ),
              const SizedBox(height: 12),
              Text(
                file.name,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text('${(bytes.length / 1024).ceil()} KB'),
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
              label: const Text('Send'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      setState(() => _uploadingAttachment = true);
      await _service.sendAttachment(
        chatId: widget.chatId,
        bytes: bytes,
        fileName: file.name,
        contentType: contentType,
      );
    } catch (error) {
      _showError('Could not upload attachment: $error');
    } finally {
      if (mounted) setState(() => _uploadingAttachment = false);
    }
  }

  String _imageContentType(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String _contentType(String? extension) {
    switch ((extension ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      _showError('Invalid attachment link.');
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _showError('Could not open this attachment.');
    } catch (error) {
      _showError('Could not open attachment: $error');
    }
  }

  void _replyTo({
    required String id,
    required String text,
    required String senderName,
  }) {
    setState(() {
      _replyId = id;
      _replyText = text;
      _replyName = senderName;
    });
  }

  Future<void> _editMessage(String messageId, String originalText) async {
    final editController = TextEditingController(text: originalText);
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Enter your message',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = editController.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    editController.dispose();
    if (newText == null || newText == originalText.trim()) return;
    try {
      await _service.editMessage(
        chatId: widget.chatId,
        messageId: messageId,
        text: newText,
      );
    } catch (error) {
      _showError('Could not edit message: $error');
    }
  }

  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This message will be removed from the chat.'),
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
    if (confirmed != true) return;
    try {
      await _service.deleteMessage(chatId: widget.chatId, messageId: messageId);
    } catch (error) {
      _showError('Could not delete message: $error');
    }
  }

  Future<void> _showMessageActions({
    required String messageId,
    required Map<String, dynamic> data,
    required bool isMine,
  }) async {
    final text = (data['text'] ?? '').toString();
    final senderName = (data['senderName'] ?? widget.otherName).toString();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        Widget option({
          required IconData icon,
          required String label,
          required VoidCallback onTap,
          Color color = _primaryText,
        }) => ListTile(
          leading: Icon(icon, color: color),
          title: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          onTap: () {
            Navigator.pop(sheetContext);
            onTap();
          },
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 8),
                option(
                  icon: Icons.reply_rounded,
                  label: 'Reply',
                  color: _indigo,
                  onTap: () => _replyTo(
                    id: messageId,
                    text: text,
                    senderName: senderName,
                  ),
                ),
                if (isMine)
                  option(
                    icon: Icons.edit_rounded,
                    label: 'Edit message',
                    color: _indigo,
                    onTap: () => _editMessage(messageId, text),
                  ),
                if (isMine)
                  option(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete message',
                    color: Colors.red,
                    onTap: () => _deleteMessage(messageId),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresence() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('userPresence')
          .doc(widget.otherUid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final lastSeenValue = data?['lastSeen'];
        final lastSeen = lastSeenValue is Timestamp
            ? lastSeenValue.toDate()
            : null;
        final fresh =
            lastSeen != null &&
            DateTime.now().difference(lastSeen).inSeconds < 90;
        final online = data?['isOnline'] == true && fresh;
        String status;
        if (online) {
          status = 'Online';
        } else if (lastSeen == null) {
          status = 'Offline';
        } else {
          final difference = DateTime.now().difference(lastSeen);
          if (difference.inMinutes < 1) {
            status = 'Last seen just now';
          } else if (difference.inHours < 1) {
            status = 'Last seen ${difference.inMinutes} min ago';
          } else if (difference.inDays < 1) {
            status = 'Last seen ${difference.inHours} hr ago';
          } else {
            status = 'Last seen ${difference.inDays} days ago';
          }
        }
        return Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: online ? const Color(0xFF22C55E) : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: _secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() => Container(
    height: 68,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
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
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.chat_bubble_rounded,
            color: Color(0xFF2563EB),
            size: 21,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _primaryText,
                ),
              ),
              const SizedBox(height: 4),
              _buildPresence(),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Close chat',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF8FAFC),
            side: const BorderSide(color: _border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
            fixedSize: const Size(42, 42),
          ),
        ),
      ],
    ),
  );

  Widget _buildAttachmentContent({
    required String type,
    required String fileUrl,
    required String fileName,
    required bool isMine,
  }) {
    if (type == 'image' && fileUrl.isNotEmpty) {
      return GestureDetector(
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            child: InteractiveViewer(
              child: Image.network(
                fileUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Unable to load image.'),
                ),
              ),
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            fileUrl,
            width: 230,
            height: 200,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const SizedBox(
                    width: 230,
                    height: 150,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
            errorBuilder: (_, __, ___) => const SizedBox(
              width: 230,
              height: 100,
              child: Center(child: Text('Unable to load image.')),
            ),
          ),
        ),
      );
    }
    if (type == 'file' && fileUrl.isNotEmpty) {
      return InkWell(
        onTap: () => _openAttachment(fileUrl),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMine
                ? Colors.white.withValues(alpha: 0.12)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_rounded,
                size: 28,
                color: isMine ? Colors.white : _indigo,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Tap to open file',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildBubble({
    required String messageId,
    required Map<String, dynamic> data,
    required bool isMine,
  }) {
    final senderName = (data['senderName'] ?? widget.otherName).toString();
    final text = (data['text'] ?? '').toString();
    final type = (data['type'] ?? 'text').toString();
    final fileUrl = (data['fileUrl'] ?? '').toString();
    final fileName = (data['fileName'] ?? 'Attachment').toString();
    final timestampValue = data['createdAt'];
    final timestamp = timestampValue is Timestamp ? timestampValue : null;
    final replyText = data['replyToMessage']?.toString();
    final replyName = data['replyToSenderName']?.toString();
    final edited = data['isEdited'] == true;
    final read = data['isRead'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFE0E7FF),
                shape: BoxShape.circle,
              ),
              child: Text(
                _initial(senderName),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: _darkIndigo,
                ),
              ),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageActions(
                messageId: messageId,
                data: data,
                isMine: isMine,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 390),
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: isMine
                      ? const LinearGradient(
                          colors: [_indigo, _darkIndigo],
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
                  border: isMine ? null : Border.all(color: _border),
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
                    if (!isMine) ...[
                      Text(
                        senderName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _indigo,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    if (replyText != null && replyText.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.15)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(9),
                          border: Border(
                            left: BorderSide(
                              color: isMine ? Colors.white70 : _indigo,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              replyName ?? 'Reply',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isMine ? Colors.white : _indigo,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              replyText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isMine ? Colors.white70 : _secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (type == 'text' || fileUrl.isEmpty)
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: isMine ? Colors.white : _primaryText,
                        ),
                      )
                    else
                      _buildAttachmentContent(
                        type: type,
                        fileUrl: fileUrl,
                        fileName: fileName,
                        isMine: isMine,
                      ),
                    const SizedBox(height: 7),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (edited) ...[
                          Text(
                            'Edited',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: isMine ? Colors.white70 : _secondaryText,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          _formatTime(timestamp),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMine ? Colors.white70 : _secondaryText,
                          ),
                        ),
                        if (isMine) ...[
                          const SizedBox(width: 5),
                          Icon(
                            read ? Icons.done_all_rounded : Icons.done_rounded,
                            size: 15,
                            color: read
                                ? const Color(0xFF93C5FD)
                                : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Message options',
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: Color(0xFF64748B),
            ),
            onSelected: (value) {
              switch (value) {
                case 'reply':
                  _replyTo(id: messageId, text: text, senderName: senderName);
                  break;
                case 'edit':
                  if (isMine && type == 'text') _editMessage(messageId, text);
                  break;
                case 'delete':
                  if (isMine) _deleteMessage(messageId);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String>(
                value: 'reply',
                child: Row(
                  children: [
                    Icon(Icons.reply_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Reply'),
                  ],
                ),
              ),
              if (isMine && type == 'text')
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 20),
                      SizedBox(width: 10),
                      Text('Edit message'),
                    ],
                  ),
                ),
              if (isMine)
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: Colors.red,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Delete message',
                        style: TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() => SafeArea(
    top: false,
    child: Container(
      padding: const EdgeInsets.fromLTRB(8, 9, 10, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_uploadingAttachment) ...[
            const LinearProgressIndicator(minHeight: 2, color: _indigo),
            const SizedBox(height: 8),
          ],
          if (_replyId != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: const Border(
                  left: BorderSide(color: _indigo, width: 4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyName ?? 'User'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _indigo,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _replyText ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: _secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel reply',
                    onPressed: () => setState(() {
                      _replyId = null;
                      _replyText = null;
                      _replyName = null;
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Upload image',
                onPressed: (_uploadingAttachment || _sending)
                    ? null
                    : () => _pickAttachment(imageOnly: true),
                icon: const Icon(Icons.image_outlined, color: _indigo),
              ),
              IconButton(
                tooltip: 'Attach file',
                onPressed: (_uploadingAttachment || _sending)
                    ? null
                    : () => _pickAttachment(imageOnly: false),
                icon: const Icon(Icons.attach_file_rounded, color: _indigo),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Message ${widget.otherName}…',
                    hintStyle: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: _indigo, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_indigo, _darkIndigo],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  tooltip: 'Send message',
                  onPressed: (_sending || _uploadingAttachment) ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _buildEmptyState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Icon(Icons.forum_rounded, size: 35, color: _indigo),
          ),
          const SizedBox(height: 18),
          const Text(
            'Start a conversation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send a message to ${widget.otherName} and start collaborating.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: _secondaryText,
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: _background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(86),
        child: Container(
          color: const Color(0xFFF5F7FB),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: _buildHeader(),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/chat_background.png.jpeg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: _background),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.white.withValues(alpha: 0.48)),
          ),
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _service.watchMessages(widget.chatId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _indigo),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Could not load private messages.'),
                      );
                    }
                    final messages = snapshot.data?.docs ?? [];
                    if (currentUid != null &&
                        !_markingRead &&
                        messages.any((doc) {
                          final data = doc.data();
                          return data['senderId'] != currentUid &&
                              data['isRead'] != true;
                        })) {
                      _markingRead = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        try {
                          await _service.markMessagesRead(
                            widget.chatId,
                            messages,
                          );
                        } catch (error) {
                          debugPrint('Mark read failed: $error');
                        } finally {
                          _markingRead = false;
                        }
                      });
                    }
                    if (messages.isEmpty) return _buildEmptyState();
                    return ListView.builder(
                      reverse: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 20, 8, 20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final doc = messages[index];
                        return _buildBubble(
                          messageId: doc.id,
                          data: doc.data(),
                          isMine: doc.data()['senderId'] == currentUid,
                        );
                      },
                    );
                  },
                ),
              ),
              _buildComposer(),
            ],
          ),
        ],
      ),
    );
  }
}
