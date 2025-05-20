// lib/screens/main_app_page.dart
import 'package:flutter/material.dart';

class MainAppPage extends StatelessWidget {
  const MainAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LingoLamp (Logged In User - Placeholder)'), // Title indicates its potential purpose
        backgroundColor: Theme.of(context).primaryColor, // Use theme color
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      body: const Center(
        child: Text(
          'This is the Main App Page (e.g., for logged-in users)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, color: Color.fromARGB(255, 255, 255, 255)), // Adjust color if background changes
        ),
      ),
      // You might want a different background color here if it's distinct from GuestHomePage
      // or InitialPage. For now, it will inherit the default dark from MyApp.
      // backgroundColor: const Color(0xFF0E7A71),
    );
  }
}