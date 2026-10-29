import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'client_applications_screen.dart';
import 'client_messages_screen.dart' show ClientProjectChat;
import 'client_payments_screen.dart';
import 'client_team_screen.dart';
import 'project_details_screen.dart';
import '../../localization/app_localizations.dart';
import '../../services/notification_service.dart';

class ClientNotificationsScreen extends StatelessWidget {
  const ClientNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Center(
        child: Text(
          l10n.loginAgain,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final notificationService = NotificationService();

    return Container(
      color: const Color(0xFFF6F8FC),
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _NotificationAmbientPainter()),
            ),
          ),
          StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: notificationService.watchMyClientNotifications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: _NotificationLoader());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _NotificationErrorCard(
                      message:
                          '${l10n.unableToLoadMessages}\n${snapshot.error}',
                    ),
                  ),
                );
              }

              final notifications = (snapshot.data ?? [])
                  .where((document) => document.data()['isDismissed'] != true)
                  .toList();

              if (notifications.isEmpty) {
                return const _EmptyNotifications();
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _NotificationSectionHeading(),
                        const SizedBox(height: 18),
                        Column(
                          children: notifications.map((document) {
                            return Dismissible(
                              key: ValueKey('notification_${document.id}'),
                              direction: DismissDirection.horizontal,

                              background: _notificationDismissBackground(
                                Alignment.centerLeft,
                              ),

                              secondaryBackground:
                                  _notificationDismissBackground(
                                    Alignment.centerRight,
                                  ),

                              confirmDismiss: (_) async {
                                try {
                                  await notificationService
                                      .dismissMyClientNotification(document.id);

                                  return true;
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not dismiss notification: $error',
                                        ),
                                      ),
                                    );
                                  }

                                  return false;
                                }
                              },

                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _NotificationCard(
                                  notificationId: document.id,
                                  data: document.data(),
                                  userId: user.uid,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget _notificationDismissBackground(Alignment alignment) {
  return Container(
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: const Color(0xFFDC2626),
      borderRadius: BorderRadius.circular(21),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 25),
        SizedBox(width: 8),
        Text(
          'Dismiss',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _NotificationSectionHeading extends StatelessWidget {
  const _NotificationSectionHeading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.activity.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.25,
            color: Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.recentNotifications,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.latestWorkspaceUpdates,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String notificationId;
  final Map<String, dynamic> data;
  final String userId;

  const _NotificationCard({
    required this.notificationId,
    required this.data,
    required this.userId,
  });

  Future<void> _openNotification(BuildContext context) async {
    final notificationRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId);

    try {
      // Mark as read through NotificationService.
      // Keep the direct Firestore update as a fallback for compatibility.
      if (data['isRead'] != true) {
        try {
          await NotificationService().markMyClientNotificationAsRead(
            notificationId,
          );
        } catch (error) {
          debugPrint(
            'NotificationService could not mark notification as read: $error',
          );

          // Existing behavior retained as a fallback.
          try {
            await notificationRef.update({'isRead': true});
          } catch (fallbackError) {
            debugPrint('Could not mark notification as read: $fallbackError');
          }
        }
      }

      final type = (data['type'] ?? 'system').toString().trim().toLowerCase();

      var projectId = (data['projectId'] ?? '').toString().trim();

      final applicationId = (data['applicationId'] ?? '').toString().trim();

      var projectTitle = (data['projectTitle'] ?? '').toString().trim();

      // Some application notifications may contain only applicationId.
      if (projectId.isEmpty && applicationId.isNotEmpty) {
        final applicationSnapshot = await FirebaseFirestore.instance
            .collection('applications')
            .doc(applicationId)
            .get();

        projectId = (applicationSnapshot.data()?['projectId'] ?? '')
            .toString()
            .trim();
      }

      // Fetch the project title if the notification doesn't contain it.
      if (projectId.isNotEmpty && projectTitle.isEmpty) {
        final projectSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .get();

        projectTitle = (projectSnapshot.data()?['title'] ?? 'Project')
            .toString()
            .trim();
      }

      if (!context.mounted) return;

      switch (type) {
        case 'message':
        case 'chat':
        case 'project_message':
          if (projectId.isNotEmpty) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ClientProjectChat(
                  projectId: projectId,
                  projectTitle: projectTitle.isEmpty
                      ? 'Project Chat'
                      : projectTitle,
                ),
              ),
            );
            return;
          }
          break;

        case 'application':
        case 'new_application':
          if (projectId.isNotEmpty) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ClientApplicationsScreen(
                  projectId: projectId,
                  projectTitle: projectTitle.isEmpty ? 'Project' : projectTitle,
                ),
              ),
            );
            return;
          }
          break;

        case 'team':
        case 'team_invitation':
        case 'team_update':
        case 'project_team':
          if (projectId.isNotEmpty) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ClientTeamScreen(projectId: projectId),
              ),
            );
            return;
          }
          break;

        case 'payment':
        case 'payments':
        case 'payment_update':
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const ClientPaymentsScreen(),
            ),
          );
          return;

        case 'project':
        case 'status':
        case 'project_status':
        case 'project_update':
        case 'meeting':
        case 'meeting_invitation':
          if (projectId.isNotEmpty) {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProjectDetailsScreen(projectId: projectId),
              ),
            );
            return;
          }
          break;
      }

      // Fallback for any other project-related notification.
      if (!context.mounted) return;

      if (projectId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProjectDetailsScreen(projectId: projectId),
          ),
        );
        return;
      }
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This notification does not have a destination configured yet.',
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open notification: $error')),
        );
      }
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'application':
      case 'new_application':
        return Icons.assignment_outlined;

      case 'team_invitation':
      case 'team_update':
        return Icons.groups_outlined;

      case 'meeting':
      case 'meeting_invitation':
        return Icons.event_available_rounded;

      case 'project_status':
      case 'project_update':
        return Icons.update_rounded;

      case 'payment_update':
        return Icons.currency_rupee_rounded;
      case 'project':
        return Icons.work_outline_rounded;
      case 'message':
        return Icons.chat_bubble_outline_rounded;
      case 'team':
        return Icons.groups_outlined;
      case 'payment':
        return Icons.currency_rupee_rounded;
      case 'status':
        return Icons.update_rounded;
      case 'system':
        return Icons.info_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'project':
        return const Color(0xFF4F46E5);
      case 'message':
        return const Color(0xFF2563EB);
      case 'team':
        return const Color(0xFF7C3AED);
      case 'payment':
        return const Color(0xFF059669);
      case 'status':
        return const Color(0xFFD97706);
      case 'system':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF4F46E5);
    }
  }

  Color _getIconBackground(String type) {
    switch (type) {
      case 'payment':
        return const Color(0xFFECFDF3);
      case 'status':
        return const Color(0xFFFFF7E8);
      case 'team':
        return const Color(0xFFF5F3FF);
      case 'message':
        return const Color(0xFFEFF6FF);
      default:
        return const Color(0xFFEEF2FF);
    }
  }

  String _getTypeLabel(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context);

    switch (type) {
      case 'application':
      case 'new_application':
        return 'Application';

      case 'team_invitation':
      case 'team_update':
        return 'Team';

      case 'meeting':
      case 'meeting_invitation':
        return 'Meeting';

      case 'project_status':
      case 'project_update':
        return l10n.status;

      case 'payment_update':
        return l10n.payments;
      case 'project':
        return l10n.project;
      case 'message':
        return l10n.messages;
      case 'team':
        return l10n.team;
      case 'payment':
        return l10n.payments;
      case 'status':
        return l10n.status;
      default:
        return l10n.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final title = data['title']?.toString() ?? l10n.notifications;

    final message = (data['message'] ?? data['body'])?.toString() ?? '';

    final type = (data['type']?.toString() ?? 'system').trim().toLowerCase();

    final isRead = data['isRead'] == true;

    final typeLabel = _getTypeLabel(context, type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openNotification(context),
        borderRadius: BorderRadius.circular(21),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(
              color: isRead ? const Color(0xFFE5E7EB) : const Color(0xFFD9E2FF),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _getIconBackground(type),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _getIcon(type),
                  color: _getIconColor(type),
                  size: 23,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                              color: const Color(0xFF111827),
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            margin: const EdgeInsets.only(left: 8, top: 4),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4F46E5),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getIconBackground(type),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        typeLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.6,
                          color: _getIconColor(type),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _NotificationSectionHeading(),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 52,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x070F172A),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const _EmptyNotificationIcon(),
                    const SizedBox(height: 18),
                    Text(
                      l10n.noNotifications,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.latestWorkspaceUpdates,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotificationIcon extends StatelessWidget {
  const _EmptyNotificationIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(
        Icons.notifications_none_rounded,
        size: 34,
        color: Color(0xFF4F46E5),
      ),
    );
  }
}

class _NotificationLoader extends StatelessWidget {
  const _NotificationLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Color(0xFF4F46E5),
      ),
    );
  }
}

class _NotificationErrorCard extends StatelessWidget {
  final String message;

  const _NotificationErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1C2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationAmbientPainter extends CustomPainter {
  const _NotificationAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0x0B4F46E5);

    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.12),
      190,
      paint,
    );

    paint.color = const Color(0x087C3AED);

    canvas.drawCircle(
      Offset(size.width * 0.05, size.height * 0.78),
      155,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _NotificationAmbientPainter oldDelegate) {
    return false;
  }
}
