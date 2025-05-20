// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.primary, // Use your app's primary color
        foregroundColor: Colors.white, // Text and back arrow color
      ),
      backgroundColor: Theme.of(context).colorScheme.surface, // Use the white background
      body: ListView( // Use ListView for settings as they often grow
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: const Text('Edit your profile information'),
            onTap: () {
              // TODO: Navigate to Profile Edit Screen
              print('Profile tapped');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text('Manage notification preferences'),
            onTap: () {
              // TODO: Navigate to Notification Settings Screen
              print('Notifications tapped');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Appearance'),
            subtitle: const Text('Change theme or display settings'),
            onTap: () {
              // TODO: Navigate to Appearance Settings Screen
              print('Appearance tapped');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_outlined),
            title: const Text('Log Out'),
            onTap: () {
              // TODO: Implement Log Out functionality
              print('Log Out tapped');
              // Example: Navigator.of(context).popUntil((route) => route.isFirst); // Go back to initial page
            },
          ),
        ],
      ),
    );
  }
}