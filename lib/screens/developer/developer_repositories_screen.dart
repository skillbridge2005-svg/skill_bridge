import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/developer_repository.dart';
import '../../services/developer_repository_service.dart';

class DeveloperRepositoriesScreen extends StatefulWidget {
  const DeveloperRepositoriesScreen({super.key});

  @override
  State<DeveloperRepositoriesScreen> createState() =>
      _DeveloperRepositoriesScreenState();
}

class _DeveloperRepositoriesScreenState
    extends State<DeveloperRepositoriesScreen> {
  final DeveloperRepositoryService _repositoryService =
      DeveloperRepositoryService();

  static const Color _primary = Color(0xFF2563EB);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _background = Color(0xFFF5F7FC);
  static const Color _border = Color(0xFFE5EAF3);
  static const Color _purple = Color(0xFF7C3AED);
  static const Color _green = Color(0xFF059669);
  static const Color _cyan = Color(0xFF06B6D4);

  String _searchQuery = '';

  // ============================================================
  // ADD / EDIT REPOSITORY
  // ============================================================

  Future<void> _showRepositoryDialog({DeveloperRepository? repository}) async {
    final formKey = GlobalKey<FormState>();

    final nameController = TextEditingController(text: repository?.name ?? '');

    final urlController = TextEditingController(text: repository?.url ?? '');

    final descriptionController = TextEditingController(
      text: repository?.description ?? '',
    );

    final technologiesController = TextEditingController(
      text: repository?.technologies.join(', ') ?? '',
    );

    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Dialog(
                backgroundColor: Colors.white,
                insetPadding: const EdgeInsets.all(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Dialog heading
                          Row(
                            children: [
                              Container(
                                height: 54,
                                width: 54,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [_dark, Color(0xFF334155)],
                                  ),
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: const Icon(
                                  Icons.code_rounded,
                                  color: Colors.white,
                                  size: 29,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      repository == null
                                          ? 'Add a repository'
                                          : 'Edit repository',
                                      style: const TextStyle(
                                        color: _dark,
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'Showcase your development work.',
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Close',
                                onPressed: saving
                                    ? null
                                    : () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),

                          const SizedBox(height: 27),

                          _fieldLabel('Repository name'),
                          const SizedBox(height: 9),
                          TextFormField(
                            controller: nameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: _inputDecoration(
                              hint: 'e.g. SkillBridge',
                              icon: Icons.folder_outlined,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a repository name.';
                              }

                              if (value.trim().length > 100) {
                                return 'Keep the name under 100 characters.';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          _fieldLabel('GitHub repository URL'),
                          const SizedBox(height: 9),
                          TextFormField(
                            controller: urlController,
                            keyboardType: TextInputType.url,
                            decoration: _inputDecoration(
                              hint: 'https://github.com/user/project',
                              icon: Icons.link_rounded,
                            ),
                            validator: _validateGitHubUrl,
                          ),

                          const SizedBox(height: 20),

                          _fieldLabel('About this project'),
                          const SizedBox(height: 9),
                          TextFormField(
                            controller: descriptionController,
                            maxLines: 4,
                            maxLength: 500,
                            decoration: _inputDecoration(
                              hint: 'What does your project do?',
                              icon: Icons.description_outlined,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _fieldLabel('Technologies used'),
                          const SizedBox(height: 9),
                          TextFormField(
                            controller: technologiesController,
                            decoration:
                                _inputDecoration(
                                  hint: 'Java, Flutter, Firebase',
                                  icon: Icons.terminal_rounded,
                                ).copyWith(
                                  helperText:
                                      'Separate technologies with commas.',
                                  helperStyle: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                  ),
                                ),
                          ),

                          const SizedBox(height: 27),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: saving
                                      ? null
                                      : () => Navigator.pop(dialogContext),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _dark,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    side: const BorderSide(color: _border),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: saving
                                      ? null
                                      : () async {
                                          if (!formKey.currentState!
                                              .validate()) {
                                            return;
                                          }

                                          setDialogState(() {
                                            saving = true;
                                          });

                                          final technologies =
                                              technologiesController.text
                                                  .split(',')
                                                  .map((value) => value.trim())
                                                  .where(
                                                    (value) => value.isNotEmpty,
                                                  )
                                                  .toSet()
                                                  .toList();

                                          try {
                                            if (repository == null) {
                                              await _repositoryService
                                                  .createRepository(
                                                    name: nameController.text
                                                        .trim(),
                                                    url: urlController.text
                                                        .trim(),
                                                    description:
                                                        descriptionController
                                                            .text
                                                            .trim(),
                                                    technologies: technologies,
                                                  );
                                            } else {
                                              await _repositoryService
                                                  .updateRepository(
                                                    repositoryId: repository.id,
                                                    name: nameController.text
                                                        .trim(),
                                                    url: urlController.text
                                                        .trim(),
                                                    description:
                                                        descriptionController
                                                            .text
                                                            .trim(),
                                                    technologies: technologies,
                                                  );
                                            }

                                            if (!dialogContext.mounted) return;

                                            Navigator.pop(dialogContext);

                                            if (mounted) {
                                              _showMessage(
                                                repository == null
                                                    ? 'Repository added successfully!'
                                                    : 'Repository updated successfully!',
                                                success: true,
                                              );
                                            }
                                          } catch (error) {
                                            if (!dialogContext.mounted) {
                                              return;
                                            }

                                            setDialogState(() {
                                              saving = false;
                                            });

                                            ScaffoldMessenger.of(
                                              dialogContext,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Unable to save repository: $error',
                                                ),
                                                backgroundColor:
                                                    Colors.red.shade700,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                  icon: saving
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.check_rounded),
                                  label: Text(
                                    saving ? 'Saving...' : 'Save project',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      urlController.dispose();
      descriptionController.dispose();
      technologiesController.dispose();
    }
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: _dark,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: Icon(icon, color: _muted, size: 21),
      filled: true,
      fillColor: _background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  String? _validateGitHubUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter the GitHub repository URL.';
    }

    final uri = Uri.tryParse(value.trim());

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'github.com' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment) {
      return 'Enter a valid HTTPS GitHub repository URL.';
    }

    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();

    if (segments.length != 2 ||
        segments.any(
          (segment) =>
              segment == '.' || segment == '..' || segment.contains('\\'),
        )) {
      return 'Use the format github.com/username/repository.';
    }

    return null;
  }

  // ============================================================
  // OPEN REPOSITORY
  // ============================================================

  Future<void> _openRepository(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null || _validateGitHubUrl(url) != null) {
      _showMessage('This repository URL is invalid.');
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

      if (!opened && mounted) {
        _showMessage('Could not open the GitHub repository.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Unable to open repository: $error');
      }
    }
  }

  // ============================================================
  // DELETE REPOSITORY
  // ============================================================

  Future<void> _deleteRepository(DeveloperRepository repository) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.red,
              size: 30,
            ),
          ),
          title: const Text(
            'Delete repository?',
            textAlign: TextAlign.center,
            style: TextStyle(color: _dark, fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Are you sure you want to delete "${repository.name}"? '
            'This action cannot be undone.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.6),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep it'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _repositoryService.deleteRepository(repository.id);

      if (mounted) {
        _showMessage('Repository deleted successfully.', success: true);
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Unable to delete repository: $error');
      }
    }
  }

  void _showMessage(String message, {bool success = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                success
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: success ? _green : _dark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  // ============================================================
  // MAIN SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: StreamBuilder<List<DeveloperRepository>>(
          stream: _repositoryService.watchRepositories(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _statusView(
                icon: Icons.cloud_off_rounded,
                title: 'Unable to load repositories',
                message: 'Please check your internet connection and try again.',
                actionLabel: 'Retry',
                onAction: () => setState(() {}),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _primary),
              );
            }

            final repositories = snapshot.data ?? [];

            return LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 650;
                final padding = isMobile ? 18.0 : 34.0;

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    padding,
                    isMobile ? 18 : 30,
                    padding,
                    40,
                  ),
                  children: [
                    _buildTopBar(isMobile),
                    const SizedBox(height: 25),
                    _buildHero(isMobile),
                    const SizedBox(height: 25),
                    _buildQuickTip(),
                    const SizedBox(height: 27),
                    _buildRepositoryContent(repositories, isMobile: isMobile),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar(bool isMobile) {
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: _dark.withValues(alpha: 0.035),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.code_rounded, color: _primary, size: 26),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Developer Studio',
                style: TextStyle(
                  color: _dark,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                isMobile
                    ? 'Your coding portfolio'
                    : 'YOUR WORKSPACE  /  PORTFOLIO',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFD1FAE5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: _green),
              SizedBox(width: 7),
              Text(
                'Portfolio',
                style: TextStyle(
                  color: _green,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CREATIVE HERO
  // ============================================================

  Widget _buildHero(bool isMobile) {
    return Container(
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B1224), Color(0xFF172554), Color(0xFF1D4ED8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.17),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative background circles
          Positioned(
            right: -65,
            top: -95,
            child: Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.5,
                ),
              ),
            ),
          ),
          Positioned(
            right: -20,
            bottom: -115,
            child: Container(
              height: 250,
              width: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.06),
                  width: 35,
                ),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.all(isMobile ? 23 : 37),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF93C5FD),
                        size: 15,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'YOUR DEVELOPER PORTFOLIO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Your code.\n'),
                      TextSpan(
                        text: 'Your creativity.',
                        style: TextStyle(
                          color: const Color(0xFF93C5FD),
                          shadows: [
                            Shadow(
                              color: _cyan.withValues(alpha: 0.20),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 32 : 45,
                    height: 1.12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.6,
                  ),
                ),

                const SizedBox(height: 15),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 490),
                  child: Text(
                    'Turn your best work into your professional identity. '
                    'Show clients and collaborators what you can build.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.76),
                      fontSize: 14,
                      height: 1.8,
                    ),
                  ),
                ),

                const SizedBox(height: 26),

                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _showRepositoryDialog(),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _dark,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 21),
                      label: const Text(
                        'Add a Repository',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.verified_outlined,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Showcase your skills',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // Decorative code-editor panel
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 450),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF080F20).withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _windowDot(const Color(0xFFF87171)),
                          const SizedBox(width: 6),
                          _windowDot(const Color(0xFFFBBF24)),
                          const SizedBox(width: 6),
                          _windowDot(const Color(0xFF34D399)),
                          const SizedBox(width: 12),
                          Text(
                            'developer_portfolio.dart',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _codeLine(
                        'const',
                        ' developer = ',
                        '"creative";',
                        const Color(0xFFC4B5FD),
                      ),
                      const SizedBox(height: 7),
                      _codeLine(
                        'final',
                        ' projects = ',
                        'yourBestWork;',
                        const Color(0xFF93C5FD),
                      ),
                      const SizedBox(height: 7),
                      _codeLine(
                        'return',
                        ' ',
                        'buildSomethingAmazing();',
                        const Color(0xFF6EE7B7),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _windowDot(Color color) {
    return Container(
      height: 8,
      width: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _codeLine(
    String first,
    String second,
    String third,
    Color firstColor,
  ) {
    return Wrap(
      children: [
        Text(
          first,
          style: TextStyle(
            color: firstColor,
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          second,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          third,
          style: const TextStyle(
            color: Color(0xFFFDE68A),
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  // ============================================================
  // QUICK TIP
  // ============================================================

  Widget _buildQuickTip() {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFDBEAFE)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: _primary, size: 23),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Portfolio tip',
                  style: TextStyle(
                    color: Color(0xFF1E40AF),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Add a clear description and your main technologies '
                  'to help people understand your work at a glance.',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REPOSITORY CONTENT
  // ============================================================

  Widget _buildRepositoryContent(
    List<DeveloperRepository> allRepositories, {
    required bool isMobile,
  }) {
    final query = _searchQuery.trim().toLowerCase();

    final repositories = allRepositories.where((repository) {
      return query.isEmpty ||
          repository.name.toLowerCase().contains(query) ||
          repository.description.toLowerCase().contains(query) ||
          repository.url.toLowerCase().contains(query) ||
          repository.technologies.any(
            (technology) => technology.toLowerCase().contains(query),
          );
    }).toList();

    final technologyCount = allRepositories
        .expand((repository) => repository.technologies)
        .map((technology) => technology.toLowerCase())
        .toSet()
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStats(
          repositoryCount: allRepositories.length,
          technologyCount: technologyCount,
          isMobile: isMobile,
        ),

        const SizedBox(height: 32),

        // Section heading
        Row(
          children: [
            Container(
              height: 43,
              width: 43,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _border),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: _primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Projects',
                    style: TextStyle(
                      color: _dark,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'A collection of your development work',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                '${repositories.length} ${repositories.length == 1 ? 'item' : 'items'}',
                style: const TextStyle(
                  color: _dark,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Search field
        TextField(
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
          decoration: InputDecoration(
            hintText: 'Search projects, descriptions or technologies...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _muted,
              size: 22,
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    icon: const Icon(Icons.close_rounded),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
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
              borderSide: const BorderSide(color: _primary, width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 22),

        if (allRepositories.isEmpty)
          _emptyPortfolio()
        else if (repositories.isEmpty)
          _statusView(
            icon: Icons.search_off_rounded,
            title: 'No matching projects',
            message: 'Try another project name, description or technology.',
            actionLabel: 'Clear search',
            onAction: () {
              setState(() {
                _searchQuery = '';
              });
            },
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 20.0;

              final columns = constraints.maxWidth >= 1100
                  ? 3
                  : constraints.maxWidth >= 650
                  ? 2
                  : 1;

              final cardWidth =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: repositories.map((repository) {
                  return SizedBox(
                    width: cardWidth,
                    child: _repositoryCard(repository),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStats({
    required int repositoryCount,
    required int technologyCount,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 18 : 22,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _dark.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _statItem(
              icon: Icons.folder_copy_rounded,
              label: 'Repositories',
              value: '$repositoryCount',
              color: _primary,
              isMobile: isMobile,
            ),
          ),
          _statDivider(),
          Expanded(
            child: _statItem(
              icon: Icons.layers_rounded,
              label: 'Technologies',
              value: '$technologyCount',
              color: _purple,
              isMobile: isMobile,
            ),
          ),
          _statDivider(),
          Expanded(
            child: _statItem(
              icon: Icons.rocket_launch_rounded,
              label: 'Portfolio',
              value: repositoryCount == 0 ? 'Start' : 'Active',
              color: _green,
              isMobile: isMobile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isMobile,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: isMobile ? 38 : 46,
          width: isMobile ? 38 : 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: isMobile ? 20 : 24),
        ),
        SizedBox(height: isMobile ? 9 : 12),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _dark,
            fontSize: isMobile ? 17 : 23,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _muted,
            fontSize: isMobile ? 9 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _statDivider() {
    return Container(
      height: 75,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: _border,
    );
  }

  // ============================================================
  // REPOSITORY CARD
  // ============================================================

  Widget _repositoryCard(DeveloperRepository repository) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _dark.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient accent
          Container(
            height: 5,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_primary, _purple, _cyan]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(21),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Repository header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 51,
                      width: 51,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF334155)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _dark.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.code_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              repository.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _dark,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                height: 1.3,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Row(
                              children: [
                                Icon(
                                  Icons.public_rounded,
                                  color: _muted,
                                  size: 13,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'GitHub repository',
                                  style: TextStyle(
                                    color: _muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    PopupMenuButton<String>(
                      tooltip: 'Repository options',
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_horiz_rounded, color: _muted),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showRepositoryDialog(repository: repository);
                        } else if (value == 'delete') {
                          _deleteRepository(repository);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 19),
                              SizedBox(width: 10),
                              Text('Edit repository'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.red,
                                size: 19,
                              ),
                              SizedBox(width: 10),
                              Text('Delete repository'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 21),

                // Description
                Text(
                  repository.description.trim().isEmpty
                      ? 'Add a description to tell people what makes this project special.'
                      : repository.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: repository.description.trim().isEmpty
                        ? const Color(0xFF94A3B8)
                        : _muted,
                    fontSize: 12.5,
                    height: 1.8,
                    fontStyle: repository.description.trim().isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),

                const SizedBox(height: 20),

                const Divider(color: _border, height: 1),

                const SizedBox(height: 18),

                // Technologies heading
                const Row(
                  children: [
                    Icon(Icons.terminal_rounded, color: _primary, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'BUILT WITH',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 13),

                if (repository.technologies.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _background,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Text(
                      'No technologies added yet',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 7,
                    runSpacing: 8,
                    children: repository.technologies.take(6).map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _primary.withValues(alpha: 0.065),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _primary.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Text(
                          item,
                          style: const TextStyle(
                            color: _primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                if (repository.technologies.length > 6) ...[
                  const SizedBox(height: 9),
                  Text(
                    '+${repository.technologies.length - 6} more technologies',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Open repository button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _openRepository(repository.url),
                    style: FilledButton.styleFrom(
                      backgroundColor: _dark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text(
                      'Explore Repository',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY PORTFOLIO
  // ============================================================

  Widget _emptyPortfolio() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            height: 94,
            width: 94,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primary.withValues(alpha: 0.09),
                  _purple.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: _primary,
              size: 43,
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Your next big thing starts here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _dark,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 10),

          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Text(
              'Your portfolio is waiting for its first project. '
              'Add a GitHub repository and start showing the world '
              'what you can build.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 13, height: 1.8),
            ),
          ),

          const SizedBox(height: 25),

          FilledButton.icon(
            onPressed: () => _showRepositoryDialog(),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add Your First Project',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REUSABLE STATUS VIEW
  // ============================================================

  Widget _statusView({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 38),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 78,
                width: 78,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(icon, color: _primary, size: 37),
              ),

              const SizedBox(height: 22),

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _dark,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                  height: 1.7,
                ),
              ),

              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
