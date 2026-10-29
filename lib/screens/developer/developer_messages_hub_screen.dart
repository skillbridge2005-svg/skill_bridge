import 'package:flutter/material.dart';

import 'individual_chats_screen.dart';
import 'team_messages_screen.dart';

/// One entry point for a developer's private conversations and team chats.
/// Existing list/chat services are reused; the selector only changes the list.
class DeveloperMessagesHubScreen extends StatefulWidget {
  const DeveloperMessagesHubScreen({super.key});

  @override
  State<DeveloperMessagesHubScreen> createState() =>
      _DeveloperMessagesHubScreenState();
}

class _DeveloperMessagesHubScreenState
    extends State<DeveloperMessagesHubScreen> {
  int _selectedIndex = 0;

  static const Color _page = Color(0xFFF6F8FC);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 76,
        iconTheme: const IconThemeData(color: _ink),
        titleSpacing: 4,
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x263B82F6),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Chats',
                    style: TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Private conversations and team updates',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _ChatModeSelector(
                  selectedIndex: _selectedIndex,
                  onChanged: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                ),
              ),
            ),
          ),
          Expanded(
            // Keep each list's state while switching between the two tabs.
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                IndividualChatsScreen(showAppBar: false),
                const TeamMessagesScreen(showAppBar: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatModeSelector extends StatelessWidget {
  const _ChatModeSelector({
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const Color _blue = Color(0xFF2563EB);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ChatModeButton(
              selected: selectedIndex == 0,
              icon: Icons.person_rounded,
              title: 'Individual chats',
              subtitle: 'Private messages',
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _ChatModeButton(
              selected: selectedIndex == 1,
              icon: Icons.groups_rounded,
              title: 'Team chats',
              subtitle: 'Project groups',
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatModeButton extends StatelessWidget {
  const _ChatModeButton({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const Color _blue = Color(0xFF2563EB);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x0D0F172A),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFEFF6FF) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: selected ? _blue : _muted),
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? _ink : _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? _blue : _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
