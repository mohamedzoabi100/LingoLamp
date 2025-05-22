//lib/screens/phrasebook_screen.dart
import 'package:flutter/material.dart';
import 'category_phrases_screen.dart';
import 'phrase_search_screen.dart';

class PhrasebookScreen extends StatefulWidget {
  const PhrasebookScreen({super.key});

  @override
  State<PhrasebookScreen> createState() => _PhrasebookScreenState();
}

class _PhrasebookScreenState extends State<PhrasebookScreen> {
  // Sample data structure for themes
  final List<PhrasebookTheme> _themes = [
    PhrasebookTheme(
      title: 'Food & Dining',
      icon: Icons.restaurant,
      color: Colors.orange,
      phraseCount: 25,
      description: 'Essential phrases for restaurants and food shopping',
    ),
    PhrasebookTheme(
      title: 'Transport',
      icon: Icons.directions_car,
      color: Colors.blue,
      phraseCount: 20,
      description: 'Getting around, directions, and transportation',
    ),
    PhrasebookTheme(
      title: 'Emergencies',
      icon: Icons.local_hospital,
      color: Colors.red,
      phraseCount: 15,
      description: 'Important phrases for urgent situations',
    ),
    PhrasebookTheme(
      title: 'Greetings',
      icon: Icons.waving_hand,
      color: Colors.green,
      phraseCount: 18,
      description: 'Basic greetings and polite expressions',
    ),
    PhrasebookTheme(
      title: 'Shopping',
      icon: Icons.shopping_bag,
      color: Colors.purple,
      phraseCount: 22,
      description: 'Shopping, prices, and bargaining phrases',
    ),
    PhrasebookTheme(
      title: 'Accommodation',
      icon: Icons.hotel,
      color: Colors.brown,
      phraseCount: 16,
      description: 'Hotel, booking, and accommodation needs',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrasebook'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // Search bar section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PhraseSearchScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Search phrases',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Themes grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.9,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _themes.length,
                itemBuilder: (context, index) {
                  return _buildThemeCard(_themes[index]);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard(PhrasebookTheme theme) {
    return GestureDetector(
      onTap: () {
        // Navigate to category phrases screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryPhrasesScreen(
              categoryTitle: theme.title,
              categoryColor: theme.color,
              categoryIcon: theme.icon,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.color.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      theme.icon,
                      color: theme.color,
                      size: 28,
                    ),
                  ),
                ],
              ),
              
              // Title and description
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    theme.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    theme.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              
              // Arrow indicator
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.color.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Data model for phrasebook themes
class PhrasebookTheme {
  final String title;
  final IconData icon;
  final Color color;
  final int phraseCount;
  final String description;

  PhrasebookTheme({
    required this.title,
    required this.icon,
    required this.color,
    required this.phraseCount,
    required this.description,
  });
}