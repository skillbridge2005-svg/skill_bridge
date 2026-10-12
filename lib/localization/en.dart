class EnglishTranslations {
  static const Map<String, String> translations = {
    'appName': 'SkillBridge',

    // Main
    'dashboard': 'Dashboard',
    'myProjects': 'My Projects',
    'messages': 'Messages',
    'notifications': 'Notifications',
    'myProfile': 'My Profile',
    'home': 'Home',
    'projects': 'Projects',
    'alerts': 'Alerts',
    'profile': 'Profile',
    'client': 'Client',

    // Workspace
    'skillBridgeWorkspace': 'SkillBridge Workspace',
    'selectLanguage': 'Select Language',
    'english': 'English',
    'marathi': 'Marathi',
    'hindi': 'Hindi',

    // Dashboard
    'welcomeBack': 'Welcome back',
    'createNewProject': 'Create a New Project',
    'shareIdea': 'Share your idea and requirements with SkillBridge.',
    'overview': 'OVERVIEW',
    'yourWorkspace': 'Your workspace',
    'projectActivity': 'A quick look at your project activity.',
    'totalProjects': 'Total Projects',
    'activeProjects': 'Active Projects',
    'completed': 'Completed',
    'recentProjects': 'Recent Projects',
    'latestProjectActivity': 'Your latest project activity.',
    'viewAll': 'View all',
    'noProjectsYet': 'No projects yet',
    'createFirstProject': 'Create your first project and it will appear here.',

    // Quick Actions
    'quickActions': 'QUICK ACTIONS',
    'continueWhereLeft': 'Continue where you left off',
    'jumpWorkspace': 'Jump directly to your workspace.',
    'openProjectWorkspace': 'Open your project workspace',
    'continueConversations': 'Continue your conversations',

    // Account
    'clientAccount': 'Client account',
    'logout': 'Logout',
    'settings': 'Settings',

    // Projects
    'project': 'Project',
    'projectsPlural': 'Projects',

    // AI Project Assistant
    'aiProjectAssistant': 'AI Project Assistant',
    'hireDeveloper': 'Hire Developer',
    'findDevelopers': 'Find Developers',
    'postProject': 'Post Project',
    'describeProject': 'Describe your project idea',
    'generateProject': 'Generate Project',
    'requiredSkill': 'Required Skill',
    'experience': 'Experience',
    'continueToPostProject': 'Continue to Post Project',

    // AI Generated Project
    'generatedProject': 'Generated Project',
    'projectTitle': 'Project Title',
    'projectDescription': 'Description',
    'exampleProjectIdea': 'Example: I need a website for my shop with product listing and online orders.',
    'generatedSkills': 'Required Skills',
    'projectGeneratedSuccessfully': 'Project generated successfully.',

    // Authentication
    'loginAgain': 'Please login again.',

    // Project Description
    'softwareProjectsDescription':
        'Everything for your software projects, in one place.',

    // Project Status
    'requirement': 'Requirement',
    'teamFormation': 'Team Formation',
    'development': 'Development',
    'testing': 'Testing',
    'clientReview': 'Client Review',
    'cancelled': 'Cancelled',

    // Client Home
    'workspaceOverview': 'Workspace Overview',
    'quickActionsDescription': 'Manage your projects and continue your work.',
    'createProject': 'Create Project',
    'createProjectDescription':
        'Share your idea and requirements with SkillBridge.',
    'totalProject': 'Total Project',
    'activeProject': 'Active Project',
    'completedProject': 'Completed Project',
    'recentProject': 'Recent Project',
    'noRecentProjects': 'No recent projects.',

    // Client Messages
    'conversations': 'CONVERSATIONS',
    'yourProjectChats': 'Your project chats',
    'openProjectConversation':
        'Open a project conversation to continue working together.',
    'noConversations': 'No conversations yet.',
    'noMessagesYet': 'No messages yet.',
    'noConversationsYet': 'No conversations yet.',
    'startConversation': 'Start a conversation about this project.',
    'typeMessage': 'Type a message...',
    'writeMessage': 'Write a message...',
    'send': 'Send',
    'projectConversation': 'Project conversation',
    'unableToLoadMessages': 'Unable to load messages.',
    'unableToLoadConversation': 'Unable to load conversation.',
    'unableToSendMessage': 'Unable to send message.',
    'somethingWentWrong': 'Something went wrong.',

    // Client Notifications
    'activity': 'ACTIVITY',
    'recentNotifications': 'Recent notifications',
    'latestWorkspaceUpdates':
        'Review the latest updates from your SkillBridge workspace.',
    'noNotifications': 'No notifications yet.',
    'markAsRead': 'Mark as read',

    // Client Payments
    'payments': 'Payments',
    'paymentHistory': 'Payment History',
    'paymentDetails': 'Payment Details',
    'advancePayment': 'Advance Payment',
    'finalPayment': 'Final Payment',
    'pending': 'Pending',
    'paid': 'Paid',
    'failed': 'Failed',
    'refunded': 'Refunded',
    'paymentCancelled': 'Cancelled',
    'noPayments': 'No payment records yet.',

    // Client Team
    'team': 'Team',
    'projectTeam': 'Project Team',
    'teamMembers': 'Team Members',
    'teamLeader': 'Team Leader',
    'frontendDeveloper': 'Frontend Developer',
    'backendDeveloper': 'Backend Developer',
    'databaseDeveloper': 'Database Developer',
    'tester': 'Tester',
    'noTeamMembers': 'No team members yet.',

    // Project Details
    'projectDetails': 'Project Details',
    'description': 'Description',
    'requirements': 'Requirements',
    'budget': 'Budget',
    'timeline': 'Timeline',
    'progress': 'Progress',
    'viewTeam': 'View Team',
    'openMessages': 'Open Messages',

    // Project
    'projectId': 'Project ID',
    'projectNotFound': 'Project not found.',
    'unableToLoadProject': 'Unable to load project.',

    // Common Actions
    'noData': 'No data available.',
    'yes': 'Yes',
    'no': 'No',
    'confirm': 'Confirm',
    'select': 'Select',
    'submit': 'Submit',
    'update': 'Update',

    // Common
    'loading': 'Loading...',
    'error': 'Something went wrong.',
    'retry': 'Retry',
    'cancel': 'Cancel',
    'save': 'Save',
    'edit': 'Edit',
    'delete': 'Delete',
    'close': 'Close',
    'back': 'Back',
    'next': 'Next',
    'continueText': 'Continue',
    'search': 'Search',
    'status': 'Status',
    'date': 'Date',
    'amount': 'Amount',
    'category': 'Category',
  };

  static String get(String key) {
    return translations[key] ?? key;
  }
}
