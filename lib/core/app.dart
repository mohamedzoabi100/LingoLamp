import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// Providers
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';

// Services
import '../services/sync_service.dart';

// Theme
import 'theme/app_theme.dart';

// Screens
import 'routing/app_router.dart';

class LingoLampApp extends StatelessWidget {
  const LingoLampApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: const _RouterScope(),
    );
  }
}

class _RouterScope extends StatefulWidget {
  const _RouterScope();

  @override
  State<_RouterScope> createState() => _RouterScopeState();
}

class _RouterScopeState extends State<_RouterScope> with WidgetsBindingObserver {
  late SyncService _syncService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncService = SyncService();
    _initializeSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncService.dispose();
    super.dispose();
  }

  Future<void> _initializeSync() async {
    await _syncService.initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Handle app lifecycle changes for sync
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - check for sync
        if (_syncService.isAuthenticated) {
          _syncService.pullFromCloud();
        }
        break;
      case AppLifecycleState.paused:
        // App going to background - push any pending changes
        if (_syncService.isAuthenticated) {
          _syncService.pushToCloud();
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    final GoRouter router = GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        // Update user provider when auth state changes
        if (authProvider.currentUser != userProvider.currentUser) {
          userProvider.setUser(authProvider.currentUser);
        }
        // Show loading screen while checking auth state
        if (authProvider.authState == AuthState.initial) {
          return '/loading';
        }
        // Show error screen if auth failed
        if (authProvider.authState == AuthState.error) {
          return '/error';
        }
        // Handle guest mode
        if (authProvider.authState == AuthState.guest) {
          // If user is in guest mode and trying to access authenticated routes
          if (!state.matchedLocation.startsWith('/guest') && state.matchedLocation != '/signin') {
            return '/guest';
          }
          return null;
        }
        // Redirect to sign in if not authenticated
        if (authProvider.authState == AuthState.unauthenticated) {
          return '/signin';
        }
        // Allow access to authenticated routes
        return null;
      },
      routes: AppRouter.routes,
    );

    return MaterialApp.router(
      title: 'LingoLamp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
} 