import 'package:flutter/material.dart';

import 'auth/login_screen.dart';
import 'auth/role_selection_screen.dart';

class SkillBridgeLandingPage extends StatelessWidget {
  const SkillBridgeLandingPage({super.key});

  void _goToRoleSelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
    );
  }

  void _goToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen(role: 'developer')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildNavbar(context),
            _buildHero(context),
            _buildAbout(context),
            _buildForUsers(context),
            _buildHowItWorks(context),
            _buildAiSection(context),
            _buildFinalCta(context),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildNavbar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;

              if (isMobile) {
                return Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [_Logo()],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _goToLogin(context),
                            child: const Text('Log in'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _goToRoleSelection(context),
                            child: const Text('Get Started'),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  const _Logo(),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => _goToLogin(context),
                    child: const Text('Log in'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => _goToRoleSelection(context),
                    child: const Text('Get Started'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 90),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'A platform for software projects',
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Build. Connect. Grow.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'SkillBridge connects clients who need software solutions '
                'with developers who have the skills to build them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFF64748B),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 34),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => _goToRoleSelection(context),
                    icon: const Icon(Icons.rocket_launch_rounded),
                    label: const Text('Get Started'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _goToRoleSelection(context),
                    icon: const Icon(Icons.person_outline_rounded),
                    label: const Text('Join as Developer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbout(BuildContext context) {
    return _Section(
      title: 'What is SkillBridge?',
      subtitle:
          'SkillBridge is a software project platform designed to bring '
          'clients and skilled developers together in one place.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final items = [
            _FeatureCard(
              icon: Icons.work_outline_rounded,
              title: 'Software Projects',
              description:
                  'Clients can share software requirements and connect '
                  'with developers who can build the solution.',
              onTap: () => _goToRoleSelection(context),
            ),
            _FeatureCard(
              icon: Icons.groups_outlined,
              title: 'Team Collaboration',
              description:
                  'Developers can collaborate using suitable roles '
                  'such as frontend, backend and database development.',
              onTap: () => _goToRoleSelection(context),
            ),
            _FeatureCard(
              icon: Icons.smart_toy_outlined,
              title: 'AI Assistance',
              description:
                  'AI helps understand requirements, organize project '
                  'information and support project planning.',
              onTap: () => _goToRoleSelection(context),
            ),
          ];

          if (constraints.maxWidth > 800) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items
                  .map(
                    (item) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: item,
                      ),
                    ),
                  )
                  .toList(),
            );
          }

          return Column(
            children: items
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: item,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildForUsers(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 70),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              const Text(
                'Built for both sides of the project',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'One platform, two roles, one connected workflow.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 35),
              LayoutBuilder(
                builder: (context, constraints) {
                  final clientCard = _RoleCard(
                    icon: Icons.business_center_outlined,
                    title: 'For Clients',
                    description:
                        'Turn your software idea into a structured '
                        'project and connect with developers.',
                    features: const [
                      'Create project requirements',
                      'Get AI-assisted requirement support',
                      'Build a suitable development team',
                      'Track project progress',
                    ],
                    onTap: () => _goToRoleSelection(context),
                  );

                  final developerCard = _RoleCard(
                    icon: Icons.code_rounded,
                    title: 'For Developers',
                    description:
                        'Use your skills to work on software projects '
                        'and collaborate with other developers.',
                    features: const [
                      'Discover software projects',
                      'Show your skills and profile',
                      'Join development teams',
                      'Work through a structured workflow',
                    ],
                    onTap: () => _goToRoleSelection(context),
                  );

                  if (constraints.maxWidth > 700) {
                    return Row(
                      children: [
                        Expanded(child: clientCard),
                        const SizedBox(width: 20),
                        Expanded(child: developerCard),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      clientCard,
                      const SizedBox(height: 20),
                      developerCard,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowItWorks(BuildContext context) {
    const steps = [
      (
        '01',
        'Create a Requirement',
        'The client describes the software idea and project needs.',
        Icons.edit_note_rounded,
      ),
      (
        '02',
        'Understand & Plan',
        'AI helps organize the requirement and support initial planning.',
        Icons.psychology_outlined,
      ),
      (
        '03',
        'Form the Team',
        'Suitable developers can collaborate according to project roles.',
        Icons.groups_rounded,
      ),
      (
        '04',
        'Build & Test',
        'The team develops, reviews and tests the software.',
        Icons.build_circle_outlined,
      ),
      (
        '05',
        'Deliver',
        'The completed software moves through review and final delivery.',
        Icons.task_alt_rounded,
      ),
    ];

    return _Section(
      title: 'How SkillBridge works',
      subtitle: 'A structured workflow from project idea to software delivery.',
      child: Column(
        children: steps.map((step) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _StepCard(
              number: step.$1,
              title: step.$2,
              description: step.$3,
              icon: step.$4,
              onTap: () => _goToRoleSelection(context),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAiSection(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 75),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI-assisted project planning',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SkillBridge uses AI to help convert a client idea '
                    'into clearer project requirements, questions, '
                    'preliminary planning and project information.',
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.6,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(height: 25),
                  _DarkFeature(
                    icon: Icons.chat_outlined,
                    text: 'Understand project requirements',
                  ),
                  _DarkFeature(
                    icon: Icons.question_answer_outlined,
                    text: 'Ask useful clarification questions',
                  ),
                  _DarkFeature(
                    icon: Icons.description_outlined,
                    text: 'Organize project information',
                  ),
                  _DarkFeature(
                    icon: Icons.timeline_outlined,
                    text: 'Support preliminary planning',
                  ),
                  const SizedBox(height: 15),
                  FilledButton(
                    onPressed: () => _goToRoleSelection(context),
                    child: const Text('Explore SkillBridge'),
                  ),
                ],
              );

              final visual = InkWell(
                onTap: () => _goToRoleSelection(context),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF334155)),
                    color: const Color(0xFF111827),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                      SizedBox(height: 20),
                      Text(
                        'AI Project Assistant',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'From idea to clearer requirements',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              );

              if (constraints.maxWidth > 800) {
                return Row(
                  children: [
                    Expanded(child: content),
                    const SizedBox(width: 60),
                    Expanded(child: visual),
                  ],
                );
              }

              return Column(
                children: [content, const SizedBox(height: 35), visual],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFinalCta(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              const Text(
                'Have a project or a skill?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'SkillBridge brings software ideas and developers '
                'together on one platform.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              FilledButton.icon(
                onPressed: () => _goToRoleSelection(context),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Join SkillBridge'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      color: const Color(0xFF0F172A),
      child: const Center(
        child: Text(
          'SkillBridge • Build. Connect. Grow.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 10),
        const Text(
          'SkillBridge',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 70),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 750),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF64748B),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 38),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<String> features;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.features,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB), size: 28),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            ...features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 19,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final String number;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _StepCard({
    required this.number,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      height: 1.4,
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
}

class _DarkFeature extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DarkFeature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
