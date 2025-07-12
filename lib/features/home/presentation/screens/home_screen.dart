import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/daily_task_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../widgets/xp_display_widget.dart';
import '../../../../widgets/language_flag_button.dart';
import '../../../../models/daily_task_model.dart';
import '../../../../services/daily_motivation_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;
  Timer? _refreshTimer;
  DailyMotivation? _dailyMotivation;
  bool _isLoadingMotivation = true;

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
      // Load daily tasks when screen initializes
      final dailyTaskProvider = Provider.of<DailyTaskProvider>(context, listen: false);
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
      dailyTaskProvider.setLanguage(languageProvider.currentLanguage);
      
      // Check and update tasks based on current activity
      dailyTaskProvider.checkAndUpdateTasks();
      
      // Load daily motivation
      _loadDailyMotivation();
      
      // Set up periodic refresh of tasks
      _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (mounted) {
          dailyTaskProvider.checkAndUpdateTasks();
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to language changes
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    languageProvider.addListener(_onLanguageChanged);
    
    // Reload motivation when language changes
    if (_dailyMotivation?.languageCode != languageProvider.currentLanguage) {
      _loadDailyMotivation();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _controller.dispose();
    // Remove language listener
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    languageProvider.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    // Reload daily motivation and tasks when language changes
    _loadDailyMotivation();
    final dailyTaskProvider = Provider.of<DailyTaskProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    dailyTaskProvider.setLanguage(languageProvider.currentLanguage);
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
        title: Builder(
          builder: (context) {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            final user = authProvider.currentUser;
            final displayName = user?.displayName ?? user?.email?.split('@')[0] ?? 'User';
            return Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Welcome back!', style: TextStyle(fontSize: 15, color: Colors.white70)),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 26, // Increased font size
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          const LanguageFlagButton(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            onSelected: (value) {
              if (value == 'signout') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
            onPressed: () {
                          Navigator.of(context).pop();
                          context.read<AuthProvider>().signOut();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );
              } else if (value == 'deleteaccount') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Account'),
                    content: const Text('This will permanently delete your account and all data. This action cannot be undone. Are you sure?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await context.read<AuthProvider>().deleteAccount();
            },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              } else if (value == 'about') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('About LingoLamp'),
                    content: const Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LingoLamp is your AI-powered language learning companion.'),
                        SizedBox(height: 8),
                        Text('Version: 1.0.0'),
                        SizedBox(height: 8),
                        Text('Features:'),
                        Text('• AI Chat for conversation practice'),
                        Text('• Smart Flashcards with spaced repetition'),
                        Text('• Phrasebook with AI suggestions'),
                        Text('• Progress tracking and XP system'),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'about',
                child: Row(children: [Icon(Icons.info_outline), SizedBox(width: 8), Text('About')]),
              ),
              const PopupMenuItem(
                value: 'signout',
                child: Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 8), Text('Sign Out', style: TextStyle(color: Colors.red))]),
              ),
              const PopupMenuItem(
                value: 'deleteaccount',
                child: Row(children: [Icon(Icons.delete_forever, color: Colors.red), SizedBox(width: 8), Text('Delete Account', style: TextStyle(color: Colors.red))]),
              ),
            ],
          ),
        ],
      ),
      body: Consumer4<AuthProvider, UserProvider, DailyTaskProvider, LanguageProvider>(
        builder: (context, authProvider, userProvider, dailyTaskProvider, languageProvider, child) {
          if (userProvider.isLoading || dailyTaskProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // (Welcome section moved to app bar)
                const SizedBox(height: 24),
                // XP and Streak Panels (side by side on wide screens, stacked on narrow)
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      return Row(
                        children: [
                          Expanded(child: XPDisplayWidget(showStreak: false)),
                          const SizedBox(width: 24),
                          Expanded(child: XPDisplayWidget(showStreak: true)),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          XPDisplayWidget(showStreak: false),
                          const SizedBox(height: 24),
                          XPDisplayWidget(showStreak: true),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 32),
                // Animated Daily Task Panel
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return AnimatedOpacity(
                      opacity: _opacityAnim.value,
                      duration: const Duration(milliseconds: 0),
                      child: AnimatedSlide(
                        offset: _slideAnim.value,
                        duration: const Duration(milliseconds: 0),
                        child: child,
                      ),
                    );
                  },
                  child: _buildDailyTaskPanel(context, dailyTaskProvider),
                ),
                const SizedBox(height: 24),
                // Daily Motivation Box
                _buildDailyMotivationBox(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWelcomeSection(
    BuildContext context,
    AuthProvider authProvider,
    UserProvider userProvider,
  ) {
    final user = authProvider.currentUser;
    final displayName = user?.displayName ?? user?.email?.split('@')[0] ?? 'User';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back!',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              displayName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, UserProvider userProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Progress',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        const XPDisplayWidget(showStreak: true),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                '💬 Chat',
                'Practice with AI',
                Icons.chat,
                () {
                  context.go('/chat');
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                '📚 Study',
                'Review flashcards',
                Icons.diamond,
                () {
                  context.go('/flashcards');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

  Widget _buildDailyGoalSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  'XP earned today',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Learn 10 new vocabulary words',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Focus on common verbs and nouns related to travel.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  context.go('/phrasebook');
                },
                child: const Text('Start Learning'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTaskPanel(BuildContext context, DailyTaskProvider dailyTaskProvider) {
    final taskSet = dailyTaskProvider.currentTaskSet;
    if (taskSet == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blueGrey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Daily Tasks',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                Text(
                  '${taskSet.completedTasksCount}/${taskSet.totalTasksCount} completed',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              children: taskSet.tasks.map((task) {
                return Column(
                  children: [
                    _buildTaskTile(task),
                    if (task != taskSet.tasks.last)
                      const Divider(height: 16, thickness: 1),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildTaskTile(DailyTask task) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Checkbox(
      value: task.isCompleted,
      onChanged: null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      activeColor: Colors.green,
    ),
    title: Text(
      task.title,
      style: TextStyle(
        fontWeight: FontWeight.w600, 
        fontSize: 16,
        decoration: task.isCompleted ? TextDecoration.lineThrough : null,
        color: task.isCompleted ? Colors.grey[600] : null,
      ),
    ),
    subtitle: task.isInProgress ? Text(
      '${task.currentValue}/${task.targetValue}',
      style: TextStyle(
        fontSize: 12,
        color: Colors.blue[600],
        fontWeight: FontWeight.w500,
      ),
    ) : null,
    trailing: task.isCompleted ? Icon(
      Icons.star,
      color: Colors.amber[600],
      size: 20,
    ) : null,
    dense: true,
    visualDensity: VisualDensity.compact,
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
} 