// lib/screens/phrasebook_screen.dart
import 'package:flutter/material.dart';

class PhrasebookScreen extends StatelessWidget {
  const PhrasebookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrasebook'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: const Color.fromARGB(255, 255, 255, 255),
      ),
      body: const Center(
        child: Text(
          'Phrasebook Screen - Coming Soon!',
          style: TextStyle(fontSize: 24, color: Colors.black87),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
    );
  }
}