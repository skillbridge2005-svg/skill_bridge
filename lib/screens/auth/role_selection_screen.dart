import 'package:flutter/material.dart';

import 'login_screen.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color titleColor = Color(0xFF0F172A);
  static const Color mutedText = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color background = Color(0xFFF8FAFC);

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String _selectedRole = 'developer';

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(role: _selectedRole),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoleSelectionScreen.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Image.asset(
                      'assets/images/skillbridge_logo.png',
                      width: 210,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Build. Connect. Grow.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: RoleSelectionScreen.titleColor,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Choose how you want to use SkillBridge and start connecting with real-world software opportunities.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RoleSelectionScreen.mutedText,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Text(
                    'Choose your role',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: RoleSelectionScreen.titleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'You can change your role later.',
                    style: TextStyle(
                      fontSize: 13,
                      color: RoleSelectionScreen.mutedText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _RoleCard(
                    role: 'developer',
                    title: 'Developer',
                    description:
                        'Find projects, showcase your skills, work with teams and earn.',
                    icon: Icons.code_rounded,
                    iconBackground: const Color(0xFFEFF6FF),
                    iconColor: RoleSelectionScreen.primary,
                    selected: _selectedRole == 'developer',
                    onTap: () {
                      setState(() {
                        _selectedRole = 'developer';
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    role: 'client',
                    title: 'Client',
                    description:
                        'Post your project, find skilled developers and manage your project.',
                    icon: Icons.business_center_rounded,
                    iconBackground: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF16A34A),
                    selected: _selectedRole == 'client',
                    onTap: () {
                      setState(() {
                        _selectedRole = 'client';
                      });
                    },
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _continue,
                      style: FilledButton.styleFrom(
                        backgroundColor: RoleSelectionScreen.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.selected,
    required this.onTap,
  });

  final String role;
  final String title;
  final String description;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected
              ? RoleSelectionScreen.primary.withValues(alpha: 0.08)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? RoleSelectionScreen.primary : RoleSelectionScreen.border,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: RoleSelectionScreen.titleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: RoleSelectionScreen.mutedText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: RoleSelectionScreen.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
