import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class HireDeveloperScreen extends StatelessWidget {
  const HireDeveloperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Hire Developer',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 800;

          return SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 32 : 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroSection(),
                    const SizedBox(height: 28),
                    const Text(
                      'What do you want to hire?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose an individual developer or hire a complete team.',
                      style: TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 20),
                    if (wide)
                      Row(
                        children: [
                          Expanded(
                            child: _HireOptionCard(
                              icon: Icons.person_search_rounded,
                              title: 'Individual Developer',
                              subtitle: 'Find a developer based on skills, technology, task or project.',
                              buttonText: 'Find Developers',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const FindDevelopersScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _HireOptionCard(
                              icon: Icons.groups_rounded,
                              title: 'Developer Team',
                              subtitle: 'Hire a complete team created by experienced developers.',
                              buttonText: 'Browse Teams',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DeveloperTeamsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _HireOptionCard(
                            icon: Icons.person_search_rounded,
                            title: 'Individual Developer',
                            subtitle: 'Find a developer based on skills, technology, task or project.',
                            buttonText: 'Find Developers',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FindDevelopersScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 18),
                          _HireOptionCard(
                            icon: Icons.groups_rounded,
                            title: 'Developer Team',
                            subtitle: 'Hire a complete team created by experienced developers.',
                            buttonText: 'Browse Teams',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DeveloperTeamsScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 22),
                    _AiHelpCard(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.handshake_rounded, color: Colors.white, size: 38),
          SizedBox(height: 18),
          Text(
            'Find the right developer for your work',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Hire an individual developer or a complete team directly for your project or specific task.',
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HireOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onTap;

  const _HireOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: const Color(0xFF4F46E5), size: 29),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AiHelpCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help deciding?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'AI can guide you about which type of developer or team you may need.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Color(0xFF4F46E5),
          ),
        ],
      ),
    );
  }
}

class FindDevelopersScreen extends StatefulWidget {
  const FindDevelopersScreen({super.key});

  @override
  State<FindDevelopersScreen> createState() => _FindDevelopersScreenState();
}

class _FindDevelopersScreenState extends State<FindDevelopersScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  String _filter = 'All';

  final List<String> _filters = [
    'All',
    'Skill',
    'Technology',
    'Task',
    'Project',
  ];

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value != null) {
      final text = value.toString().trim();

      if (text.isEmpty) {
        return [];
      }

      return [text];
    }

    return [];
  }

  String _listToSearchText(dynamic value) {
    return _toStringList(value).join(' ').toLowerCase();
  }

  bool _matches(Map<String, dynamic> data) {
    if (_search.isEmpty) {
      return true;
    }

    final name = data['name']?.toString().toLowerCase() ?? '';
    final bio = data['bio']?.toString().toLowerCase() ?? '';

    final skills = _listToSearchText(data['skills']);
    final technologies = _listToSearchText(data['technologies']);
    final tasks = _listToSearchText(data['tasks']);
    final projectTypes = _listToSearchText(data['projectTypes']);

    switch (_filter) {
      case 'Skill':
        return skills.contains(_search);

      case 'Technology':
        return technologies.contains(_search);

      case 'Task':
        return tasks.contains(_search);

      case 'Project':
        return projectTypes.contains(_search);

      case 'All':
      default:
        return name.contains(_search) ||
            bio.contains(_search) ||
            skills.contains(_search) ||
            technologies.contains(_search) ||
            tasks.contains(_search) ||
            projectTypes.contains(_search);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Find Developers',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchSection(),
          _buildFilterSection(),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'developer')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Unable to load developers.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 15,
                        ),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                  );
                }

                final developers =
                    snapshot.data?.docs.where((doc) {
                      return _matches(doc.data());
                    }).toList() ??
                    [];

                if (developers.isEmpty) {
                  return _EmptyState(
                    icon: Icons.person_search_rounded,
                    title: _search.isEmpty
                        ? 'No developers available'
                        : 'No developers found',
                    subtitle: _search.isEmpty
                        ? 'Developers will appear here when they complete their profiles.'
                        : 'Try another skill, technology, task or project type.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  itemCount: developers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final data = developers[index].data();

                    return _DeveloperCard(
                      data: data,
                      onTap: () {
                        _showDeveloperDetails(context, data);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search skill, technology, task or project...',
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF6B7280),
          ),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                  },
                  icon: const Icon(
                    Icons.clear_rounded,
                    color: Color(0xFF6B7280),
                  ),
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _filters.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = _filters[index];
            final selected = _filter == filter;

            return ChoiceChip(
              label: Text(filter),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _filter = filter;
                });
              },
              labelStyle: TextStyle(
                color: selected ? Colors.white : const Color(0xFF374151),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              selectedColor: const Color(0xFF4F46E5),
              backgroundColor: const Color(0xFFF8FAFC),
              side: BorderSide(
                color: selected
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFFE5E7EB),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            );
          },
        ),
      ),
    );
  }

  void _showDeveloperDetails(BuildContext context, Map<String, dynamic> data) {
    final name = data['name']?.toString().trim().isNotEmpty == true
        ? data['name'].toString()
        : 'Developer';

    final bio = data['bio']?.toString().trim().isNotEmpty == true
        ? data['bio'].toString()
        : 'Software Developer';

    final skills = _toStringList(data['skills']);
    final technologies = _toStringList(data['technologies']);
    final tasks = _toStringList(data['tasks']);
    final projectTypes = _toStringList(data['projectTypes']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xFF4F46E5),
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Developer',
                            style: TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  bio,
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                if (skills.isNotEmpty)
                  _buildDetailSection(
                    title: 'Skills',
                    icon: Icons.code_rounded,
                    items: skills,
                  ),
                if (technologies.isNotEmpty)
                  _buildDetailSection(
                    title: 'Technologies',
                    icon: Icons.memory_rounded,
                    items: technologies,
                  ),
                if (tasks.isNotEmpty)
                  _buildDetailSection(
                    title: 'Can help with',
                    icon: Icons.task_alt_rounded,
                    items: tasks,
                  ),
                if (projectTypes.isNotEmpty)
                  _buildDetailSection(
                    title: 'Project Types',
                    icon: Icons.work_outline_rounded,
                    items: projectTypes,
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Developer hiring request will be connected next.',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.handshake_rounded),
                    label: const Text('Hire Developer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3730A3),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class DeveloperTeamsScreen extends StatefulWidget {
  const DeveloperTeamsScreen({super.key});

  @override
  State<DeveloperTeamsScreen> createState() => _DeveloperTeamsScreenState();
}

class _DeveloperTeamsScreenState extends State<DeveloperTeamsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _search = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Map<String, dynamic> data) {
    if (_search.isEmpty) return true;

    final name = data['name']?.toString().toLowerCase() ?? '';
    final description = data['description']?.toString().toLowerCase() ?? '';

    final skills = data['skills'];

    String skillText = '';

    if (skills is List) {
      skillText = skills.join(' ').toLowerCase();
    } else {
      skillText = skills?.toString().toLowerCase() ?? '';
    }

    return name.contains(_search) ||
        description.contains(_search) ||
        skillText.contains(_search);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Developer Teams',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search Flutter team, full stack...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.isNotEmpty
                    ? IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear_rounded),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('teams')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Unable to load teams.'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final teams =
                    snapshot.data?.docs.where((doc) {
                      return _matches(doc.data());
                    }).toList() ??
                    [];

                if (teams.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.groups_rounded,
                    title: 'No developer teams yet',
                    subtitle: 'Teams created by developers will appear here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: teams.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final data = teams[index].data();

                    return _TeamCard(
                      data: data,
                      onTap: () {
                        _showTeamDetails(context, data);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTeamDetails(BuildContext context, Map<String, dynamic> data) {
    final name = data['name']?.toString() ?? 'Developer Team';
    final description =
        data['description']?.toString() ?? 'Software development team';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Team hiring flow will be connected next.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Hire Team'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _DeveloperCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? 'Developer';
    final bio = data['bio']?.toString() ?? 'Software Developer';
    final skills = data['skills'];

    final skillList = skills is List
        ? skills.map((e) => e.toString()).take(5).toList()
        : <String>[];

    return _BaseCard(
      icon: Icons.person_rounded,
      title: name,
      subtitle: bio,
      chips: skillList,
      buttonText: 'View Profile',
      onTap: onTap,
    );
  }
}

class _TeamCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _TeamCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = data['name']?.toString() ?? 'Developer Team';
    final description =
        data['description']?.toString() ?? 'Software Development Team';

    final skills = data['skills'];

    final skillList = skills is List
        ? skills.map((e) => e.toString()).take(5).toList()
        : <String>[];

    return _BaseCard(
      icon: Icons.groups_rounded,
      title: name,
      subtitle: description,
      chips: skillList,
      buttonText: 'View Team',
      onTap: onTap,
    );
  }
}

class _BaseCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> chips;
  final String buttonText;
  final VoidCallback onTap;

  const _BaseCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF6B7280), height: 1.45),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: chips.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    skill,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFFC7D2FE)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(icon, size: 34, color: const Color(0xFF4F46E5)),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
