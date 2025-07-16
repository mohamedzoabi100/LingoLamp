import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../services/sync_service.dart';
import '../../../../services/sync_status_service.dart';
import '../../../../widgets/sync_status_bar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final syncService = SyncService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          // Show sync status in app bar
          if (authProvider.isAuthenticated)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(child: SyncStatusBar()),
            ),
        ],
      ),
      body: ListView(
        children: [
          // Account Section
          if (authProvider.isAuthenticated) ...[
            const _SectionHeader(title: 'Account'),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              subtitle: Text(authProvider.currentUser?.email ?? ''),
              onTap: () {
                // TODO: Navigate to profile
              },
            ),
            const Divider(),
          ],

          // Sync Section (only for authenticated users)
          if (authProvider.isAuthenticated) ...[
            const _SectionHeader(title: 'Sync & Data'),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync Now'),
              subtitle: const Text('Manually sync your data across devices'),
              onTap: () => _performManualSync(context),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download),
              title: const Text('Pull from Cloud'),
              subtitle: const Text('Download latest data from cloud'),
              onTap: () => _pullFromCloud(context),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('Push to Cloud'),
              subtitle: const Text('Upload local data to cloud'),
              onTap: () => _pushToCloud(context),
            ),
            const Divider(),
          ],

          // App Settings
          const _SectionHeader(title: 'App Settings'),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            onTap: () {
              // TODO: Navigate to notifications
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            onTap: () {
              // TODO: Navigate to language settings
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Storage & Data'),
            onTap: () {
              // TODO: Navigate to storage settings
            },
          ),

          // Privacy & Legal
          const _SectionHeader(title: 'Privacy & Legal'),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: () {
              // TODO: Show privacy policy
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            onTap: () {
              // TODO: Show terms of service
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'LingoLamp',
                applicationVersion: '2.0.0',
                applicationIcon: Image.asset('assets/images/Logo.png', width: 48, height: 48),
                children: [
                  const SizedBox(height: 16),
                  const Text(
                    'LingoLamp is your all-in-one language learning companion, designed to help you master new languages through interactive features and smart AI assistance.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Key Features:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('• Flashcards with spaced repetition'),
                  const Text('• AI-powered chat and phrase suggestions'),
                  const Text('• Daily tasks and XP streaks'),
                  const Text('• Favorites and personalized recommendations'),
                  const Text('• Cross-device sync (cloud backup)'),
                  const Text('• Guest mode (no account required)'),
                  const Text('• Full account deletion and data portability'),
                  const SizedBox(height: 12),
                  const Text(
                    'Data Collection & Privacy:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    '• We collect only the data needed to provide your learning experience: flashcards, chat history, XP, favorites, and settings.'
                  ),
                  const Text(
                    '• All data is securely stored and transmitted using Google Firebase.'
                  ),
                  const Text(
                    '• You can delete your account and all data at any time from Settings.'
                  ),
                  const Text(
                    '• No personal data is shared with third parties.'
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Compliance:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('• Fully compliant with Google Play Store data safety and privacy policies.'),
                  const Text('• See our Privacy Policy and Terms of Service for more details.'),
                  const SizedBox(height: 12),
                  const Text(
                    'Open Source Licenses:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text('This app uses the following open source libraries:'),
                  const SizedBox(height: 8),
                  const Text('• Flutter (Apache 2.0)'),
                  const Text('• Firebase (Apache 2.0)'),
                  const Text('• Provider (MIT)'),
                  const Text('• Go Router (BSD 3-Clause)'),
                  const Text('• Google Generative AI (Apache 2.0)'),
                  const Text('• SQLite (Public Domain)'),
                  const Text('• Hive (Apache 2.0)'),
                  const Text('• Shared Preferences (Apache 2.0)'),
                  const Text('• Cached Network Image (MIT)'),
                  const Text('• Shimmer (MIT)'),
                  const Text('• Flutter Markdown (MIT)'),
                  const Text('• Flutter TTS (MIT)'),
                  const Text('• Speech to Text (MIT)'),
                  const Text('• Intl (BSD 3-Clause)'),
                  const Text('• HTTP (BSD 3-Clause)'),
                  const Text('• Connectivity Plus (Apache 2.0)'),
                  const Text('• Path Provider (Apache 2.0)'),
                  const Text('• Permission Handler (MIT)'),
                  const Text('• RxDart (Apache 2.0)'),
                  const Text('• Path (BSD 3-Clause)'),
                  const Text('• UUID (MIT)'),
                  const Text('• CSV (MIT)'),
                  const Text('• Cupertino Icons (MIT)'),
                  const Text('• Google APIs Auth (Apache 2.0)'),
                  const Text('• Audio Players (MIT)'),
                  const SizedBox(height: 8),
                  const Text('For full license texts, visit:'),
                  const Text('https://github.com/flutter/flutter/blob/master/LICENSE'),
                  const Text('https://firebase.google.com/terms'),
                  const Text('https://pub.dev/packages/provider'),
                  const Text('https://pub.dev/packages/go_router'),
                ],
              );
            },
          ),

          // Account Actions
          const _SectionHeader(title: 'Account Actions'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.orange),
            title: const Text('Sign Out', style: TextStyle(color: Colors.orange)),
            onTap: () => _showSignOutDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Permanently delete account and all data'),
            onTap: () => _showDeleteAccountDialog(context),
          ),
        ],
      ),
    );
  }

  Future<void> _performManualSync(BuildContext context) async {
    final syncService = SyncService();
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Syncing data...')),
      );
      
      await syncService.performFullSync();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }

  Future<void> _pullFromCloud(BuildContext context) async {
    final syncService = SyncService();
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pulling data from cloud...')),
      );
      
      await syncService.pullFromCloud();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data pulled successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pull failed: $e')),
        );
      }
    }
  }

  Future<void> _pushToCloud(BuildContext context) async {
    final syncService = SyncService();
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pushing data to cloud...')),
      );
      
      await syncService.pushToCloud();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data pushed successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Push failed: $e')),
        );
      }
    }
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out? Your data will be saved locally.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Clear provider states before signing out
              AuthProvider.clearProviderStates(context);
              context.read<AuthProvider>().signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action will permanently delete your account and all associated data including:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• All flashcards and study progress'),
            Text('• Chat history and conversations'),
            Text('• XP, levels, and achievements'),
            Text('• Favorites and preferences'),
            Text('• Recommendations'),
            SizedBox(height: 8),
            Text(
              'This action cannot be undone. Are you absolutely sure?',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDeleteAccount(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: const Text(
          'This is your final warning. Your account and all data will be permanently deleted and cannot be recovered. Type "DELETE" to confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthProvider>().deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }
} 