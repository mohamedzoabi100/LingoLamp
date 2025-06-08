//lib/screens/main_app_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_data_service.dart';
import 'chat_screen.dart'; 
import 'phrasebook_screen.dart';
import 'flashcards_screen.dart';
import 'favorites_screen.dart';
import 'chat_history_screen.dart';
import 'settings_screen.dart';
import 'auth/sign_in_screen.dart';

class MainAppPage extends StatefulWidget {
  const MainAppPage({super.key});

  @override
  State<MainAppPage> createState() => _MainAppPageState();
}

class _MainAppPageState extends State<MainAppPage> {
  final AuthService _authService = AuthService();
  final UserDataService _userDataService = UserDataService();
  bool _isLoading = false;
  User? _currentUser;
  Map<String, dynamic> _userStats = {
    'currentStreak': 0,
    'longestStreak': 0,
    'flashcardsCount': 0,
    'favoritesCount': 0,
    'chatsCount': 0,
  };

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // Just load user stats - sync is already handled by auth listener
      await _loadUserStats();
      
      // Add a small delay to ensure any ongoing sync completes
      await Future.delayed(const Duration(milliseconds: 500));
      
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final stats = await _userDataService.getUserStats();
      if (mounted) {
        setState(() {
          _userStats = stats;
        });
      }
    } catch (e) {
      print('Error loading user stats: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      print('Starting sign out process...');
      await _authService.signOut();
      print('Sign out completed - AuthStateWrapper will handle navigation');
      // AuthStateWrapper will automatically navigate to InitialPage when user becomes null
    } catch (e) {
      print('Error signing out: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildFeatureButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color borderColor,
    required VoidCallback onTap,
    double? width,
    double? height,
    String? badge,
  }) {
    final buttonContent = Container(
      width: width,
      height: height,
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
      child: Stack(
        children: [
          Column(
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
          if (badge != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return width == null && height == null
        ? Expanded(child: GestureDetector(onTap: onTap, child: buttonContent))
        : GestureDetector(onTap: onTap, child: buttonContent);
  }

  Widget _buildStreakPanel(BuildContext context) {
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
                Text('${_userStats['currentStreak']} 🔥', 
                    style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 4),
                Text('Current Streak', 
                    style: TextStyle(fontSize: 20, color: Theme.of(context).colorScheme.primary.withOpacity(1)), 
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          Container(height: 55, width: 1.0, color: Theme.of(context).colorScheme.primary.withOpacity(1)),
          Expanded(
            child: Column(
              children: [
                Text('${_userStats['longestStreak']} 🏆', 
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 4),
                Text('Longest Streak', 
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary.withOpacity(1)), 
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTaskPanel(BuildContext context) {
    String taskTitle = "Practice 5 flashcards";
    String taskDescription = "Review your saved flashcards to improve retention.";
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
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FlashcardsScreen()),
                    );
                  },
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: primaryTeal,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    Text(
                      _currentUser?.displayName ?? _currentUser?.email?.split('@')[0] ?? 'User',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.history, size: 28.0, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChatHistoryScreen()),
                        );
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.account_circle, size: 32.0, color: Colors.white),
                      onSelected: (value) {
                        if (value == 'settings') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        } else if (value == 'signout') {
                          _signOut();
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'settings',
                          child: Row(
                            children: [
                              Icon(Icons.settings, color: Colors.black87),
                              SizedBox(width: 8),
                              Text('Settings'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'signout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Sign Out', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
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
                              width: buttonWidth, 
                              height: buttonHeight,
                              badge: _userStats['chatsCount'] > 0 ? '${_userStats['chatsCount']}' : null,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ChatScreen())),
                            ),
                            const SizedBox(width: 12),
                            _buildFeatureButton(
                              context: context, 
                              icon: Icons.auto_stories, 
                              label: 'Phrasebook', 
                              iconColor: primaryTeal, 
                              borderColor: primaryTeal, 
                              width: buttonWidth, 
                              height: buttonHeight,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PhrasebookScreen())),
                            ),
                          ],
                        ),
                        SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            _buildFeatureButton(
                              context: context, 
                              icon: Icons.diamond, 
                              label: 'Flashcards', 
                              iconColor: primaryTeal, 
                              borderColor: primaryTeal, 
                              width: buttonWidth, 
                              height: buttonHeight,
                              badge: _userStats['flashcardsCount'] > 0 ? '${_userStats['flashcardsCount']}' : null,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FlashcardsScreen())),
                            ),
                            const SizedBox(width: 12),
                            _buildFeatureButton(
                              context: context, 
                              icon: Icons.favorite, 
                              label: 'Favorites', 
                              iconColor: primaryTeal, 
                              borderColor: primaryTeal, 
                              width: buttonWidth, 
                              height: buttonHeight,
                              badge: _userStats['favoritesCount'] > 0 ? '${_userStats['favoritesCount']}' : null,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesScreen())),
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