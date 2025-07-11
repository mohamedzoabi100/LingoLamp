import 'package:flutter/material.dart';

class PhrasebookScreen extends StatelessWidget {
  final String? categoryId;

  const PhrasebookScreen({
    super.key,
    this.categoryId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrasebook'),
      ),
      body: const Center(
        child: Text('Phrasebook - Coming soon!'),
      ),
    );
  }
} 