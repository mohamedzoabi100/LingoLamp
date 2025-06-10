//lib/screens/loggedin_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      print('Starting sign out process from settings...');
      await AuthService().signOut();
      print('Sign out completed - navigating to home');
      
      // Navigate back to home page (root) and clear navigation stack
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed out'),
            backgroundColor: Color(0xFF0E7A71),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      print('Error signing out: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryTeal = Color(0xFF0E7A71);
    final currentUser = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          // Profile Section
          ListTile(
            leading: const Icon(
              Icons.person_outline,
              color: Color(0xFF0E7A71),
            ),
            title: const Text(
              'Profile',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              currentUser?.email ?? 'Edit your profile information',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            onTap: () {
              // Show coming soon message for now
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile editing coming soon!'),
                  backgroundColor: Color(0xFF0E7A71),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ),
          
          const Divider(height: 32),
          
          // Notifications Section
          ListTile(
            leading: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF0E7A71),
            ),
            title: const Text(
              'Notifications',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            subtitle: const Text(
              'Manage notification preferences',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            onTap: () {
              // Show coming soon message for now
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification settings coming soon!'),
                  backgroundColor: Color(0xFF0E7A71),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ),
          
          const Divider(height: 32),
          
          // Appearance Section
          ListTile(
            leading: const Icon(
              Icons.palette_outlined,
              color: Color(0xFF0E7A71),
            ),
            title: const Text(
              'Appearance',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            subtitle: const Text(
              'Change theme or display settings',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            onTap: () {
              // Show coming soon message for now
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Appearance settings coming soon!'),
                  backgroundColor: Color(0xFF0E7A71),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ),
          
          const Divider(height: 32),

                    // About Section
          ListTile(
            leading: const Icon(Icons.info_outline, color: Color(0xFF0E7A71)),
            title: const Text(
              'About',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            subtitle: const Text(
              'App info and open source licenses',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'LingoLamp',
                applicationVersion: '1.0.0',
                applicationIcon: Image.asset('assets/images/Logo.png', height: 48),
                applicationLegalese: '© 2025 LingoLamp\nAll media is original.\nOpen source licenses are included.',
              );
            },
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ),

          const Divider(height: 32),
          
          // Sign Out Section
          ListTile(
            leading: const Icon(
              Icons.logout,
              color: Colors.red,
            ),
            title: const Text(
              'Sign Out',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Colors.red,
              ),
            ),
            subtitle: const Text(
              'Sign out of your account',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            onTap: () async {
              // Show confirmation dialog
              final bool? shouldSignOut = await showDialog<bool>(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  );
                },
              );
              
              if (shouldSignOut == true) {
                await _signOut(context);
              }
            },
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}