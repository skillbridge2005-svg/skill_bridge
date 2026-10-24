import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/team_chat_service.dart';

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
  final TeamChatService _chat = TeamChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _sending = false;
  bool _uploadingImage = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _messageController.clear();

    try {
      await _chat.sendMessage(teamId: widget.teamId, text: text);
    } catch (error) {
      if (!mounted) return;

      _messageController.text = text;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send message: $error')));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
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

final shouldSend = await showDialog<bool>(
  context: context,
  builder: (dialogContext) {
    return AlertDialog(
      title: const Text('Send image?'),
      content: SizedBox(
        width: 320,
        height: 280,
        child: Image.memory(
          imageBytes,
          width: 320,
          height: 280,
          fit: BoxFit.contain,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(dialogContext).pop(true),
          icon: const Icon(Icons.send),
          label: const Text('Send'),
        ),
      ],
    );
  },
);


      if (shouldSend != true || !mounted) return;

      setState(() => _uploadingImage = true);

      await _chat.sendImageMessage(
        teamId: widget.teamId,
        imageBytes: imageBytes,
        fileName: pickedFile.name,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Image sent successfully.')));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not upload image: $error')));
    } finally {
      if (mounted) {
        setState(() => _uploadingImage = false);
      }
    }
  }

  Widget _buildMessageBubble({
    required Map<String, dynamic> data,
    required bool isMine,
    required String time,
  }) {
    final isImage = data['type'] == 'image';
    final imageUrl = (data['imageUrl'] ?? '').toString();

    final bubbleColor = isMine
        ? const Color(0xFF2563EB)
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    final textColor = isMine
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  (data['senderName'] ?? 'Team member').toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            if (isImage)
              if (imageUrl.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    showDialog<void>(
                      context: context,
                      builder: (dialogContext) => Dialog(
                        child: InteractiveViewer(
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;

                              return const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Unable to load image.'),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imageUrl,
                      width: 220,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;

                        return const SizedBox(
                          width: 220,
                          height: 180,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          width: 220,
                          height: 100,
                          child: Center(child: Text('Unable to load image.')),
                        );
                      },
                    ),
                  ),
                )
              else
                const Text('Image unavailable'),
            if (!isImage && (data['text'] ?? '').toString().isNotEmpty)
              Text(data['text'].toString(), style: TextStyle(color: textColor)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: isMine
                      ? Colors.white70
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.teamName),
            const Text('Team group chat', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
      body: StreamBuilder<bool>(
        stream: _chat.watchMembership(widget.teamId),
        builder: (context, membershipSnapshot) {
          if (membershipSnapshot.hasError) {
            return const Center(
              child: Text('Unable to verify team membership.'),
            );
          }

          if (!membershipSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (membershipSnapshot.data != true) {
            return const Center(
              child: Text('Only accepted team members can access this chat.'),
            );
          }

          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _chat.watchMessages(widget.teamId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Could not load messages.'),
                      );
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final messages = snapshot.data!.docs;

                    if (messages.isEmpty) {
                      return const Center(
                        child: Text(
                          'No messages yet.\nSay hello to your team!',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final data = messages[index].data();
                        final isMine = data['senderId'] == currentUid;
                        final timestamp = data['createdAt'];

                        final time = timestamp is Timestamp
                            ? TimeOfDay.fromDateTime(timestamp.toDate())
                                  .format(context)
                            : 'Sending…';

                        return _buildMessageBubble(
                          data: data,
                          isMine: isMine,
                          time: time,
                        );
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Upload image',
                        onPressed: _uploadingImage ? null : _pickAndSendImage,
                        icon: _uploadingImage
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.image_outlined),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            hintText: 'Message your team…',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
