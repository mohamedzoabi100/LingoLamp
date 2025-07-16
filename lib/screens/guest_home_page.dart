// lib/screens/guest_home_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../core/providers/auth_provider.dart';
import '../core/providers/language_provider.dart';
import '../widgets/language_flag_button.dart';
import '../services/daily_motivation_service.dart';
import '../services/user_data_service.dart'; // Added import for UserDataService

class GuestHomePage extends StatefulWidget {
  const GuestHomePage({super.key});

  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;
  DailyMotivation? _dailyMotivation;
  bool _isLoadingMotivation = true;
  LanguageProvider? _languageProvider; // Store reference

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacityAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
    });
    _loadDailyMotivation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only add listener once
    _languageProvider ??= Provider.of<LanguageProvider>(context, listen: false);
    _languageProvider!.addListener(_onLanguageChanged);
    if (_dailyMotivation?.languageCode != _languageProvider!.currentLanguage) {
      _loadDailyMotivation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _languageProvider?.removeListener(_onLanguageChanged); // Use stored reference
    super.dispose();
  }

  void _onLanguageChanged() {
    _loadDailyMotivation();
  }

  Future<void> _loadDailyMotivation() async {
    try {
      setState(() {
        _isLoadingMotivation = true;
      });
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      final motivation = await DailyMotivationService().getTodayMotivation(
        languageCode: languageProvider.currentLanguage,
      );
      if (mounted) {
        setState(() {
          _dailyMotivation = motivation;
          _isLoadingMotivation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMotivation = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        title: const Align(
          alignment: Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Welcome to LingoLamp', style: TextStyle(fontSize: 15, color: Colors.white70)),
              Text(
                'Guest Mode',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 26,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          const LanguageFlagButton(),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => _showGuestSettings(context),
          ),
          IconButton(
            icon: const Icon(Icons.login),
            tooltip: 'Sign In',
            onPressed: () => _showSignInDialog(context),
          ),
        ],
      ),
      body: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Yellow box at the top
                _buildSignInPrompt(),
                const SizedBox(height: 24),
                // Feature Cards Row
                Row(
                  children: [
                    Expanded(child: _buildFeatureCard(
                      '💬 AI Chat',
                      'Practice conversations with our AI tutor',
                      Icons.chat,
                      Colors.green,
                      () => context.go('/guest/chat'),
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _buildFeatureCard(
                      '📚 Phrasebook',
                      'Learn useful phrases and expressions',
                      Icons.auto_stories,
                      Colors.purple,
                      () => context.go('/guest/phrasebook'),
                    )),
                  ],
                ),
                const SizedBox(height: 32),
                // Daily Motivation Box
                _buildDailyMotivationBox(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_outline, color: Colors.blue[700], size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Try LingoLamp',
                    style: TextStyle(
                      fontSize: 20,
                        fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Experience our AI-powered language learning features. Start practicing with our chat assistant and explore useful phrases.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.4,
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildFeatureCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available Features',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 600) {
              return Row(
                children: [
                  Expanded(child: _buildFeatureCard(
                    '💬 AI Chat',
                    'Practice conversations with our AI tutor',
                    Icons.chat,
                    Colors.green,
                    () => context.go('/guest/chat'),
                  )),
                  const SizedBox(width: 16),
                  Expanded(child: _buildFeatureCard(
                    '📚 Phrasebook',
                    'Learn useful phrases and expressions',
                    Icons.auto_stories,
                    Colors.purple,
                    () => context.go('/guest/phrasebook'),
                  )),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildFeatureCard(
                    '💬 AI Chat',
                    'Practice conversations with our AI tutor',
                    Icons.chat,
                    Colors.green,
                    () => context.go('/guest/chat'),
                  ),
                  const SizedBox(height: 16),
                  _buildFeatureCard(
                    '📚 Phrasebook',
                    'Learn useful phrases and expressions',
                    Icons.auto_stories,
                    Colors.purple,
                    () => context.go('/guest/phrasebook'),
                  ),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star_outline, color: Colors.orange[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Unlock Full Features',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Sign in to access flashcards, progress tracking, favorites, and sync your data across devices.',
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showSignInDialog(context),
                icon: const Icon(Icons.login),
                label: const Text('Sign In with Google'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyMotivationBox() {
    if (_dailyMotivation == null && _isLoadingMotivation) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.purple[50],
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    if (_dailyMotivation == null) {
      return const SizedBox.shrink();
    }
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
            children: [
                Icon(Icons.lightbulb_outline, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'Daily Motivation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
                if (_isLoadingMotivation) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[700]!),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _dailyMotivation!.spanishQuote,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _dailyMotivation!.englishTranslation,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showSignInDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign In'),
        content: const Text('Would you like to sign in to unlock all features and sync your progress?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthProvider>().exitGuestMode();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  void _showGuestSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guest Settings'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage your guest data and settings:'),
            SizedBox(height: 16),
            Text('• Delete all guest data (flashcards, chat history, favorites)'),
            Text('• Clear app preferences'),
            Text('• Reset to fresh start'),
            SizedBox(height: 8),
            Text(
              'Note: This will permanently delete all your guest data and cannot be undone.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showDeleteDataDialog(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All Data'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Guest Data'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will permanently delete all your guest data including:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• All flashcards and study progress'),
            Text('• Chat history and conversations'),
            Text('• Favorites and preferences'),
            Text('• AI-generated phrases'),
            Text('• App settings and preferences'),
            SizedBox(height: 8),
            Text(
              'This action cannot be undone. Are you absolutely sure?',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDeleteData(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All Data'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteData(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: const Text(
          'This is your final warning. All guest data will be permanently deleted and cannot be recovered. This will reset the app to a fresh state.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteAllGuestData(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete & Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllGuestData(BuildContext context) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Deleting all data...'),
            ],
          ),
        ),
      );

      // Clear all guest data
      await UserDataService().clearAllUserData();
      
      // Clear provider states
      AuthProvider.clearProviderStates(context);

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All guest data has been deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
