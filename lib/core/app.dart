import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

// Providers
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';

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

class _RouterScope extends StatelessWidget {
  const _RouterScope();

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