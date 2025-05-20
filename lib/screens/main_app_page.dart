//lib/screens/main_app_page.dart
import 'package:flutter/material.dart';

class MainAppPage extends StatelessWidget {
  const MainAppPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LingoLamp (Logged In User - Placeholder)'), 
        backgroundColor: Theme.of(context).primaryColor, 
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      body: const Center(
        child: Text(
          'This is the Main App Page (e.g., for logged-in users)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, color: Color.fromARGB(255, 255, 255, 255)), 
        ),
      ),
    );
  }
}