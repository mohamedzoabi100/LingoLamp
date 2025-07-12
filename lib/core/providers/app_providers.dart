import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

// Auth
import 'auth_provider.dart';

// Features
import '../../providers/chat_provider.dart';
import 'flashcard_provider.dart';
import 'phrasebook_provider.dart';
import 'user_provider.dart';
import 'daily_task_provider.dart';
import 'language_provider.dart';

class AppProviders {
  static List<SingleChildWidget> get providers => [
    // Auth provider
    ChangeNotifierProvider<AuthProvider>(
      create: (context) => AuthProvider(),
    ),
    
    // User provider
    ChangeNotifierProvider<UserProvider>(
      create: (context) => UserProvider(),
    ),
    
    // Chat provider
    ChangeNotifierProvider<ChatProvider>(
      create: (context) => ChatProvider(),
    ),
    
    // Flashcard provider
    ChangeNotifierProvider<FlashcardProvider>(
      create: (context) => FlashcardProvider(),
    ),
    
    // Phrasebook provider
    ChangeNotifierProvider<PhrasebookProvider>(
      create: (context) => PhrasebookProvider(),
    ),
    
    // Daily Task provider
    ChangeNotifierProvider<DailyTaskProvider>(
      create: (context) => DailyTaskProvider(),
    ),
    
    // Language provider
    ChangeNotifierProvider<LanguageProvider>(
      create: (context) => LanguageProvider(),
    ),
  ];
} 