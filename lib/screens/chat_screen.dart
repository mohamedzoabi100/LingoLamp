// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      body: const Center(
        child: Text(
          'Chat Screen - Coming Soon!',
          style: TextStyle(fontSize: 24, color: Colors.black87), // Adjust color for light background
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255), // Consistent light background
    );
  }
}