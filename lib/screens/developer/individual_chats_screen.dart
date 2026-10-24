
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/individual_chat_service.dart';
import 'individual_chat_screen.dart';

class IndividualChatsScreen extends StatelessWidget {
  IndividualChatsScreen({super.key});

  final IndividualChatService _chatService = IndividualChatService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text(
          'Individual Chats',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _chatService.watchConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load individual chats',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final conversations = snapshot.data?.docs ?? [];
          final currentUid = FirebaseAuth.instance.currentUser?.uid;

          if (currentUid == null) {
            return const Center(
              child: Text('Please sign in to view your conversations.'),
            );
          }

          if (conversations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 48,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No private chats yet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Open a team, select a member, and tap '
                      '"Message privately" to start a conversation.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        height: 1.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (_, index) =>
                const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final document = conversations[index];
              final data = document.data();

              final participants =
                  List<String>.from(data['participants'] ?? []);

              final otherUsers = participants
                  .where((uid) => uid != currentUid)
                  .toList();

              if (otherUsers.length != 1) {
                return const SizedBox.shrink();
              }

              final otherUid = otherUsers.first;

              final names = Map<String, dynamic>.from(
                data['participantNames'] ?? {},
              );

              final otherName =
                  (names[otherUid] ?? 'Team member').toString();

              final lastMessage =
                  (data['lastMessage'] ?? '').toString();

              final lastSenderId =
                  (data['lastSenderId'] ?? '').toString();

              final timestamp = data['updatedAt'];
              final date = timestamp is Timestamp
                  ? timestamp.toDate()
                  : null;

              final preview = lastMessage.isEmpty
                  ? 'No messages yet'
                  : lastSenderId == currentUid
                      ? 'You: $lastMessage'
                      : lastMessage;

              return Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(
                    color: Color(0xFFE5E7EB),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: const Color(0xFFE0E7FF),
                    child: Text(
                      otherName.trim().isEmpty
                          ? '?'
                          : otherName.trim()[0].toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF4338CA),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  title: Text(
                    otherName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (date != null)
                        Text(
                          _formatDate(date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF9CA3AF),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IndividualChatScreen(
                          chatId: document.id,
                          otherUid: otherUid,
                          otherName: otherName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();

    final sameDay = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;

    if (sameDay) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    }

    final yesterday = now.subtract(const Duration(days: 1));

    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }

    return '${date.day}/${date.month}/${date.year}';
  }
}
