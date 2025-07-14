import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

// Providers
import '../providers/auth_provider.dart';

// Screens
import '../../features/auth/presentation/screens/sign_in_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../screens/chat_screen.dart';
import '../../screens/chat_history_screen.dart';
import '../../features/phrasebook/presentation/screens/phrasebook_screen.dart';
import '../../screens/flashcards_screen.dart';
import '../../models/phrasebook_theme.dart';
import '../../features/phrasebook/presentation/screens/category_phrases_screen.dart';
import '../../screens/recommendations_screen.dart';
import '../../screens/guest_home_page.dart';

class AppRouter {
  static final List<RouteBase> routes = [
    // Loading screen
    GoRoute(
      path: '/loading',
      builder: (context, state) => const LoadingScreen(),
    ),
    // Error screen
    GoRoute(
      path: '/error',
      builder: (context, state) => const ErrorScreen(),
    ),
    // Sign in screen
    GoRoute(
      path: '/signin',
      builder: (context, state) => const SignInScreen(),
    ),
    // Guest mode routes
    ShellRoute(
      builder: (context, state, child) => GuestAppShell(child: child),
      routes: [
        // Guest home screen
        GoRoute(
          path: '/guest',
          builder: (context, state) => const GuestHomePage(),
        ),
        // Guest chat screen
        GoRoute(
          path: '/guest/chat',
          builder: (context, state) => const ChatScreen(),
        ),
        // Guest phrasebook screen
        GoRoute(
          path: '/guest/phrasebook',
          builder: (context, state) => const PhrasebookScreen(),
        ),
      ],
    ),
    // Main app routes (authenticated users)
    ShellRoute(
      builder: (context, state, child) => MainAppShell(child: child),
      routes: [
        // Home screen
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        // Chat routes
        GoRoute(
          path: '/chat',
          builder: (context, state) => const ChatHistoryScreen(),
        ),
        GoRoute(
          path: '/chat/new',
          builder: (context, state) => const ChatScreen(),
        ),
        GoRoute(
          path: '/chat/:conversationId',
          builder: (context, state) => ChatScreen(
            conversationId: state.pathParameters['conversationId'],
          ),
        ),
        // Optionally, keep chat history route for direct access
        GoRoute(
          path: '/chat/history',
          builder: (context, state) => const ChatHistoryScreen(),
        ),
        // Phrasebook routes
        GoRoute(
          path: '/phrasebook',
          builder: (context, state) => const PhrasebookScreen(),
        ),
        GoRoute(
          path: '/phrasebook/category/:categoryId',
          builder: (context, state) {
            final categoryId = state.pathParameters['categoryId'] ?? '';
            final theme = _getThemeForCategory(categoryId);
            if (theme == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Category Not Found')),
                body: const Center(child: Text('Category not found.')),
              );
            }
            return CategoryPhrasesScreen(
              categoryTitle: theme.title,
              categoryColor: theme.color,
              categoryIcon: theme.icon,
            );
          },
        ),
        // Flashcard routes
        GoRoute(
          path: '/flashcards',
          builder: (context, state) => const FlashcardsScreen(),
        ),
        // Recommendations
        GoRoute(
          path: '/recommendations',
          builder: (context, state) => const RecommendationsScreen(),
        ),

      ],
    ),
  ];
}

// Loading screen
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading LingoLamp...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Error screen
class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please try again or contact support if the problem persists.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Clear error and retry
                  context.read<AuthProvider>().clearError();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Guest app shell with simplified navigation
class GuestAppShell extends StatefulWidget {
  final Widget child;

  const GuestAppShell({super.key, required this.child});

  @override
  State<GuestAppShell> createState() => _GuestAppShellState();
}

class _GuestAppShellState extends State<GuestAppShell> {
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/guest/chat')) {
      _currentIndex = 1;
    } else if (location.startsWith('/guest/phrasebook')) {
      _currentIndex = 2;
    } else {
      _currentIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Navigate to the selected route
          switch (index) {
            case 0:
              context.go('/guest');
              break;
            case 1:
              context.go('/guest/chat');
              break;
            case 2:
              context.go('/guest/phrasebook');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal[700],
        unselectedItemColor: Colors.teal[200],
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, color: Colors.blue[200]),
            activeIcon: Icon(Icons.home, color: Colors.blue[700]),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined, color: Colors.green[200]),
            activeIcon: Icon(Icons.chat, color: Colors.green[700]),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories_outlined, color: Colors.purple[200]),
            activeIcon: Icon(Icons.auto_stories, color: Colors.purple[700]),
            label: 'Phrasebook',
          ),
        ],
      ),
    );
  }
}

// Main app shell with bottom navigation
class MainAppShell extends StatefulWidget {
  final Widget child;

  const MainAppShell({super.key, required this.child});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Navigate to the selected route
          switch (index) {
            case 0:
              context.go('/');
              break;
            case 1:
              context.go('/chat');
              break;
            case 2:
              context.go('/phrasebook');
              break;
            case 3:
              context.go('/flashcards');
              break;
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal[700],
        unselectedItemColor: Colors.teal[200],
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, color: Colors.blue[200]),
            activeIcon: Icon(Icons.home, color: Colors.blue[700]),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined, color: Colors.green[200]),
            activeIcon: Icon(Icons.chat, color: Colors.green[700]),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_stories_outlined, color: Colors.purple[200]),
            activeIcon: Icon(Icons.auto_stories, color: Colors.purple[700]),
            label: 'Phrasebook',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.diamond_outlined, color: Colors.teal[200]),
            activeIcon: Icon(Icons.diamond, color: Colors.teal[700]),
            label: 'Flashcards',
          ),
        ],
      ),
    );
  }
} 

// Helper to map categoryId to theme data
PhrasebookTheme? _getThemeForCategory(String categoryId) {
  final themes = [
    PhrasebookTheme(
      title: 'Food & Dining',
      icon: Icons.restaurant,
      color: Colors.orange,
      phraseCount: 0,
      description: '',
    ),
    PhrasebookTheme(
      title: 'Transport',
      icon: Icons.directions_car,
      color: Colors.blue,
      phraseCount: 0,
      description: '',
    ),
    PhrasebookTheme(
      title: 'Emergencies',
      icon: Icons.local_hospital,
      color: Colors.red,
      phraseCount: 0,
      description: '',
    ),
    PhrasebookTheme(
      title: 'Greetings',
      icon: Icons.waving_hand,
      color: Colors.green,
      phraseCount: 0,
      description: '',
    ),
    PhrasebookTheme(
      title: 'Shopping',
      icon: Icons.shopping_bag,
      color: Colors.purple,
      phraseCount: 0,
      description: '',
    ),
    PhrasebookTheme(
      title: 'Accommodation',
      icon: Icons.hotel,
      color: Colors.brown,
      phraseCount: 0,
      description: '',
    ),
  ];
  for (final t in themes) {
    if (t.title.toLowerCase().replaceAll('&', '').replaceAll(' ', '').replaceAll('-', '') ==
        categoryId.toLowerCase().replaceAll('&', '').replaceAll(' ', '').replaceAll('-', '')) {
      return t;
    }
  }
  return null;
} 