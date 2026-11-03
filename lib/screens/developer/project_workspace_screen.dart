import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WorkspaceMember {
  final String uid;
  final String name;
  final String email;
  final String photoUrl;

  WorkspaceMember({
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
  });
}

class ProjectWorkspaceScreen extends StatelessWidget {
  final String projectId;
  final String projectTitle;

  const ProjectWorkspaceScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  static const Color primary = Color(0xFF4F46E5);
  static const Color background = Color(0xFFF7F8FC);
  static const Color dark = Color(0xFF111827);
  static const Color muted = Color(0xFF64748B);

  CollectionReference<Map<String, dynamic>> get tasksCollection {
    return FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('tasks');
  }

  Future<List<WorkspaceMember>> _loadProjectMembers() async {
    final members = <WorkspaceMember>[];

    final teamSnapshot = await FirebaseFirestore.instance
        .collection('teams')
        .where('projectId', isEqualTo: projectId)
        .where('status', isEqualTo: 'active')
        .get();

    final memberIds = <String>{};

    for (final team in teamSnapshot.docs) {
      final ids = team.data()['memberIds'];

      if (ids is List) {
        memberIds.addAll(ids.map((e) => e.toString()));
      }
    }

    for (final uid in memberIds) {
      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userSnapshot.exists) continue;

      final user = userSnapshot.data() ?? {};

      members.add(
        WorkspaceMember(
          uid: uid,
          name: user['name'] ?? user['displayName'] ?? 'Developer',
          email: user['email'] ?? '',
          photoUrl: user['photoURL'] ?? '',
        ),
      );
    }

    return members;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Project Workspace',
          style: TextStyle(color: dark, fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .snapshots(),
        builder: (context, projectSnapshot) {
          if (projectSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primary),
            );
          }

          if (!projectSnapshot.hasData || !projectSnapshot.data!.exists) {
            return const Center(child: Text('Project not found.'));
          }

          final project = projectSnapshot.data!.data() ?? {};

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: tasksCollection
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, taskSnapshot) {
              if (taskSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primary),
                );
              }

              if (taskSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Unable to load tasks.\n${taskSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final tasks = taskSnapshot.data?.docs ?? [];

              final todo = tasks
                  .where((task) => task.data()['status'] == 'todo')
                  .length;

              final inProgress = tasks
                  .where((task) => task.data()['status'] == 'in_progress')
                  .length;

              final completed = tasks
                  .where((task) => task.data()['status'] == 'completed')
                  .length;

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _projectHeader(project),

                  const SizedBox(height: 22),

                  // Task Statistics
                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          'Total Tasks',
                          tasks.length.toString(),
                          Icons.task_alt_rounded,
                          primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          'Completed',
                          completed.toString(),
                          Icons.check_circle_outline_rounded,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _statCard(
                          'In Progress',
                          inProgress.toString(),
                          Icons.timelapse_rounded,
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statCard(
                          'To Do',
                          todo.toString(),
                          Icons.pending_actions_rounded,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // Workspace Actions
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Workspace Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: dark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create tasks and manage your project team work.',
                          style: TextStyle(color: muted, height: 1.5),
                        ),
                        const SizedBox(height: 18),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: currentUserId == null
                                ? null
                                : () {
                                    _showCreateTaskDialog(context);
                                  },
                            icon: const Icon(Icons.add_task_rounded),
                            label: const Text('Create New Task'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Task Board
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Project Tasks',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: dark,
                          ),
                        ),
                      ),
                      Text(
                        '${tasks.length} tasks',
                        style: const TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  if (tasks.isEmpty)
                    _emptyTasks()
                  else
                    ...tasks.map((task) {
                      final data = task.data();

                      return _taskCard(context, task.id, data);
                    }),

                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // PROJECT HEADER
  // ============================================================

  Widget _projectHeader(Map<String, dynamic> project) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.workspaces_rounded, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                'PROJECT WORKSPACE',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            projectTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Owner: ${project['developerName'] ?? 'Project Owner'}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 25),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: dark,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: muted, fontSize: 12)),
        ],
      ),
    );
  }

  // ============================================================
  // TASK CARD
  // ============================================================

  Widget _taskCard(
    BuildContext context,
    String taskId,
    Map<String, dynamic> task,
  ) {
    final status = task['status'] ?? 'todo';
    final priority = task['priority'] ?? 'medium';

    Color statusColor;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        break;
      case 'in_progress':
        statusColor = Colors.orange;
        break;
      case 'review':
        statusColor = Colors.purple;
        break;
      default:
        statusColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task['title'] ?? 'Untitled Task',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: dark,
                  ),
                ),
              ),
              _badge(status, statusColor),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            task['description'] ?? 'No description',
            style: const TextStyle(color: muted, height: 1.5),
          ),

          const SizedBox(height: 14),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(
                'Priority: $priority',
                priority == 'high' || priority == 'urgent'
                    ? Colors.red
                    : Colors.orange,
              ),
              _badge(
                'Assigned: ${task['assignedToName'] ?? 'Unassigned'}',
                primary,
              ),
            ],
          ),

          const SizedBox(height: 12),

          const Divider(),

          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 18, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Created by ${task['createdByName'] ?? 'Project Owner'}',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
              IconButton(
                tooltip: 'Reassign Task',
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: primary,
                ),
                onPressed: () async {
                  final members = await _loadProjectMembers();

                  if (context.mounted) {
                    _reassignTask(
                      context,
                      taskId,
                      members,
                    );
                  }
                },
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  tasksCollection.doc(taskId).update({
                    'status': value,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'todo', child: Text('To Do')),
                  PopupMenuItem(
                    value: 'in_progress',
                    child: Text('In Progress'),
                  ),
                  PopupMenuItem(value: 'review', child: Text('In Review')),
                  PopupMenuItem(value: 'completed', child: Text('Completed')),
                ],
                child: const Icon(Icons.more_vert_rounded, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY TASKS
  // ============================================================

  Widget _emptyTasks() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Column(
        children: [
          Icon(Icons.task_alt_rounded, size: 55, color: Color(0xFF9CA3AF)),
          SizedBox(height: 14),
          Text(
            'No tasks created yet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8),
          Text(
            'Create your first project task to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CREATE TASK
  // ============================================================

  Future<void> _showCreateTaskDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();

    String priority = 'medium';
    String? selectedDeveloperId;
    String? selectedDeveloperName;

    List<WorkspaceMember> projectMembers = [];

    bool loadingMembers = true;

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    try {
      projectMembers = await _loadProjectMembers();
      loadingMembers = false;
    } catch (_) {
      loadingMembers = false;
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Create Project Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Task Title',
                        hintText: 'Example: Create Login UI',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: descriptionController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Describe the task...',
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (loadingMembers)
                      const CircularProgressIndicator()
                    else
                      DropdownButtonFormField<String>(
                        initialValue: selectedDeveloperId,
                        decoration: const InputDecoration(
                          labelText: 'Assign Developer',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Unassigned'),
                          ),
                          ...projectMembers.map(
                            (member) => DropdownMenuItem<String>(
                              value: member.uid,
                              child: Text(member.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            selectedDeveloperId = value;

                            selectedDeveloperName = value == null
                                ? null
                                : projectMembers
                                      .firstWhere(
                                        (member) => member.uid == value,
                                      )
                                      .name;
                          });
                        },
                      ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(
                          value: 'urgent',
                          child: Text('Urgent'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => priority = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final description = descriptionController.text.trim();

                    if (title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter a task title.')),
                      );
                      return;
                    }

                    try {
                      await tasksCollection.add({
                        'projectId': projectId,
                        'title': title,
                        'description': description,
                        'assignedTo': selectedDeveloperId ?? '',
                        'assignedToName': selectedDeveloperName ?? 'Unassigned',
                        'createdBy': currentUser.uid,
                        'createdByName':
                            currentUser.displayName ?? 'Project Owner',
                        'priority': priority,
                        'status': 'todo',
                        'createdAt': FieldValue.serverTimestamp(),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Task created successfully.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Unable to create task: $error'),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
  }

  Future<void> _reassignTask(
    BuildContext context,
    String taskId,
    List<WorkspaceMember> members,
  ) async {
    String? selectedDeveloperId;
    String? selectedDeveloperName;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Reassign Task'),
              content: DropdownButtonFormField<String>(
                initialValue: selectedDeveloperId,
                decoration: const InputDecoration(
                  labelText: 'Select Developer',
                ),
                items: members.map((member) {
                  return DropdownMenuItem(
                    value: member.uid,
                    child: Text(member.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedDeveloperId = value;

                    selectedDeveloperName = members
                        .firstWhere((member) => member.uid == value)
                        .name;
                  });
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedDeveloperId == null) return;

                    await tasksCollection.doc(taskId).update({
                      'assignedTo': selectedDeveloperId,
                      'assignedToName': selectedDeveloperName,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
