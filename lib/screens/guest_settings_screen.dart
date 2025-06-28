//lib/screens/guest_settings_screen.dart
import 'package:flutter/material.dart';
import 'auth/sign_in_screen.dart';


class GuestSettingsScreen extends StatelessWidget {
  const GuestSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryTeal = Color(0xFF0E7A71);
    
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
          // Log In Option - First item for guest users
          ListTile(
            leading: const Icon(
              Icons.login,
              color: Color(0xFF0E7A71),
            ),
            title: const Text(
              'Log In',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            subtitle: const Text(
              'Sign in to access all features',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SignInScreen()),
              );
            },
            trailing: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey,
            ),
          ),
          
          const Divider(
            thickness: 1,
            color: Colors.grey,
            indent: 16,
            endIndent: 16,
          ),
          
          // Notifications - Disabled for now but keeping the UI
          ListTile(
            leading: const Icon(
              Icons.notifications_outlined,
              color: Colors.grey,
            ),
            title: const Text(
              'Notifications',
              style: TextStyle(
                color: Colors.grey,
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
              // Show coming soon message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications settings coming soon!'),
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
          
          const Divider(
            thickness: 1,
            color: Colors.grey,
            indent: 16,
            endIndent: 16,
          ),
          
          // Appearance - Disabled for now but keeping the UI
          ListTile(
            leading: const Icon(
              Icons.palette_outlined,
              color: Colors.grey,
            ),
            title: const Text(
              'Appearance',
              style: TextStyle(
                color: Colors.grey,
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
              // Show coming soon message
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
          
          const Divider(
            thickness: 1,
            color: Colors.grey,
            indent: 16,
            endIndent: 16,
          ),

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
        ],
      ),
    );
  }
}