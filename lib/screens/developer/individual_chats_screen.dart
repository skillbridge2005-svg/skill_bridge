import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/individual_chat_service.dart';
import '../../widgets/skillbridge_avatar.dart';
import 'individual_chat_screen.dart' hide IndividualChatService;

/// Lists the developer's one-to-one conversations.
///
/// Set [showAppBar] to false when this screen is shown inside
/// DeveloperMessagesHubScreen. Its existing service and chat screen are reused.
class IndividualChatsScreen extends StatefulWidget {
  const IndividualChatsScreen({super.key, this.showAppBar = true});

  final bool showAppBar;

  @override
  State<IndividualChatsScreen> createState() => _IndividualChatsScreenState();
}

class _IndividualChatsScreenState extends State<IndividualChatsScreen> {
  static const Color _page = Color(0xFFF6F8FC);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF64748B);
  static const Color _blue = Color(0xFF2563EB);
  static const Color _border = Color(0xFFE2E8F0);

  final IndividualChatService _chatService = IndividualChatService();
  final TextEditingController _searchController = TextEditingController();

  late Stream<QuerySnapshot<Map<String, dynamic>>> _conversationsStream;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _conversationsStream = _chatService.watchConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _retryLoading() {
    setState(() {
      _conversationsStream = _chatService.watchConversations();
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);

    if (messageDay == today) {
      final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    }

    if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }

    const months = <String>[
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
    if (date.year == now.year) {
      return '${months[date.month - 1]} ${date.day}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Map<String, dynamic> _toStringKeyedMap(dynamic value) {
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  List<String> _toStringList(dynamic value) {
    if (value is! Iterable) return <String>[];
    return value
        .where((item) => item != null)
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Widget _buildPageHeading() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: _blue,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Individual messages',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Continue your private conversations.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value.trim().toLowerCase());
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search people or messages',
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: _muted, size: 21),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _blue, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: _blue),
          ),
          SizedBox(height: 14),
          Text(
            'Loading conversations…',
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.cloud_off_rounded,
                    color: Color(0xFFDC2626),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Unable to load individual chats',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your connection and Firestore permissions, then try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, height: 1.45, fontSize: 12),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _retryLoading,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                ),
                if (error.toString().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text(
                      'Technical details',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                    children: [
                      SelectableText(
                        error.toString(),
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool searching}) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFEFF6FF), Color(0xFFEDE9FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                searching ? Icons.search_off_rounded : Icons.forum_outlined,
                color: _blue,
                size: 39,
              ),
            ),
            const SizedBox(height: 19),
            Text(
              searching ? 'No matching conversations' : 'No private chats yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searching ? 'Try another name or search term.' : 'Open a team, select a member, and choose “Message privately” to start a conversation.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13, height: 1.55),
            ),
            if (searching) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.close_rounded, size: 17),
                label: const Text('Clear search'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(_ConversationRow row) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => IndividualChatScreen(
                chatId: row.chatId,
                otherUid: row.otherUid,
                otherName: row.otherName,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x050F172A),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(row.otherUid)
                    .snapshots(),
                builder: (context, profileSnapshot) {
                  final profile =
                      profileSnapshot.data?.data() ?? <String, dynamic>{};
                  final name = (profile['name'] ?? row.otherName).toString();
                  final imageUrl = profile['profileImageUrl']?.toString();

                  return SkillBridgeAvatar(
                    profileImageUrl: imageUrl,
                    name: name,
                    size: 54,
                    backgroundColor: const Color(0xFFE0E7FF),
                    foregroundColor: const Color(0xFF4338CA),
                  );
                },
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.otherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      row.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (row.date != null)
                    Text(
                      _formatDate(row.date!),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                  const SizedBox(height: 8),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('individualChats')
                        .doc(row.chatId)
                        .collection('messages')
                        .where('isRead', isEqualTo: false)
                        .snapshots(),
                    builder: (context, unreadSnapshot) {
                      final currentUid = FirebaseAuth.instance.currentUser?.uid;

                      final unreadCount = currentUid == null
                          ? 0
                          : (unreadSnapshot.data?.docs ?? [])
                                .where(
                                  (doc) =>
                                      doc.data()['senderId']?.toString() !=
                                      currentUid,
                                )
                                .length;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (unreadCount > 0) ...[
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.chevron_right_rounded,
                              size: 19,
                              color: _muted,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: _page,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: _ink),
              title: const Text(
                'Individual Chats',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
              ),
              bottom: const PreferredSize(
                preferredSize: Size.fromHeight(1),
                child: Divider(height: 1, color: _border),
              ),
            )
          : null,
      body: currentUid == null
          ? _buildSignInState()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPageHeading(),
                _buildSearchField(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _conversationsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _buildError(snapshot.error!);
                      }

                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return _buildLoading();
                      }

                      final conversations = snapshot.data?.docs ?? [];
                      final rows = <_ConversationRow>[];

                      for (final document in conversations) {
                        final data = document.data();
                        final participants = _toStringList(
                          data['participants'],
                        );
                        final otherUsers = participants
                            .where((uid) => uid != currentUid)
                            .toList();

                        // Individual conversations must have exactly one other user.
                        if (otherUsers.length != 1) continue;

                        final otherUid = otherUsers.single;
                        final names = _toStringKeyedMap(
                          data['participantNames'],
                        );
                        final storedName = (names[otherUid] ?? '')
                            .toString()
                            .trim();
                        final otherName = storedName.isNotEmpty
                            ? storedName
                            : 'Team member';

                        final lastMessage = (data['lastMessage'] ?? '')
                            .toString()
                            .trim();
                        final lastSenderId = (data['lastSenderId'] ?? '')
                            .toString();
                        final preview = lastMessage.isEmpty
                            ? 'No messages yet'
                            : lastSenderId == currentUid
                            ? 'You: $lastMessage'
                            : lastMessage;

                        final row = _ConversationRow(
                          chatId: document.id,
                          otherUid: otherUid,
                          otherName: otherName,
                          preview: preview,
                          date: _toDate(data['updatedAt']),
                        );

                        final query = _searchQuery;
                        if (query.isEmpty ||
                            row.otherName.toLowerCase().contains(query) ||
                            row.preview.toLowerCase().contains(query)) {
                          rows.add(row);
                        }
                      }

                      rows.sort((a, b) {
                        final aDate =
                            a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
                        final bDate =
                            b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
                        return bDate.compareTo(aDate);
                      });

                      if (rows.isEmpty) {
                        return _buildEmptyState(
                          searching: _searchQuery.isNotEmpty,
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) =>
                            _buildConversationTile(rows[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSignInState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 42, color: _muted),
            const SizedBox(height: 12),
            const Text(
              'Sign in to view your conversations',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your private chats will appear here after you sign in.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.4, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationRow {
  const _ConversationRow({
    required this.chatId,
    required this.otherUid,
    required this.otherName,
    required this.preview,
    required this.date,
  });

  final String chatId;
  final String otherUid;
  final String otherName;
  final String preview;
  final DateTime? date;
}
