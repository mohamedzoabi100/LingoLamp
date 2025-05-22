//lib/screens/guest_home_page.dart
import 'package:flutter/material.dart';
import 'chat_screen.dart'; 
import 'phrasebook_screen.dart';
import 'flashcards_screen.dart';
import 'settings_screen.dart'; 

class GuestHomePage extends StatelessWidget {
  const GuestHomePage({super.key});

  Widget _buildFeatureButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color borderColor,
    required VoidCallback onTap,
    double? Twidth,
    double? Theight,
  }) {
    final buttonContent = Container(
      width: Twidth,
      height: Theight,
      padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: borderColor, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 65.0, color: iconColor),
          const SizedBox(height: 3.0),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
          ),
        ],
      ),
    );
    return Twidth == null && Theight == null
        ? Expanded(child: GestureDetector(onTap: onTap, child: buttonContent))
        : GestureDetector(onTap: onTap, child: buttonContent);
  }

  Widget _buildStreakPanel(BuildContext context) {
    int currentStreak = 5;
    int longestStreak = 12;
    return Container(
      margin: const EdgeInsets.only(top: 20.0),
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(1),
          width: 2.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          Expanded(
            child: Column(
              children: [
                Text('$currentStreak 🔥', style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 4),
                Text('Current Streak', style: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.primary.withOpacity(1)), textAlign: TextAlign.center),
              ],
            ),
          ),
          Container(height: 55, width: 1.0, color: Theme.of(context).colorScheme.primary.withOpacity(1)),
          Expanded(
            child: Column(
              children: [
                Text('$longestStreak 🏆', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 4),
                Text('Longest Streak', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary.withOpacity(1)), textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTaskPanel(BuildContext context) {
    String taskTitle = "Learn 10 new vocabulary words";
    String taskDescription = "Focus on common verbs and nouns related to travel.";
    bool isTaskCompleted = false;
    return Container(
      margin: const EdgeInsets.only(top: 25.0, bottom: 15.0),
      padding: const EdgeInsets.all(18.0),
      decoration: BoxDecoration(
        color: isTaskCompleted ? Colors.green.withOpacity(0.08) : Theme.of(context).colorScheme.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15.0),
        border: Border.all(
          color: isTaskCompleted ? Colors.green.withOpacity(0.25) : Theme.of(context).colorScheme.secondary.withOpacity(1),
          width: 2.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Today's Task ✨", 
                  style: TextStyle(
                    fontSize: 17, 
                    fontWeight: FontWeight.bold, 
                    color: isTaskCompleted ? Colors.green[700] : Theme.of(context).colorScheme.secondary
                  ),
                ),
              ),
              Icon(
                isTaskCompleted ? Icons.check_circle : Icons.radio_button_unchecked, 
                color: isTaskCompleted ? Colors.green[700] : Theme.of(context).colorScheme.secondary.withOpacity(1), 
                size: 26
              )
            ],
          ),
          const SizedBox(height: 10.0),
          Text(
            taskTitle, 
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.w600, 
              color: Theme.of(context).colorScheme.onSurface.withOpacity(1)
            )
          ),
          const SizedBox(height: 5.0),
          Text(
            taskDescription, 
            style: TextStyle(
              fontSize: 13, 
              color: Theme.of(context).colorScheme.onSurface.withOpacity(1)
            )
          ),
          if (!isTaskCompleted)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => print("Start Task / Mark as Complete pressed"),
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.13), 
                    foregroundColor: Theme.of(context).colorScheme.secondary, 
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), 
                    textStyle: const TextStyle(fontSize: 14)
                  ),
                  child: const Text('Start Task'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryTeal = Theme.of(context).colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final double buttonWidth = (screenWidth / 2) - 45;
    final double buttonHeight = buttonWidth * 1.05;
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: <Widget>[
          //--- HEADER BAR ---
          Container(
            width: double.infinity,
            color: primaryTeal,
            padding: EdgeInsets.only(
              top: statusBarHeight + 15.0,
              bottom: 10.0,
              left: 20.0,
              right: 20.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  'LingoLamp',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 30.0, color: Colors.white),
                  onPressed: () {
                    print('Settings button pressed');
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          //--- END HEADER BAR ---

          //--- CONTENT AREA ---
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    //Feature Buttons
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            _buildFeatureButton(
                              context: context, 
                              icon: Icons.chat, 
                              label: 'Chat', 
                              iconColor: primaryTeal, 
                              borderColor: primaryTeal, 
                              Twidth: buttonWidth, 
                              Theight: buttonHeight,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatScreen())),
                            ),
                            const SizedBox(width: 12),
                            _buildFeatureButton(
                              context: context, 
                              icon: Icons.auto_stories, 
                              label: 'Phrasebook', 
                              iconColor: primaryTeal, 
                              borderColor: primaryTeal, 
                              Twidth: buttonWidth, 
                              Theight: buttonHeight,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PhrasebookScreen())),
                            ),
                          ],
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            _buildFeatureButton(
                              context: context, 
                              icon: Icons.diamond, 
                              label: 'Flashcards', 
                              iconColor: primaryTeal, 
                              borderColor: primaryTeal, 
                              Twidth: buttonWidth, 
                              Theight: buttonHeight,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FlashcardsScreen())),
                            ),
                          ],
                        ),
                      ],
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),

                    _buildStreakPanel(context),
                    _buildDailyTaskPanel(context),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}