import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String get appName => _get('appName');
  String get dashboard => _get('dashboard');
  String get myProjects => _get('myProjects');
  String get messages => _get('messages');
  String get notifications => _get('notifications');
  String get myProfile => _get('myProfile');
  String get home => _get('home');
  String get projects => _get('projects');
  String get alerts => _get('alerts');
  String get profile => _get('profile');
  String get client => _get('client');

  String get skillBridgeWorkspace => _get('skillBridgeWorkspace');
  String get selectLanguage => _get('selectLanguage');
  String get english => _get('english');
  String get marathi => _get('marathi');
  String get hindi => _get('hindi');

  String get welcomeBack => _get('welcomeBack');
  String get createNewProject => _get('createNewProject');
  String get shareIdea => _get('shareIdea');

  String get overview => _get('overview');
  String get yourWorkspace => _get('yourWorkspace');
  String get projectActivity => _get('projectActivity');

  String get totalProjects => _get('totalProjects');
  String get activeProjects => _get('activeProjects');
  String get completed => _get('completed');

  String get recentProjects => _get('recentProjects');
  String get latestProjectActivity => _get('latestProjectActivity');
  String get viewAll => _get('viewAll');

  String get noProjectsYet => _get('noProjectsYet');
  String get createFirstProject => _get('createFirstProject');

  String get quickActions => _get('quickActions');
  String get continueWhereLeft => _get('continueWhereLeft');
  String get jumpWorkspace => _get('jumpWorkspace');
  String get openProjectWorkspace => _get('openProjectWorkspace');
  String get continueConversations => _get('continueConversations');

  String get clientAccount => _get('clientAccount');
  String get logout => _get('logout');
  String get settings => _get('settings');

  String get project => _get('project');
  String get projectsPlural => _get('projectsPlural');

  String get aiProjectAssistant => _get('aiProjectAssistant');
  String get hireDeveloper => _get('hireDeveloper');
  String get findDevelopers => _get('findDevelopers');
  String get postProject => _get('postProject');

  String get describeProject => _get('describeProject');
  String get generateProject => _get('generateProject');
  String get requiredSkill => _get('requiredSkill');
  String get experience => _get('experience');
  String get continueToPostProject => _get('continueToPostProject');

  String get loginAgain => _get('loginAgain');
  String get softwareProjectsDescription => _get('softwareProjectsDescription');

  String get requirement => _get('requirement');
  String get teamFormation => _get('teamFormation');
  String get development => _get('development');
  String get testing => _get('testing');
  String get clientReview => _get('clientReview');
  String get cancelled => _get('cancelled');

  // Client Home
  String get workspaceOverview => _get('workspaceOverview');
  String get quickActionsDescription => _get('quickActionsDescription');
  String get createProject => _get('createProject');
  String get createProjectDescription => _get('createProjectDescription');
  String get totalProject => _get('totalProject');
  String get activeProject => _get('activeProject');
  String get completedProject => _get('completedProject');
  String get recentProject => _get('recentProject');
  String get noRecentProjects => _get('noRecentProjects');

  // Client Messages
  String get conversations => _get('conversations');
  String get yourProjectChats => _get('yourProjectChats');
  String get openProjectConversation => _get('openProjectConversation');
  String get noConversations => _get('noConversations');
  String get noMessagesYet => _get('noMessagesYet');
  String get noConversationsYet => _get('noConversationsYet');
  String get startConversation => _get('startConversation');
  String get typeMessage => _get('typeMessage');
  String get writeMessage => _get('writeMessage');
  String get send => _get('send');
  String get projectConversation => _get('projectConversation');
  String get unableToLoadMessages => _get('unableToLoadMessages');
  String get unableToLoadConversation => _get('unableToLoadConversation');
  String get unableToSendMessage => _get('unableToSendMessage');
  String get somethingWentWrong => _get('somethingWentWrong');

  // Client Notifications
  String get activity => _get('activity');
  String get recentNotifications => _get('recentNotifications');
  String get latestWorkspaceUpdates => _get('latestWorkspaceUpdates');
  String get noNotifications => _get('noNotifications');
  String get markAsRead => _get('markAsRead');

  // Client Payments
  String get payments => _get('payments');
  String get paymentHistory => _get('paymentHistory');
  String get paymentDetails => _get('paymentDetails');
  String get advancePayment => _get('advancePayment');
  String get finalPayment => _get('finalPayment');
  String get pending => _get('pending');
  String get paid => _get('paid');
  String get failed => _get('failed');
  String get refunded => _get('refunded');
  String get paymentCancelled => _get('paymentCancelled');
  String get noPayments => _get('noPayments');

  // Client Team
  String get team => _get('team');
  String get projectTeam => _get('projectTeam');
  String get teamMembers => _get('teamMembers');
  String get teamLeader => _get('teamLeader');
  String get frontendDeveloper => _get('frontendDeveloper');
  String get backendDeveloper => _get('backendDeveloper');
  String get databaseDeveloper => _get('databaseDeveloper');
  String get tester => _get('tester');
  String get noTeamMembers => _get('noTeamMembers');

  // Project Details
  String get projectDetails => _get('projectDetails');
  String get description => _get('description');
  String get requirements => _get('requirements');
  String get budget => _get('budget');
  String get timeline => _get('timeline');
  String get progress => _get('progress');
  String get viewTeam => _get('viewTeam');
  String get openMessages => _get('openMessages');

  // AI Project Assistant
  String get generatedProject => _get('generatedProject');
  String get projectTitle => _get('projectTitle');
  String get projectDescription => _get('projectDescription');
  String get exampleProjectIdea => _get('exampleProjectIdea');
  String get generatedSkills => _get('generatedSkills');
  String get projectGeneratedSuccessfully =>
      _get('projectGeneratedSuccessfully');

  // Project
  String get projectId => _get('projectId');
  String get projectNotFound => _get('projectNotFound');
  String get unableToLoadProject => _get('unableToLoadProject');

  // Common Actions
  String get noData => _get('noData');
  String get yes => _get('yes');
  String get no => _get('no');
  String get confirm => _get('confirm');
  String get select => _get('select');
  String get submit => _get('submit');
  String get update => _get('update');

  // Common
  String get loading => _get('loading');
  String get error => _get('error');
  String get retry => _get('retry');
  String get cancel => _get('cancel');
  String get save => _get('save');
  String get edit => _get('edit');
  String get delete => _get('delete');
  String get close => _get('close');
  String get back => _get('back');
  String get next => _get('next');
  String get continueText => _get('continueText');
  String get search => _get('search');
  String get status => _get('status');
  String get date => _get('date');
  String get amount => _get('amount');
  String get category => _get('category');

  String _get(String key) {
    switch (locale.languageCode) {
      case 'mr':
        return MarathiTranslations.get(key);
      case 'hi':
        return HindiTranslations.get(key);
      default:
        return EnglishTranslations.get(key);
    }
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'mr', 'hi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) {
    return false;
  }
}

class EnglishTranslations {
  static const Map<String, String> translations = {
    'appName': 'SkillBridge',

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

    'skillBridgeWorkspace': 'SkillBridge Workspace',
    'selectLanguage': 'Select Language',
    'english': 'English',
    'marathi': 'Marathi',
    'hindi': 'Hindi',

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

    'quickActions': 'QUICK ACTIONS',
    'continueWhereLeft': 'Continue where you left off',
    'jumpWorkspace': 'Jump directly to your workspace.',
    'openProjectWorkspace': 'Open your project workspace',
    'continueConversations': 'Continue your conversations',

    'clientAccount': 'Client account',
    'logout': 'Logout',
    'settings': 'Settings',

    'project': 'Project',
    'projectsPlural': 'Projects',

    'aiProjectAssistant': 'AI Project Assistant',
    'hireDeveloper': 'Hire Developer',
    'findDevelopers': 'Find Developers',
    'postProject': 'Post Project',

    'describeProject': 'Describe your project idea',
    'generateProject': 'Generate Project',
    'requiredSkill': 'Required Skill',
    'experience': 'Experience',
    'continueToPostProject': 'Continue to Post Project',

    'loginAgain': 'Please login again.',
    'softwareProjectsDescription':
        'Everything for your software projects, in one place.',

    'requirement': 'Requirement',
    'teamFormation': 'Team Formation',
    'development': 'Development',
    'testing': 'Testing',
    'clientReview': 'Client Review',
    'cancelled': 'Cancelled',

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

    'activity': 'ACTIVITY',
    'recentNotifications': 'Recent notifications',
    'latestWorkspaceUpdates':
        'Review the latest updates from your SkillBridge workspace.',
    'noNotifications': 'No notifications yet.',
    'markAsRead': 'Mark as read',

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

    'team': 'Team',
    'projectTeam': 'Project Team',
    'teamMembers': 'Team Members',
    'teamLeader': 'Team Leader',
    'frontendDeveloper': 'Frontend Developer',
    'backendDeveloper': 'Backend Developer',
    'databaseDeveloper': 'Database Developer',
    'tester': 'Tester',
    'noTeamMembers': 'No team members yet.',

    'projectDetails': 'Project Details',
    'description': 'Description',
    'requirements': 'Requirements',
    'budget': 'Budget',
    'timeline': 'Timeline',
    'progress': 'Progress',
    'viewTeam': 'View Team',
    'openMessages': 'Open Messages',

    'generatedProject': 'Generated Project',
    'projectTitle': 'Project Title',
    'projectDescription': 'Description',
    'exampleProjectIdea': 'Example: I need a website for my shop',
    'generatedSkills': 'Required Skills',
    'projectGeneratedSuccessfully': 'Project generated successfully.',

    'projectId': 'Project ID',
    'projectNotFound': 'Project not found.',
    'unableToLoadProject': 'Unable to load project.',

    'noData': 'No data',
    'yes': 'Yes',
    'no': 'No',
    'confirm': 'Confirm',
    'select': 'Select',
    'submit': 'Submit',
    'update': 'Update',

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

class MarathiTranslations {
  static const Map<String, String> translations = {
    'appName': 'SkillBridge',

    'dashboard': 'डॅशबोर्ड',
    'myProjects': 'माझे प्रोजेक्ट्स',
    'messages': 'संदेश',
    'notifications': 'सूचना',
    'myProfile': 'माझे प्रोफाइल',
    'home': 'होम',
    'projects': 'प्रोजेक्ट्स',
    'alerts': 'सूचना',
    'profile': 'प्रोफाइल',
    'client': 'क्लायंट',

    'skillBridgeWorkspace': 'SkillBridge कार्यक्षेत्र',
    'selectLanguage': 'भाषा निवडा',
    'english': 'इंग्रजी',
    'marathi': 'मराठी',
    'hindi': 'हिंदी',

    'welcomeBack': 'पुन्हा स्वागत आहे',
    'createNewProject': 'नवीन प्रोजेक्ट तयार करा',
    'shareIdea': 'तुमची कल्पना आणि आवश्यकता SkillBridge सोबत शेअर करा.',

    'overview': 'आढावा',
    'yourWorkspace': 'तुमचे कार्यक्षेत्र',
    'projectActivity': 'तुमच्या प्रोजेक्टच्या क्रियाकलापांचा आढावा.',

    'totalProjects': 'एकूण प्रोजेक्ट्स',
    'activeProjects': 'सक्रिय प्रोजेक्ट्स',
    'completed': 'पूर्ण झाले',

    'recentProjects': 'अलीकडील प्रोजेक्ट्स',
    'latestProjectActivity': 'तुमच्या अलीकडील प्रोजेक्टच्या हालचाली.',
    'viewAll': 'सर्व पहा',

    'noProjectsYet': 'अजून कोणतेही प्रोजेक्ट नाहीत',
    'createFirstProject': 'तुमचा पहिला प्रोजेक्ट तयार करा आणि तो येथे दिसेल.',

    'quickActions': 'जलद कृती',
    'continueWhereLeft': 'जिथे थांबलात तिथून पुढे जा',
    'jumpWorkspace': 'थेट तुमच्या कार्यक्षेत्रात जा.',
    'openProjectWorkspace': 'तुमचे प्रोजेक्ट कार्यक्षेत्र उघडा',
    'continueConversations': 'तुमचे संभाषण सुरू ठेवा',

    'clientAccount': 'क्लायंट खाते',
    'logout': 'लॉगआउट',
    'settings': 'सेटिंग्ज',

    'project': 'प्रोजेक्ट',
    'projectsPlural': 'प्रोजेक्ट्स',

    'aiProjectAssistant': 'AI प्रोजेक्ट सहाय्यक',
    'hireDeveloper': 'डेव्हलपर नियुक्त करा',
    'findDevelopers': 'डेव्हलपर शोधा',
    'postProject': 'प्रोजेक्ट पोस्ट करा',

    'describeProject': 'तुमच्या प्रोजेक्टची कल्पना सांगा',
    'generateProject': 'प्रोजेक्ट तयार करा',
    'requiredSkill': 'आवश्यक कौशल्य',
    'experience': 'अनुभव',
    'continueToPostProject': 'प्रोजेक्ट पोस्ट करण्यासाठी पुढे जा',

    'loginAgain': 'कृपया पुन्हा लॉगिन करा.',
    'softwareProjectsDescription':
        'तुमच्या सर्व सॉफ्टवेअर प्रोजेक्ट्ससाठी सर्वकाही एका ठिकाणी.',

    'requirement': 'गरज',
    'teamFormation': 'टीम तयार करणे',
    'development': 'डेव्हलपमेंट',
    'testing': 'टेस्टिंग',
    'clientReview': 'क्लायंट रिव्ह्यू',
    'cancelled': 'रद्द केले',

    'workspaceOverview': 'कार्यक्षेत्राचा आढावा',
    'quickActionsDescription':
        'तुमचे प्रोजेक्ट्स व्यवस्थापित करा आणि तुमचे काम सुरू ठेवा.',
    'createProject': 'प्रोजेक्ट तयार करा',
    'createProjectDescription':
        'तुमची कल्पना आणि आवश्यकता SkillBridge सोबत शेअर करा.',
    'totalProject': 'एकूण प्रोजेक्ट',
    'activeProject': 'सक्रिय प्रोजेक्ट',
    'completedProject': 'पूर्ण झालेले प्रोजेक्ट',
    'recentProject': 'अलीकडील प्रोजेक्ट',
    'noRecentProjects': 'अलीकडील कोणतेही प्रोजेक्ट नाहीत.',

    'conversations': 'संभाषणे',
    'yourProjectChats': 'तुमच्या प्रोजेक्टच्या चॅट्स',
    'openProjectConversation':
        'एकत्र काम सुरू ठेवण्यासाठी प्रोजेक्टचे संभाषण उघडा.',
    'noConversations': 'अजून कोणतेही संभाषण नाही.',
    'noMessagesYet': 'अजून कोणतेही संदेश नाहीत',
    'noConversationsYet': 'अजून कोणतेही संभाषण नाही',
    'startConversation': 'या प्रोजेक्टबद्दल संभाषण सुरू करा.',
    'typeMessage': 'संदेश लिहा...',
    'writeMessage': 'संदेश लिहा...',
    'send': 'पाठवा',
    'projectConversation': 'प्रोजेक्ट संभाषण',
    'unableToLoadMessages': 'संदेश लोड करता आले नाहीत.',
    'unableToLoadConversation': 'संभाषण लोड करता आले नाही.',
    'unableToSendMessage': 'संदेश पाठवता आला नाही.',
    'somethingWentWrong': 'काहीतरी चूक झाली.',

    'activity': 'क्रियाकलाप',
    'recentNotifications': 'अलीकडील सूचना',
    'latestWorkspaceUpdates':
        'तुमच्या SkillBridge कार्यक्षेत्रातील नवीन अपडेट्स पहा.',
    'noNotifications': 'अजून कोणत्याही सूचना नाहीत.',
    'markAsRead': 'वाचलेले म्हणून चिन्हांकित करा',

    'payments': 'पेमेंट्स',
    'paymentHistory': 'पेमेंट इतिहास',
    'paymentDetails': 'पेमेंट तपशील',
    'advancePayment': 'आगाऊ पेमेंट',
    'finalPayment': 'अंतिम पेमेंट',
    'pending': 'प्रलंबित',
    'paid': 'भरले',
    'failed': 'अयशस्वी',
    'refunded': 'परत केले',
    'paymentCancelled': 'रद्द केले',
    'noPayments': 'अजून कोणतेही पेमेंट रेकॉर्ड नाहीत.',

    'team': 'टीम',
    'projectTeam': 'प्रोजेक्ट टीम',
    'teamMembers': 'टीम सदस्य',
    'teamLeader': 'टीम लीडर',
    'frontendDeveloper': 'फ्रंटएंड डेव्हलपर',
    'backendDeveloper': 'बॅकएंड डेव्हलपर',
    'databaseDeveloper': 'डेटाबेस डेव्हलपर',
    'tester': 'टेस्टर',
    'noTeamMembers': 'अजून कोणतेही टीम सदस्य नाहीत.',

    'projectDetails': 'प्रोजेक्ट तपशील',
    'description': 'वर्णन',
    'requirements': 'आवश्यकता',
    'budget': 'बजेट',
    'timeline': 'वेळापत्रक',
    'progress': 'प्रगती',
    'viewTeam': 'टीम पहा',
    'openMessages': 'संदेश उघडा',

    'generatedProject': 'तयार केलेला प्रोजेक्ट',
    'projectTitle': 'प्रोजेक्टचे नाव',
    'projectDescription': 'वर्णन',
    'exampleProjectIdea': 'उदाहरण: मला माझ्या दुकानासाठी वेबसाइट हवी आहे',
    'generatedSkills': 'आवश्यक कौशल्ये',
    'projectGeneratedSuccessfully': 'प्रोजेक्ट यशस्वीरित्या तयार झाला.',

    'projectId': 'प्रोजेक्ट ID',
    'projectNotFound': 'प्रोजेक्ट सापडला नाही.',
    'unableToLoadProject': 'प्रोजेक्ट लोड करता आला नाही.',

    'noData': 'माहिती उपलब्ध नाही',
    'yes': 'होय',
    'no': 'नाही',
    'confirm': 'पुष्टी करा',
    'select': 'निवडा',
    'submit': 'सबमिट करा',
    'update': 'अपडेट करा',

    'loading': 'लोड होत आहे...',
    'error': 'काहीतरी चूक झाली.',
    'retry': 'पुन्हा प्रयत्न करा',
    'cancel': 'रद्द करा',
    'save': 'जतन करा',
    'edit': 'संपादित करा',
    'delete': 'हटवा',
    'close': 'बंद करा',
    'back': 'मागे',
    'next': 'पुढे',
    'continueText': 'सुरू ठेवा',
    'search': 'शोधा',
    'status': 'स्थिती',
    'date': 'तारीख',
    'amount': 'रक्कम',
    'category': 'श्रेणी',
  };

  static String get(String key) {
    return translations[key] ?? key;
  }
}

class HindiTranslations {
  static const Map<String, String> translations = {
    'appName': 'SkillBridge',

    'dashboard': 'डैशबोर्ड',
    'myProjects': 'मेरे प्रोजेक्ट्स',
    'messages': 'संदेश',
    'notifications': 'सूचनाएं',
    'myProfile': 'मेरी प्रोफ़ाइल',
    'home': 'होम',
    'projects': 'प्रोजेक्ट्स',
    'alerts': 'सूचनाएं',
    'profile': 'प्रोफ़ाइल',
    'client': 'क्लाइंट',

    'skillBridgeWorkspace': 'SkillBridge कार्यक्षेत्र',
    'selectLanguage': 'भाषा चुनें',
    'english': 'अंग्रेज़ी',
    'marathi': 'मराठी',
    'hindi': 'हिंदी',

    'welcomeBack': 'वापसी पर स्वागत है',
    'createNewProject': 'नया प्रोजेक्ट बनाएं',
    'shareIdea': 'अपना विचार और आवश्यकताएं SkillBridge के साथ साझा करें।',

    'overview': 'अवलोकन',
    'yourWorkspace': 'आपका कार्यक्षेत्र',
    'projectActivity': 'आपकी प्रोजेक्ट गतिविधियों का अवलोकन।',

    'totalProjects': 'कुल प्रोजेक्ट्स',
    'activeProjects': 'सक्रिय प्रोजेक्ट्स',
    'completed': 'पूर्ण',

    'recentProjects': 'हाल के प्रोजेक्ट्स',
    'latestProjectActivity': 'आपकी हाल की प्रोजेक्ट गतिविधियां।',
    'viewAll': 'सभी देखें',

    'noProjectsYet': 'अभी कोई प्रोजेक्ट नहीं है',
    'createFirstProject': 'अपना पहला प्रोजेक्ट बनाएं और वह यहां दिखाई देगा।',

    'quickActions': 'त्वरित कार्य',
    'continueWhereLeft': 'जहां छोड़ा था वहां से जारी रखें',
    'jumpWorkspace': 'सीधे अपने कार्यक्षेत्र में जाएं।',
    'openProjectWorkspace': 'अपना प्रोजेक्ट कार्यक्षेत्र खोलें',
    'continueConversations': 'अपनी बातचीत जारी रखें',

    'clientAccount': 'क्लाइंट खाता',
    'logout': 'लॉगआउट',
    'settings': 'सेटिंग्स',

    'project': 'प्रोजेक्ट',
    'projectsPlural': 'प्रोजेक्ट्स',

    'aiProjectAssistant': 'AI प्रोजेक्ट सहायक',
    'hireDeveloper': 'डेवलपर नियुक्त करें',
    'findDevelopers': 'डेवलपर खोजें',
    'postProject': 'प्रोजेक्ट पोस्ट करें',

    'describeProject': 'अपने प्रोजेक्ट का विचार बताएं',
    'generateProject': 'प्रोजेक्ट बनाएं',
    'requiredSkill': 'आवश्यक कौशल',
    'experience': 'अनुभव',
    'continueToPostProject': 'प्रोजेक्ट पोस्ट करने के लिए आगे बढ़ें',

    'loginAgain': 'कृपया फिर से लॉगिन करें।',
    'softwareProjectsDescription':
        'आपके सभी सॉफ्टवेयर प्रोजेक्ट्स के लिए सब कुछ एक ही जगह पर।',

    'requirement': 'आवश्यकता',
    'teamFormation': 'टीम गठन',
    'development': 'डेवलपमेंट',
    'testing': 'टेस्टिंग',
    'clientReview': 'क्लाइंट रिव्यू',
    'cancelled': 'रद्द किया गया',

    'workspaceOverview': 'कार्यक्षेत्र का अवलोकन',
    'quickActionsDescription':
        'अपने प्रोजेक्ट्स को प्रबंधित करें और अपना काम जारी रखें।',
    'createProject': 'प्रोजेक्ट बनाएं',
    'createProjectDescription':
        'अपना विचार और आवश्यकताएं SkillBridge के साथ साझा करें।',
    'totalProject': 'कुल प्रोजेक्ट',
    'activeProject': 'सक्रिय प्रोजेक्ट',
    'completedProject': 'पूर्ण प्रोजेक्ट',
    'recentProject': 'हाल का प्रोजेक्ट',
    'noRecentProjects': 'हाल का कोई प्रोजेक्ट नहीं है।',

    'conversations': 'बातचीत',
    'yourProjectChats': 'आपके प्रोजेक्ट की चैट्स',
    'openProjectConversation':
        'साथ मिलकर काम जारी रखने के लिए प्रोजेक्ट की बातचीत खोलें।',
    'noConversations': 'अभी कोई बातचीत नहीं है।',
    'noMessagesYet': 'अभी कोई संदेश नहीं है',
    'noConversationsYet': 'अभी कोई बातचीत नहीं है',
    'startConversation': 'इस प्रोजेक्ट के बारे में बातचीत शुरू करें।',
    'typeMessage': 'संदेश लिखें...',
    'writeMessage': 'संदेश लिखें...',
    'send': 'भेजें',
    'projectConversation': 'प्रोजेक्ट बातचीत',
    'unableToLoadMessages': 'संदेश लोड नहीं किए जा सके।',
    'unableToLoadConversation': 'बातचीत लोड नहीं की जा सकी।',
    'unableToSendMessage': 'संदेश भेजा नहीं जा सका।',
    'somethingWentWrong': 'कुछ गलत हो गया।',

    'activity': 'गतिविधि',
    'recentNotifications': 'हाल की सूचनाएं',
    'latestWorkspaceUpdates':
        'अपने SkillBridge कार्यक्षेत्र के नवीनतम अपडेट देखें।',
    'noNotifications': 'अभी कोई सूचना नहीं है।',
    'markAsRead': 'पढ़ा हुआ चिन्हित करें',

    'payments': 'भुगतान',
    'paymentHistory': 'भुगतान इतिहास',
    'paymentDetails': 'भुगतान विवरण',
    'advancePayment': 'अग्रिम भुगतान',
    'finalPayment': 'अंतिम भुगतान',
    'pending': 'लंबित',
    'paid': 'भुगतान किया गया',
    'failed': 'विफल',
    'refunded': 'वापस किया गया',
    'paymentCancelled': 'रद्द किया गया',
    'noPayments': 'अभी कोई भुगतान रिकॉर्ड नहीं है।',

    'team': 'टीम',
    'projectTeam': 'प्रोजेक्ट टीम',
    'teamMembers': 'टीम सदस्य',
    'teamLeader': 'टीम लीडर',
    'frontendDeveloper': 'फ्रंटएंड डेवलपर',
    'backendDeveloper': 'बैकएंड डेवलपर',
    'databaseDeveloper': 'डेटाबेस डेवलपर',
    'tester': 'टेस्टर',
    'noTeamMembers': 'अभी कोई टीम सदस्य नहीं है।',

    'projectDetails': 'प्रोजेक्ट विवरण',
    'description': 'विवरण',
    'requirements': 'आवश्यकताएं',
    'budget': 'बजट',
    'timeline': 'समयसीमा',
    'progress': 'प्रगति',
    'viewTeam': 'टीम देखें',
    'openMessages': 'संदेश खोलें',

    'generatedProject': 'तैयार किया गया प्रोजेक्ट',
    'projectTitle': 'प्रोजेक्ट का नाम',
    'projectDescription': 'विवरण',
    'exampleProjectIdea': 'उदाहरण: मुझे अपनी दुकान के लिए वेबसाइट चाहिए',
    'generatedSkills': 'आवश्यक कौशल',
    'projectGeneratedSuccessfully': 'प्रोजेक्ट सफलतापूर्वक तैयार हो गया।',

    'projectId': 'प्रोजेक्ट ID',
    'projectNotFound': 'प्रोजेक्ट नहीं मिला।',
    'unableToLoadProject': 'प्रोजेक्ट लोड नहीं किया जा सका।',

    'noData': 'कोई जानकारी नहीं',
    'yes': 'हां',
    'no': 'नहीं',
    'confirm': 'पुष्टि करें',
    'select': 'चुनें',
    'submit': 'सबमिट करें',
    'update': 'अपडेट करें',

    'loading': 'लोड हो रहा है...',
    'error': 'कुछ गलत हो गया।',
    'retry': 'पुनः प्रयास करें',
    'cancel': 'रद्द करें',
    'save': 'सहेजें',
    'edit': 'संपादित करें',
    'delete': 'हटाएं',
    'close': 'बंद करें',
    'back': 'वापस',
    'next': 'आगे',
    'continueText': 'जारी रखें',
    'search': 'खोजें',
    'status': 'स्थिति',
    'date': 'तारीख',
    'amount': 'राशि',
    'category': 'श्रेणी',
  };

  static String get(String key) {
    return translations[key] ?? key;
  }
}
