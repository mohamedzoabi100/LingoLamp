//lib/screens/phrasebook_screen.dart
import 'package:flutter/material.dart';
import 'category_phrases_screen.dart';
import 'phrase_search_screen.dart';
import 'favorites_screen.dart';
import 'ai_suggestions_screen.dart'; // NEW IMPORT

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
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phrasebook'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Favorites star icon in top right
          IconButton(
            icon: const Icon(Icons.star, color: Colors.white),
            tooltip: 'Favorite Phrases',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoritesScreen(),
                ),
              );
            },
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          // AI Suggestions Card - NOW FIRST with APP COLORS
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildAiSuggestionsCard(),
          ),
          
          // Search bar section - NOW SECOND
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GestureDetector(
              // Make entire container tappable
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PhraseSearchScreen(),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
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
                      const Spacer(),
                      // Add arrow indicator to show it's tappable
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // FIXED: Responsive Themes grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Calculate responsive grid parameters
                  final availableWidth = constraints.maxWidth;
                  int crossAxisCount = 2;
                  double childAspectRatio = 1.0;
                  
                  // Adjust for different screen sizes
                  if (availableWidth > 600) {
                    // Tablet/Large screens - 3 columns
                    crossAxisCount = 3;
                    childAspectRatio = 0.85;
                  } else if (availableWidth > 400) {
                    // Medium screens - 2 columns with better ratio
                    crossAxisCount = 2;
                    childAspectRatio = 0.95;
                  } else {
                    // Small screens - 2 columns with taller cards
                    crossAxisCount = 2;
                    childAspectRatio = 0.85;
                  }
                  
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: childAspectRatio,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _themes.length,
                    itemBuilder: (context, index) {
                      return _buildThemeCard(_themes[index], availableWidth);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // AI Suggestions Card - UPDATED with App Colors (Teal gradient)
  Widget _buildAiSuggestionsCard() {
    final primaryColor = Theme.of(context).colorScheme.primary; // Your teal color
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const AiSuggestionsScreen(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16), // Reduced padding
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primaryColor, // Your app's primary teal
              primaryColor.withOpacity(0.8), // Lighter teal
              primaryColor.withOpacity(0.6), // Even lighter teal
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3), // Teal shadow
              spreadRadius: 0,
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Better alignment
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10), // Slightly smaller
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Colors.white,
                    size: 28, // Slightly smaller
                  ),
                ),
                const SizedBox(width: 12),
                Expanded( // This is KEY for responsive design
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Smart Suggestions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18, // Slightly smaller
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1, // Prevent overflow
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get phrases for any topic you need',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13, // Smaller font
                        ),
                        maxLines: 2, // Allow wrapping but limit lines
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6), // Smaller arrow container
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 14, // Smaller arrow
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Responsive example text container
            LayoutBuilder(
              builder: (context, constraints) {
                // Adjust text based on available width
                final availableWidth = constraints.maxWidth;
                String exampleText = 'Try: "golf", "business meeting", "airport"...';
                
                // For very small screens, use shorter text
                if (availableWidth < 300) {
                  exampleText = 'Try: "golf", "business"...';
                } else if (availableWidth < 350) {
                  exampleText = 'Try: "golf", "business", "airport"...';
                }
                
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        color: Colors.white.withOpacity(0.8),
                        size: 16, // Smaller icon
                      ),
                      const SizedBox(width: 8),
                      Expanded( // KEY: Prevent overflow
                        child: Text(
                          exampleText,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12, // Smaller font
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // FIXED: Made theme cards responsive with better text handling
  Widget _buildThemeCard(PhrasebookTheme theme, double availableWidth) {
    // Calculate responsive font sizes based on screen width
    double titleFontSize = availableWidth > 400 ? 16 : 15;
    double descriptionFontSize = availableWidth > 400 ? 12 : 11;
    double iconSize = availableWidth > 400 ? 26 : 24;
    double containerPadding = availableWidth > 400 ? 14.0 : 12.0;
    
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
          padding: EdgeInsets.all(containerPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: EdgeInsets.all(containerPadding * 0.8),
                      decoration: BoxDecoration(
                        color: theme.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        theme.icon,
                        color: theme.color,
                        size: iconSize,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Title and description section - with flexible layout
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      theme.title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: containerPadding * 0.4),
                    Expanded(
                      child: Text(
                        theme.description,
                        style: TextStyle(
                          fontSize: descriptionFontSize,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow indicator
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
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