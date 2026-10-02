import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

class DeveloperProfile extends StatefulWidget {

  const DeveloperProfile({super.key});

  @override

  State<DeveloperProfile> createState() => _DeveloperProfileState();

}

class _DeveloperProfileState extends State<DeveloperProfile>

    with SingleTickerProviderStateMixin {

  final _formKey = GlobalKey<FormState>();

  final _headlineController = TextEditingController();

  final _bioController = TextEditingController();

  final _locationController = TextEditingController();

  final _photoUrlController = TextEditingController();

  final _experienceController = TextEditingController();

  final _educationController = TextEditingController();

  final _githubController = TextEditingController();

  final _linkedinController = TextEditingController();

  final _portfolioController = TextEditingController();

  final _resumeController = TextEditingController();

  final _skillController = TextEditingController();

  final _technologyController = TextEditingController();

  final _rateController = TextEditingController();

  late AnimationController _animationController;

  bool _loading = true;

  bool _saving = false;

  bool _hasChanges = false;

  String _name = '';

  String _email = '';

  String _availability = 'Available';

  String _workMode = 'Remote';

  String _projectType = 'Both';

  String _projectDuration = 'Flexible';

  int _hoursPerWeek = 20;

  bool _profileVisible = true;

  bool _openToTeams = true;

  List<String> _skills = [];

  List<String> _technologies = [];

  List<String> _languages = ['English'];

  @override

  void initState() {

    super.initState();

    _animationController = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 900),

    );

    _loadProfile();

    _headlineController.addListener(_markChanged);

    _bioController.addListener(_markChanged);

    _locationController.addListener(_markChanged);

    _photoUrlController.addListener(_markChanged);

    _experienceController.addListener(_markChanged);

    _educationController.addListener(_markChanged);

    _githubController.addListener(_markChanged);

    _linkedinController.addListener(_markChanged);

    _portfolioController.addListener(_markChanged);

    _resumeController.addListener(_markChanged);

    _rateController.addListener(_markChanged);

  }

  void _markChanged() {

    if (!_loading && !_saving && mounted) {

      setState(() {

        _hasChanges = true;

      });

    }

  }

  List<String> _stringList(dynamic value, {List<String> fallback = const []}) {
    if (value is! List) return List<String>.from(fallback);
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  bool _readBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    return fallback;
  }

  Future<void> _loadProfile() async {

    try {

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }

      _email = user.email ?? '';

      final userDoc = await FirebaseFirestore.instance

          .collection('users')

          .doc(user.uid)

          .get();

      if (userDoc.exists) {

        final userData = userDoc.data();

        _name = userData?['name']?.toString() ?? '';

      }

      final profileDoc = await FirebaseFirestore.instance

          .collection('developerProfiles')

          .doc(user.uid)

          .get();

      if (profileDoc.exists) {

        final data = profileDoc.data()!;

        _headlineController.text =

            data['headline']?.toString() ?? '';

        _bioController.text =

            data['bio']?.toString() ?? '';

        _locationController.text =

            data['location']?.toString() ?? '';

        _photoUrlController.text =

            data['photoUrl']?.toString() ?? '';

        _experienceController.text =

            data['experience']?.toString() ?? '';

        _educationController.text =

            data['education']?.toString() ?? '';

        _githubController.text =

            data['githubUrl']?.toString() ?? '';

        _linkedinController.text =

            data['linkedinUrl']?.toString() ?? '';

        _portfolioController.text =

            data['portfolioUrl']?.toString() ?? '';

        _resumeController.text =

            data['resumeUrl']?.toString() ?? '';

        _rateController.text =

            data['hourlyRate']?.toString() ?? '';

        _availability =

            data['availability']?.toString() ?? 'Available';

        _workMode =

            data['workMode']?.toString() ?? 'Remote';

        _projectType =

            data['projectType']?.toString() ?? 'Both';

        _projectDuration =

            data['projectDuration']?.toString() ?? 'Flexible';

        _hoursPerWeek =

            (data['hoursPerWeek'] as num?)?.toInt() ?? 20;

        _profileVisible =

            data['profileVisible'] ?? true;

        _openToTeams =

            data['openToTeams'] ?? true;

        _skills = List<String>.from(

          data['skills'] ?? [],

        );

        _technologies = List<String>.from(

          data['technologies'] ?? [],

        );

        _languages = List<String>.from(

          data['languages'] ?? ['English'],

        );

      }

      if (mounted) {

        setState(() {

          _loading = false;

        });

        _animationController.forward();

      }

    } catch (e) {

      if (mounted) {

        setState(() {

          _loading = false;

        });

        _showMessage(

          'Unable to load profile',

          isError: true,

        );

      }

    }

  }

  int _calculateCompletion() {

    int completed = 0;

    const total = 12;

    if (_name.trim().isNotEmpty) completed++;

    if (_headlineController.text.trim().isNotEmpty) completed++;

    if (_bioController.text.trim().isNotEmpty) completed++;

    if (_locationController.text.trim().isNotEmpty) completed++;

    if (_skills.isNotEmpty) completed++;

    if (_technologies.isNotEmpty) completed++;

    if (_experienceController.text.trim().isNotEmpty) completed++;

    if (_educationController.text.trim().isNotEmpty) completed++;

    if (_githubController.text.trim().isNotEmpty) completed++;

    if (_resumeController.text.trim().isNotEmpty) completed++;

    if (_availability.isNotEmpty) completed++;

    if (_projectType.isNotEmpty) completed++;

    return ((completed / total) * 100).round();

  }

  Future<void> _saveProfile() async {

    if (!_formKey.currentState!.validate()) {

      return;

    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    setState(() {

      _saving = true;

    });

    try {

      // Calculate the completion percentage once and use the same value

      // everywhere so both screens always show the same percentage.

      final completion = _calculateCompletion();

      final profileRef = FirebaseFirestore.instance

          .collection('developerProfiles')

          .doc(user.uid);

      // Check whether this is the first profile save.

      final existingProfile = await profileRef.get();

      final profileData = <String, dynamic>{

        'uid': user.uid,

        'name': _name,

        'email': _email,

        'headline': _headlineController.text.trim(),

        'bio': _bioController.text.trim(),

        'location': _locationController.text.trim(),

        'photoUrl': _photoUrlController.text.trim(),

        'experience': _experienceController.text.trim(),

        'education': _educationController.text.trim(),

        'skills': _skills,

        'technologies': _technologies,

        'languages': _languages,

        'githubUrl': _githubController.text.trim(),

        'linkedinUrl': _linkedinController.text.trim(),

        'portfolioUrl': _portfolioController.text.trim(),

        'resumeUrl': _resumeController.text.trim(),

        'availability': _availability,

        'workMode': _workMode,

        'projectType': _projectType,

        'projectDuration': _projectDuration,

        'hoursPerWeek': _hoursPerWeek,

        'hourlyRate': _rateController.text.trim(),

        'profileVisible': _profileVisible,

        'openToTeams': _openToTeams,

        'profileCompletion': completion,

        'updatedAt': FieldValue.serverTimestamp(),

      };

      // createdAt is written only once and is never overwritten on later saves.

      if (!existingProfile.exists) {

        profileData['createdAt'] = FieldValue.serverTimestamp();

      }

      await profileRef.set(

        profileData,

        SetOptions(merge: true),

      );

      // Keep the users document synchronized for any other screen that uses it.

      await FirebaseFirestore.instance

          .collection('users')

          .doc(user.uid)

          .set(

        {

          'profileCompletion': completion,

        },

        SetOptions(merge: true),

      );

      if (mounted) {

        setState(() {

          _saving = false;

          _hasChanges = false;

        });

        _showMessage('Profile updated successfully');

      }

    } catch (e) {

      if (mounted) {

        setState(() {

          _saving = false;

        });

        _showMessage(

          'Could not save your profile',

          isError: true,

        );

      }

    }

  }

  void _showMessage(

    String message, {

    bool isError = false,

  }) {

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        behavior: SnackBarBehavior.floating,

        margin: const EdgeInsets.all(20),

        backgroundColor:

            isError ? Colors.red.shade700 : const Color(0xFF111827),

        shape: RoundedRectangleBorder(

          borderRadius: BorderRadius.circular(14),

        ),

        content: Row(

          children: [

            Icon(

              isError

                  ? Icons.error_outline_rounded

                  : Icons.check_circle_outline_rounded,

              color: Colors.white,

            ),

            const SizedBox(width: 12),

            Expanded(

              child: Text(message),

            ),

          ],

        ),

      ),

    );

  }

  void _addSkill() {

    final value = _skillController.text.trim();

    if (value.isEmpty) return;

    if (!_skills.contains(value)) {

      setState(() {

        _skills.add(value);

        _hasChanges = true;

      });

    }

    _skillController.clear();

  }

  void _addTechnology() {

    final value = _technologyController.text.trim();

    if (value.isEmpty) return;

    if (!_technologies.contains(value)) {

      setState(() {

        _technologies.add(value);

        _hasChanges = true;

      });

    }

    _technologyController.clear();

  }

  void _addLanguage(String language) {

    if (!_languages.contains(language)) {

      setState(() {

        _languages.add(language);

        _hasChanges = true;

      });

    }

  }

  @override

  void dispose() {

    _animationController.dispose();

    _headlineController.dispose();

    _bioController.dispose();

    _locationController.dispose();

    _photoUrlController.dispose();

    _experienceController.dispose();

    _educationController.dispose();

    _githubController.dispose();

    _linkedinController.dispose();

    _portfolioController.dispose();

    _resumeController.dispose();

    _skillController.dispose();

    _technologyController.dispose();

    _rateController.dispose();

    super.dispose();

  }

  @override

  Widget build(BuildContext context) {

    if (_loading) {

      return const Scaffold(

        body: Center(

          child: CircularProgressIndicator(),

        ),

      );

    }

    return WillPopScope(

      onWillPop: () async {

        if (_hasChanges) {

          return await _showDiscardDialog();

        }

        return true;

      },

      child: Scaffold(

        backgroundColor: const Color(0xFFF6F8FC),

        body: LayoutBuilder(

          builder: (context, constraints) {

            final isMobile = constraints.maxWidth < 700;

            return Stack(

              children: [

                _buildBackground(),

                SafeArea(

                  child: Column(

                    children: [

                      _buildTopBar(isMobile),

                      Expanded(

                        child: FadeTransition(

                          opacity: CurvedAnimation(

                            parent: _animationController,

                            curve: Curves.easeOut,

                          ),

                          child: SingleChildScrollView(

                            padding: EdgeInsets.fromLTRB(

                              isMobile ? 16 : 32,

                              20,

                              isMobile ? 16 : 32,

                              _hasChanges ? 110 : 40,

                            ),

                            child: Center(

                              child: ConstrainedBox(

                                constraints: const BoxConstraints(

                                  maxWidth: 1180,

                                ),

                                child: Column(

                                  crossAxisAlignment:

                                      CrossAxisAlignment.start,

                                  children: [

                                    _buildProfileHero(isMobile),

                                    const SizedBox(height: 28),

                                    if (_calculateCompletion() < 70)

                                      _buildCompletionBanner(),

                                    const SizedBox(height: 24),

                                    Form(

                                      key: _formKey,

                                      child: Column(

                                        children: [

                                          _buildBasicInformation(

                                            isMobile,

                                          ),

                                          const SizedBox(height: 22),

                                          _buildSkillsSection(

                                            isMobile,

                                          ),

                                          const SizedBox(height: 22),

                                          _buildProfessionalSection(

                                            isMobile,

                                          ),

                                          const SizedBox(height: 22),

                                          _buildPreferencesSection(

                                            isMobile,

                                          ),

                                          const SizedBox(height: 22),

                                          _buildLinksSection(

                                            isMobile,

                                          ),

                                          const SizedBox(height: 22),

                                          _buildLanguagesSection(

                                            isMobile,

                                          ),

                                          const SizedBox(height: 22),

                                          _buildPrivacySection(),

                                        ],

                                      ),

                                    ),

                                  ],

                                ),

                              ),

                            ),

                          ),

                        ),

                      ),

                    ],

                  ),

                ),

                if (_hasChanges)

                  _buildSaveBar(isMobile),

              ],

            );

          },

        ),

      ),

    );

  }

  Widget _buildBackground() {

    return Positioned.fill(

      child: IgnorePointer(

        child: Stack(

          children: [

            Positioned(

              top: -180,

              right: -120,

              child: Container(

                width: 420,

                height: 420,

                decoration: BoxDecoration(

                  shape: BoxShape.circle,

                  color: const Color(0xFF4F46E5).withOpacity(.06),

                ),

              ),

            ),

            Positioned(

              bottom: -180,

              left: -100,

              child: Container(

                width: 380,

                height: 380,

                decoration: BoxDecoration(

                  shape: BoxShape.circle,

                  color: const Color(0xFF06B6D4).withOpacity(.05),

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

  Widget _buildTopBar(bool isMobile) {

    return Container(

      padding: EdgeInsets.symmetric(

        horizontal: isMobile ? 16 : 32,

        vertical: 14,

      ),

      decoration: BoxDecoration(

        color: Colors.white.withOpacity(.92),

        border: const Border(

          bottom: BorderSide(

            color: Color(0xFFE5E7EB),

          ),

        ),

      ),

      child: Row(

        children: [

          IconButton(

            onPressed: () {

              Navigator.pop(context);

            },

            icon: const Icon(

              Icons.arrow_back_rounded,

            ),

          ),

          const SizedBox(width: 8),

          const Expanded(

            child: Text(

              'Developer Profile',

              style: TextStyle(

                fontSize: 20,

                fontWeight: FontWeight.w800,

                color: Color(0xFF111827),

              ),

            ),

          ),

          if (!isMobile)

            Text(

              _hasChanges

                  ? 'Unsaved changes'

                  : 'All changes saved',

              style: TextStyle(

                fontSize: 13,

                fontWeight: FontWeight.w600,

                color: _hasChanges

                    ? const Color(0xFFD97706)

                    : const Color(0xFF059669),

              ),

            ),

          const SizedBox(width: 12),

          _buildCompletionMini(),

        ],

      ),

    );

  }

  Widget _buildCompletionMini() {

    final percentage = _calculateCompletion();

    return Container(

      padding: const EdgeInsets.symmetric(

        horizontal: 12,

        vertical: 7,

      ),

      decoration: BoxDecoration(

        color: const Color(0xFFEEF2FF),

        borderRadius: BorderRadius.circular(30),

      ),

      child: Row(

        children: [

          SizedBox(

            width: 22,

            height: 22,

            child: CircularProgressIndicator(

              value: percentage / 100,

              strokeWidth: 3,

              backgroundColor: Colors.white,

              valueColor: const AlwaysStoppedAnimation(

                Color(0xFF4F46E5),

              ),

            ),

          ),

          const SizedBox(width: 8),

          Text(

            '$percentage%',

            style: const TextStyle(

              fontWeight: FontWeight.w800,

              color: Color(0xFF3730A3),

            ),

          ),

        ],

      ),

    );

  }

  Widget _buildProfileHero(bool isMobile) {

    final percentage = _calculateCompletion();

    return Container(

      padding: EdgeInsets.all(isMobile ? 22 : 30),

      decoration: BoxDecoration(

        borderRadius: BorderRadius.circular(28),

        gradient: const LinearGradient(

          colors: [

            Color(0xFF111827),

            Color(0xFF1E293B),

          ],

        ),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity(.10),

            blurRadius: 30,

            offset: const Offset(0, 12),

          ),

        ],

      ),

      child: isMobile

          ? Column(

              children: [

                _buildAvatar(size: 92),

                const SizedBox(height: 18),

                _buildHeroText(

                  percentage,

                  center: true,

                ),

              ],

            )

          : Row(

              children: [

                _buildAvatar(size: 110),

                const SizedBox(width: 26),

                Expanded(

                  child: _buildHeroText(

                    percentage,

                  ),

                ),

                _buildCompletionRing(percentage),

              ],

            ),

    );

  }

  Widget _buildAvatar({

    required double size,

  }) {

    final photo = _photoUrlController.text.trim();

    return Container(

      width: size,

      height: size,

      decoration: BoxDecoration(

        shape: BoxShape.circle,

        border: Border.all(

          color: Colors.white.withOpacity(.25),

          width: 4,

        ),

      ),

      child: ClipOval(

        child: photo.isNotEmpty

            ? Image.network(

                photo,

                fit: BoxFit.cover,

                errorBuilder: (_, __, ___) {

                  return _buildInitialAvatar(size);

                },

              )

            : _buildInitialAvatar(size),

      ),

    );

  }

  Widget _buildInitialAvatar(double size) {

    final initial = _name.trim().isEmpty

        ? 'D'

        : _name.trim()[0].toUpperCase();

    return Container(

      color: const Color(0xFF4F46E5),

      alignment: Alignment.center,

      child: Text(

        initial,

        style: TextStyle(

          color: Colors.white,

          fontSize: size * .35,

          fontWeight: FontWeight.w900,

        ),

      ),

    );

  }

  Widget _buildHeroText(

    int percentage, {

    bool center = false,

  }) {

    return Column(

      crossAxisAlignment: center

          ? CrossAxisAlignment.center

          : CrossAxisAlignment.start,

      children: [

        Text(

          _name.isEmpty ? 'Developer' : _name,

          textAlign: center ? TextAlign.center : null,

          style: const TextStyle(

            color: Colors.white,

            fontSize: 28,

            fontWeight: FontWeight.w900,

          ),

        ),

        const SizedBox(height: 7),

        Text(

          _headlineController.text.isEmpty

              ? 'Add your professional headline'

              : _headlineController.text,

          textAlign: center ? TextAlign.center : null,

          style: TextStyle(

            color: Colors.white.withOpacity(.72),

            fontSize: 15,

            fontWeight: FontWeight.w500,

          ),

        ),

        const SizedBox(height: 14),

        Row(

          mainAxisAlignment: center

              ? MainAxisAlignment.center

              : MainAxisAlignment.start,

          children: [

            const Icon(

              Icons.email_outlined,

              color: Colors.white54,

              size: 16,

            ),

            const SizedBox(width: 7),

            Flexible(

              child: Text(

                _email,

                style: const TextStyle(

                  color: Colors.white60,

                  fontSize: 13,

                ),

              ),

            ),

          ],

        ),

        const SizedBox(height: 18),

        Container(

          padding: const EdgeInsets.symmetric(

            horizontal: 12,

            vertical: 7,

          ),

          decoration: BoxDecoration(

            color: Colors.white.withOpacity(.08),

            borderRadius: BorderRadius.circular(30),

          ),

          child: Text(

            percentage >= 90

                ? 'Profile ready for marketplace'

                : 'Complete your profile to improve matching',

            style: const TextStyle(

              color: Colors.white,

              fontSize: 12,

              fontWeight: FontWeight.w600,

            ),

          ),

        ),

      ],

    );

  }

  Widget _buildCompletionRing(int percentage) {

    return SizedBox(

      width: 125,

      height: 125,

      child: Stack(

        alignment: Alignment.center,

        children: [

          SizedBox(

            width: 115,

            height: 115,

            child: CircularProgressIndicator(

              value: percentage / 100,

              strokeWidth: 9,

              backgroundColor: Colors.white.withOpacity(.08),

              valueColor: const AlwaysStoppedAnimation(

                Color(0xFF818CF8),

              ),

            ),

          ),

          Column(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              Text(

                '$percentage%',

                style: const TextStyle(

                  color: Colors.white,

                  fontSize: 25,

                  fontWeight: FontWeight.w900,

                ),

              ),

              const Text(

                'Complete',

                style: TextStyle(

                  color: Colors.white60,

                  fontSize: 11,

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }

  Widget _buildCompletionBanner() {

    return Container(

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: const Color(0xFFFFFBEB),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(

          color: const Color(0xFFFDE68A),

        ),

      ),

      child: Row(

        children: [

          Container(

            padding: const EdgeInsets.all(10),

            decoration: const BoxDecoration(

              color: Color(0xFFFEF3C7),

              shape: BoxShape.circle,

            ),

            child: const Icon(

              Icons.auto_awesome_rounded,

              color: Color(0xFFD97706),

            ),

          ),

          const SizedBox(width: 14),

          const Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  'Complete your developer profile',

                  style: TextStyle(

                    fontWeight: FontWeight.w800,

                    color: Color(0xFF92400E),

                  ),

                ),

                SizedBox(height: 4),

                Text(

                  'A complete profile helps SkillBridge match you with relevant projects.',

                  style: TextStyle(

                    fontSize: 13,

                    color: Color(0xFF78350F),

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

  Widget _buildBasicInformation(bool isMobile) {

    return _section(

      icon: Icons.person_outline_rounded,

      title: 'Basic Information',

      subtitle: 'Tell clients who you are and what you build.',

      child: Column(

        children: [

          _field(

            controller: _headlineController,

            label: 'Professional Headline',

            hint: 'e.g. Flutter Developer | Firebase | AI',

            icon: Icons.work_outline_rounded,

          ),

          const SizedBox(height: 16),

          _field(

            controller: _bioController,

            label: 'Professional Bio',

            hint:

                'Describe your experience, strengths and what you enjoy building...',

            icon: Icons.notes_rounded,

            maxLines: 5,

          ),

          const SizedBox(height: 16),

          _responsiveFields(

            isMobile,

            _field(

              controller: _locationController,

              label: 'Location',

              hint: 'e.g. Kolhapur, Maharashtra',

              icon: Icons.location_on_outlined,

            ),

            _field(

              controller: _photoUrlController,

              label: 'Profile Photo URL',

              hint: 'https://...',

              icon: Icons.photo_outlined,

            ),

          ),

        ],

      ),

    );

  }

  Widget _buildSkillsSection(bool isMobile) {

    return _section(

      icon: Icons.code_rounded,

      title: 'Skills & Technologies',

      subtitle:

          'Add skills that SkillBridge can use for project matching.',

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          _chipInput(

            controller: _skillController,

            hint: 'Add a skill e.g. Flutter',

            onAdd: _addSkill,

          ),

          const SizedBox(height: 14),

          _buildChips(

            _skills,

            onDelete: (skill) {

              setState(() {

                _skills.remove(skill);

                _hasChanges = true;

              });

            },

          ),

          const SizedBox(height: 22),

          _chipInput(

            controller: _technologyController,

            hint: 'Add technology e.g. Firebase',

            onAdd: _addTechnology,

          ),

          const SizedBox(height: 14),

          _buildChips(

            _technologies,

            onDelete: (technology) {

              setState(() {

                _technologies.remove(technology);

                _hasChanges = true;

              });

            },

          ),

        ],

      ),

    );

  }

  Widget _buildProfessionalSection(bool isMobile) {

    return _section(

      icon: Icons.workspace_premium_outlined,

      title: 'Professional Experience',

      subtitle:

          'Help clients understand your background and expertise.',

      child: Column(

        children: [

          _field(

            controller: _experienceController,

            label: 'Experience',

            hint:

                'e.g. 2 years Flutter development, freelance projects...',

            icon: Icons.timeline_rounded,

            maxLines: 4,

          ),

          const SizedBox(height: 16),

          _field(

            controller: _educationController,

            label: 'Education',

            hint:

                'e.g. B.Tech Computer Science & Engineering',

            icon: Icons.school_outlined,

            maxLines: 3,

          ),

        ],

      ),

    );

  }

  Widget _buildPreferencesSection(bool isMobile) {

    return _section(

      icon: Icons.tune_rounded,

      title: 'Work Preferences',

      subtitle:

          'These preferences help SkillBridge find suitable projects.',

      child: Column(

        children: [

          _responsiveFields(

            isMobile,

            _dropdown(

              label: 'Availability',

              value: _availability,

              values: const [

                'Available',

                'Part-time',

                'Busy',

                'Unavailable',

              ],

              onChanged: (value) {

                setState(() {

                  _availability = value!;

                  _hasChanges = true;

                });

              },

            ),

            _dropdown(

              label: 'Work Mode',

              value: _workMode,

              values: const [

                'Remote',

                'Hybrid',

                'On-site',

              ],

              onChanged: (value) {

                setState(() {

                  _workMode = value!;

                  _hasChanges = true;

                });

              },

            ),

          ),

          const SizedBox(height: 16),

          _responsiveFields(

            isMobile,

            _dropdown(

              label: 'Project Type',

              value: _projectType,

              values: const [

                'Both',

                'Short-term',

                'Long-term',

                'Freelance',

              ],

              onChanged: (value) {

                setState(() {

                  _projectType = value!;

                  _hasChanges = true;

                });

              },

            ),

            _dropdown(

              label: 'Project Duration',

              value: _projectDuration,

              values: const [

                'Flexible',

                'Less than 1 month',

                '1–3 months',

                '3–6 months',

                '6+ months',

              ],

              onChanged: (value) {

                setState(() {

                  _projectDuration = value!;

                  _hasChanges = true;

                });

              },

            ),

          ),

          const SizedBox(height: 22),

          _buildHoursSlider(),

          const SizedBox(height: 20),

          _field(

            controller: _rateController,

            label: 'Expected Hourly Rate',

            hint: 'e.g. ₹500 / hour',

            icon: Icons.currency_rupee_rounded,

          ),

        ],

      ),

    );

  }

  Widget _buildHoursSlider() {

    return Container(

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: const Color(0xFFF8FAFC),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(

          color: const Color(0xFFE5E7EB),

        ),

      ),

      child: Column(

        children: [

          Row(

            children: [

              const Icon(

                Icons.schedule_rounded,

                color: Color(0xFF4F46E5),

              ),

              const SizedBox(width: 10),

              const Expanded(

                child: Text(

                  'Available Hours Per Week',

                  style: TextStyle(

                    fontWeight: FontWeight.w800,

                  ),

                ),

              ),

              Text(

                '$_hoursPerWeek hrs',

                style: const TextStyle(

                  fontWeight: FontWeight.w900,

                  color: Color(0xFF4F46E5),

                ),

              ),

            ],

          ),

          Slider(

            value: _hoursPerWeek.toDouble(),

            min: 5,

            max: 60,

            divisions: 11,

            onChanged: (value) {

              setState(() {

                _hoursPerWeek = value.round();

                _hasChanges = true;

              });

            },

          ),

        ],

      ),

    );

  }

  Widget _buildLinksSection(bool isMobile) {

    return _section(

      icon: Icons.link_rounded,

      title: 'Professional Links',

      subtitle:

          'Connect your professional presence and portfolio.',

      child: Column(

        children: [

          _responsiveFields(

            isMobile,

            _field(

              controller: _githubController,

              label: 'GitHub',

              hint: 'https://github.com/username',

              icon: Icons.code_rounded,

            ),

            _field(

              controller: _linkedinController,

              label: 'LinkedIn',

              hint: 'https://linkedin.com/in/username',

              icon: Icons.business_center_outlined,

            ),

          ),

          const SizedBox(height: 16),

          _responsiveFields(

            isMobile,

            _field(

              controller: _portfolioController,

              label: 'Portfolio Website',

              hint: 'https://yourportfolio.com',

              icon: Icons.language_rounded,

            ),

            _field(

              controller: _resumeController,

              label: 'Resume URL',

              hint: 'https://...',

              icon: Icons.description_outlined,

            ),

          ),

        ],

      ),

    );

  }

  Widget _buildLanguagesSection(bool isMobile) {

    return _section(

      icon: Icons.translate_rounded,

      title: 'Languages',

      subtitle:

          'Languages you can use while communicating with clients.',

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          _buildChips(

            _languages,

            onDelete: (language) {

              if (_languages.length <= 1) return;

              setState(() {

                _languages.remove(language);

                _hasChanges = true;

              });

            },

          ),

          const SizedBox(height: 16),

          Wrap(

            spacing: 8,

            runSpacing: 8,

            children: [

              'English',

              'Hindi',

              'Marathi',

              'Gujarati',

              'Tamil',

              'Telugu',

            ].map(

              (language) {

                return OutlinedButton.icon(

                  onPressed: () {

                    _addLanguage(language);

                  },

                  icon: const Icon(

                    Icons.add,

                    size: 16,

                  ),

                  label: Text(language),

                );

              },

            ).toList(),

          ),

        ],

      ),

    );

  }

  Widget _buildPrivacySection() {

    return _section(

      icon: Icons.security_outlined,

      title: 'Profile Visibility',

      subtitle:

          'Control how clients and other developers discover you.',

      child: Column(

        children: [

          SwitchListTile.adaptive(

            contentPadding: EdgeInsets.zero,

            title: const Text(

              'Show my profile to clients',

              style: TextStyle(

                fontWeight: FontWeight.w700,

              ),

            ),

            subtitle: const Text(

              'Allow your profile to appear in developer search and project matching.',

            ),

            value: _profileVisible,

            onChanged: (value) {

              setState(() {

                _profileVisible = value;

                _hasChanges = true;

              });

            },

          ),

          const Divider(height: 28),

          SwitchListTile.adaptive(

            contentPadding: EdgeInsets.zero,

            title: const Text(

              'Open to team projects',

              style: TextStyle(

                fontWeight: FontWeight.w700,

              ),

            ),

            subtitle: const Text(

              'Allow other developers to invite you to collaborative projects.',

            ),

            value: _openToTeams,

            onChanged: (value) {

              setState(() {

                _openToTeams = value;

                _hasChanges = true;

              });

            },

          ),

        ],

      ),

    );

  }

  Widget _section({

    required IconData icon,

    required String title,

    required String subtitle,

    required Widget child,

  }) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(22),

        border: Border.all(

          color: const Color(0xFFE5E7EB),

        ),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity(.025),

            blurRadius: 20,

            offset: const Offset(0, 8),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Container(

                padding: const EdgeInsets.all(11),

                decoration: BoxDecoration(

                  color: const Color(0xFFEEF2FF),

                  borderRadius: BorderRadius.circular(13),

                ),

                child: Icon(

                  icon,

                  color: const Color(0xFF4F46E5),

                  size: 21,

                ),

              ),

              const SizedBox(width: 14),

              Expanded(

                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,

                  children: [

                    Text(

                      title,

                      style: const TextStyle(

                        fontSize: 18,

                        fontWeight: FontWeight.w900,

                        color: Color(0xFF111827),

                      ),

                    ),

                    const SizedBox(height: 4),

                    Text(

                      subtitle,

                      style: const TextStyle(

                        fontSize: 13,

                        color: Color(0xFF6B7280),

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

          const SizedBox(height: 24),

          child,

        ],

      ),

    );

  }

  Widget _field({

    required TextEditingController controller,

    required String label,

    required String hint,

    required IconData icon,

    int maxLines = 1,

  }) {

    return TextFormField(

      controller: controller,

      maxLines: maxLines,

      validator: (value) {

        if (label == 'Professional Headline' &&

            (value == null || value.trim().isEmpty)) {

          return 'Please add a professional headline';

        }

        return null;

      },

      decoration: InputDecoration(

        labelText: label,

        hintText: hint,

        prefixIcon: Padding(

          padding: EdgeInsets.only(

            top: maxLines > 1 ? 12 : 0,

          ),

          child: Icon(icon),

        ),

        alignLabelWithHint: maxLines > 1,

        filled: true,

        fillColor: const Color(0xFFF8FAFC),

        border: OutlineInputBorder(

          borderRadius: BorderRadius.circular(15),

          borderSide: const BorderSide(

            color: Color(0xFFE5E7EB),

          ),

        ),

        enabledBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(15),

          borderSide: const BorderSide(

            color: Color(0xFFE5E7EB),

          ),

        ),

        focusedBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(15),

          borderSide: const BorderSide(

            color: Color(0xFF6366F1),

            width: 2,

          ),

        ),

      ),

    );

  }

  Widget _dropdown({

    required String label,

    required String value,

    required List<String> values,

    required ValueChanged<String?> onChanged,

  }) {

    return DropdownButtonFormField<String>(

      value: value,

      decoration: InputDecoration(

        labelText: label,

        filled: true,

        fillColor: const Color(0xFFF8FAFC),

        border: OutlineInputBorder(

          borderRadius: BorderRadius.circular(15),

          borderSide: const BorderSide(

            color: Color(0xFFE5E7EB),

          ),

        ),

        enabledBorder: OutlineInputBorder(

          borderRadius: BorderRadius.circular(15),

          borderSide: const BorderSide(

            color: Color(0xFFE5E7EB),

          ),

        ),

      ),

      items: values.map(

        (item) {

          return DropdownMenuItem(

            value: item,

            child: Text(item),

          );

        },

      ).toList(),

      onChanged: onChanged,

    );

  }

  Widget _chipInput({

    required TextEditingController controller,

    required String hint,

    required VoidCallback onAdd,

  }) {

    return Row(

      children: [

        Expanded(

          child: TextField(

            controller: controller,

            onSubmitted: (_) => onAdd(),

            decoration: InputDecoration(

              hintText: hint,

              prefixIcon: const Icon(

                Icons.add_circle_outline_rounded,

              ),

              filled: true,

              fillColor: const Color(0xFFF8FAFC),

              border: OutlineInputBorder(

                borderRadius: BorderRadius.circular(15),

                borderSide: const BorderSide(

                  color: Color(0xFFE5E7EB),

                ),

              ),

              enabledBorder: OutlineInputBorder(

                borderRadius: BorderRadius.circular(15),

                borderSide: const BorderSide(

                  color: Color(0xFFE5E7EB),

                ),

              ),

            ),

          ),

        ),

        const SizedBox(width: 10),

        SizedBox(

          height: 54,

          child: FilledButton(

            onPressed: onAdd,

            style: FilledButton.styleFrom(

              backgroundColor: const Color(0xFF4F46E5),

              shape: RoundedRectangleBorder(

                borderRadius: BorderRadius.circular(14),

              ),

            ),

            child: const Icon(Icons.add),

          ),

        ),

      ],

    );

  }

  Widget _buildChips(

    List<String> items, {

    required Function(String) onDelete,

  }) {

    if (items.isEmpty) {

      return Container(

        width: double.infinity,

        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(

          color: const Color(0xFFF8FAFC),

          borderRadius: BorderRadius.circular(14),

        ),

        child: const Text(

          'Nothing added yet. Add some items above.',

          style: TextStyle(

            color: Color(0xFF6B7280),

          ),

        ),

      );

    }

    return Wrap(

      spacing: 9,

      runSpacing: 9,

      children: items.map(

        (item) {

          return Container(

            padding: const EdgeInsets.only(

              left: 13,

              right: 6,

              top: 7,

              bottom: 7,

            ),

            decoration: BoxDecoration(

              color: const Color(0xFFEEF2FF),

              borderRadius: BorderRadius.circular(30),

              border: Border.all(

                color: const Color(0xFFC7D2FE),

              ),

            ),

            child: Row(

              mainAxisSize: MainAxisSize.min,

              children: [

                Text(

                  item,

                  style: const TextStyle(

                    color: Color(0xFF3730A3),

                    fontWeight: FontWeight.w700,

                    fontSize: 13,

                  ),

                ),

                const SizedBox(width: 4),

                InkWell(

                  onTap: () => onDelete(item),

                  borderRadius: BorderRadius.circular(20),

                  child: const Padding(

                    padding: EdgeInsets.all(3),

                    child: Icon(

                      Icons.close_rounded,

                      size: 16,

                      color: Color(0xFF6366F1),

                    ),

                  ),

                ),

              ],

            ),

          );

        },

      ).toList(),

    );

  }

  Widget _responsiveFields(

    bool isMobile,

    Widget first,

    Widget second,

  ) {

    if (isMobile) {

      return Column(

        children: [

          first,

          const SizedBox(height: 16),

          second,

        ],

      );

    }

    return Row(

      children: [

        Expanded(child: first),

        const SizedBox(width: 16),

        Expanded(child: second),

      ],

    );

  }

  Widget _buildSaveBar(bool isMobile) {

    return Positioned(

      left: 0,

      right: 0,

      bottom: 0,

      child: SafeArea(

        child: Container(

          padding: EdgeInsets.symmetric(

            horizontal: isMobile ? 16 : 32,

            vertical: 13,

          ),

          decoration: BoxDecoration(

            color: Colors.white.withOpacity(.97),

            border: const Border(

              top: BorderSide(

                color: Color(0xFFE5E7EB),

              ),

            ),

            boxShadow: [

              BoxShadow(

                color: Colors.black.withOpacity(.08),

                blurRadius: 20,

                offset: const Offset(0, -5),

              ),

            ],

          ),

          child: Center(

            child: ConstrainedBox(

              constraints: const BoxConstraints(

                maxWidth: 1180,

              ),

              child: Row(

                children: [

                  const Icon(

                    Icons.edit_rounded,

                    color: Color(0xFFD97706),

                    size: 19,

                  ),

                  const SizedBox(width: 9),

                  if (!isMobile)

                    const Expanded(

                      child: Text(

                        'You have unsaved changes',

                        style: TextStyle(

                          fontWeight: FontWeight.w700,

                        ),

                      ),

                    )

                  else

                    const Spacer(),

                  TextButton(

                    onPressed: () {

                      _loadProfile();

                    },

                    child: const Text('Discard'),

                  ),

                  const SizedBox(width: 8),

                  FilledButton.icon(

                    onPressed: _saving ? null : _saveProfile,

                    icon: _saving

                        ? const SizedBox(

                            width: 16,

                            height: 16,

                            child: CircularProgressIndicator(

                              strokeWidth: 2,

                              color: Colors.white,

                            ),

                          )

                        : const Icon(

                            Icons.save_rounded,

                            size: 18,

                          ),

                    label: Text(

                      _saving ? 'Saving...' : 'Save Profile',

                    ),

                    style: FilledButton.styleFrom(

                      backgroundColor:

                          const Color(0xFF4F46E5),

                      padding: const EdgeInsets.symmetric(

                        horizontal: 20,

                        vertical: 14,

                      ),

                      shape: RoundedRectangleBorder(

                        borderRadius: BorderRadius.circular(13),

                      ),

                    ),

                  ),

                ],

              ),

            ),

          ),

        ),

      ),

    );

  }

  Future<bool> _showDiscardDialog() async {

    final result = await showDialog<bool>(

      context: context,

      builder: (context) {

        return AlertDialog(

          title: const Text(

            'Discard changes?',

            style: TextStyle(

              fontWeight: FontWeight.w800,

            ),

          ),

          content: const Text(

            'You have unsaved profile changes. Are you sure you want to leave?',

          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(context, false);

              },

              child: const Text('Stay'),

            ),

            FilledButton(

              onPressed: () {

                Navigator.pop(context, true);

              },

              child: const Text('Discard'),

            ),

          ],

        );

      },

    );

    return result ?? false;

  }

}
