// lib/screens/main_app_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/user_data_service.dart';
import '../services/xp_event_tracker.dart';
import 'chat_screen.dart';
import 'phrasebook_screen.dart';
import 'flashcards_screen.dart';
import '../widgets/sync_status_bar.dart';
import 'loggedin_settings_screen.dart';
import 'dart:async';

class MainAppPage extends StatefulWidget {
  const MainAppPage({super.key});

  @override
  State<MainAppPage> createState() => _MainAppPageState();
}

class _MainAppPageState extends State<MainAppPage> {
/* ──────────────────── auth / user state ──────────────────── */

  final AuthService _authService = AuthService();
  final UserDataService _userDataService = UserDataService();
  final XPEventTracker _xpTracker = XPEventTracker();

  // Streak tracking
  static const int STREAK_REQUIREMENT_MINUTES = 1440; // 24 hours
  bool _isLoading = true;
  bool _initialLoadDone = false;
  User? _currentUser;
  Timer? _refreshTimer;
  int? _currentConversationId;

  Map<String, dynamic> _userStats = {
    'currentStreak': 0,
    'longestStreak': 0,
    'totalXP': 0,
    'todayXP': 0,
    'flashcardsToday': {'count': 0, 'xp': 0, 'time': 0},
    'chatToday': {'count': 0, 'xp': 0, 'time': 0},
    'phrasesToday': {'count': 0, 'xp': 0, 'time': 0},
  };

/* ──────────────────── bottom-bar state (unchanged) ──────────────────── */

  int _selectedIndex = 0;

  List<Widget> get _pages => [
    _buildHomeScreen(),
    ChatScreen(
      onBackToHome: () => _onItemTapped(0),
      conversationId: _currentConversationId,
      onConversationIdChanged: (id) {
        setState(() {
          _currentConversationId = id;
        });
      },
    ),
    PhrasebookScreen(onBackToHome: () => _onItemTapped(0)),
    FlashcardsScreen(onBackToHome: () => _onItemTapped(0)),
  ];

  @override
  void initState() {
    super.initState();
    _currentUser = _authService.currentUser;
    _loadUserData();
    _startAutoRefresh();
    XPEventTracker.addXPListener(_loadUserData);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    XPEventTracker.removeXPListener(_loadUserData);
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 300), (_) {
      if (mounted) {
        _loadUserData();
      }
    });
  }

  Future<void> _loadUserData() async {
    final shouldShowSpinner = !_initialLoadDone;
    if (shouldShowSpinner && mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final stats = await _userDataService.getUserStats().timeout(const Duration(seconds: 10));
      final totalXP = await _xpTracker.getTotalXP().timeout(const Duration(seconds: 10));
      final todayXP = await _xpTracker.getTodayXP().timeout(const Duration(seconds: 10));
      
      if (mounted) {
        setState(() {
          _userStats = {
            ...stats,
            'totalXP': totalXP,
            'todayXP': todayXP,
          };
        });
      }
      await Future.delayed(const Duration(milliseconds: 400));
      _initialLoadDone = true;
    } catch (e, st) {
      debugPrint('Error in _loadUserData: $e\n$st');
      if (mounted) {
        setState(() {
          // Optionally show an error message to the user
        });
      }
    } finally {
      if (shouldShowSpinner && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

/* ──────────────────── shared UI helpers ──────────────────── */

  Widget _buildStreakPanel(BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.primary.withOpacity(.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Theme.of(ctx).colorScheme.primary, width: 2),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        Expanded(
          child: Column(children: [
            Text('${_userStats['currentStreak']} 🔥',
                style: TextStyle(
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).colorScheme.primary)),
            const SizedBox(height: 4),
            Text('Current Streak',
                style: TextStyle(
                    fontSize: 20,
                    color: Theme.of(ctx).colorScheme.primary),
                textAlign: TextAlign.center),
          ]),
        ),
        Container(
            height: 55,
            width: 1,
            color: Theme.of(ctx).colorScheme.primary),
        Expanded(
          child: Column(children: [
            Text('${_userStats['longestStreak']} 🏆',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(ctx).colorScheme.primary)),
            const SizedBox(height: 4),
            Text('Longest Streak',
                style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(ctx).colorScheme.primary),
                textAlign: TextAlign.center),
          ]),
        ),
      ]),
    );
  }

  Widget _buildXPPanel(BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's XP Breakdown",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(ctx).colorScheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_userStats['todayXP'] ?? 0} XP',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // XP Source Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildXPLegendItem(ctx, '📚', 'Flashcards', _userStats['flashcardsToday']?['xp'] ?? 0, Colors.blue),
              _buildXPLegendItem(ctx, '💬', 'Chat', _userStats['chatToday']?['xp'] ?? 0, Colors.green),
              _buildXPLegendItem(ctx, '📖', 'Phrasebook', _userStats['phrasesToday']?['xp'] ?? 0, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildXPLegendItem(BuildContext ctx, String emoji, String label, int xp, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(ctx).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$xp XP',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureStatsBoxes(BuildContext ctx) {
    final flashcardStats = _userStats['flashcardsToday'] ?? {'count': 0, 'xp': 0, 'time': 0};
    final chatStats = _userStats['chatToday'] ?? {'count': 0, 'xp': 0, 'time': 0};
    final phraseStats = _userStats['phrasesToday'] ?? {'count': 0, 'xp': 0, 'time': 0};

    return Container(
      margin: const EdgeInsets.only(top: 15),
      child: Row(
        children: [
          Expanded(child: _buildFeatureBox(ctx, '📚', 'Flashcards', flashcardStats, Colors.blue)),
          const SizedBox(width: 8),
          Expanded(child: _buildFeatureBox(ctx, '💬', 'Chat', chatStats, Colors.green)),
          const SizedBox(width: 8),
          Expanded(child: _buildFeatureBox(ctx, '📖', 'Phrasebook', phraseStats, Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildFeatureBox(BuildContext ctx, String emoji, String title, Map<String, dynamic> stats, Color color) {
    final xp = stats['xp'] as int;
    final time = stats['time'] as int; // Minutes spent using this feature

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildStatRow('XP', '$xp', color),
          _buildStatRow('Time', '${time}m', color),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color.withOpacity(.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTaskPanel(BuildContext ctx) {
    const taskTitle = 'Learn 10 new vocabulary words';
    const taskDescription =
        'Focus on common verbs and nouns related to travel.';
    const isDone = false;

    return Container(
      margin: const EdgeInsets.only(top: 25, bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDone
            ? Colors.green.withOpacity(.08)
            : Theme.of(ctx).colorScheme.secondary.withOpacity(.10),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDone
              ? Colors.green.withOpacity(.25)
              : Theme.of(ctx).colorScheme.secondary,
          width: 2,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text("Today's Task ✨",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDone
                        ? Colors.green[700]
                        : Theme.of(ctx).colorScheme.secondary)),
          ),
          Icon(isDone ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isDone
                  ? Colors.green[700]
                  : Theme.of(ctx).colorScheme.secondary,
              size: 26)
        ]),
        const SizedBox(height: 10),
        Text(taskTitle,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(ctx).colorScheme.onSurface)),
        const SizedBox(height: 5),
        Text(taskDescription,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(ctx).colorScheme.onSurface)),
        if (!isDone)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                  style: TextButton.styleFrom(
                      backgroundColor:
                          Theme.of(ctx).colorScheme.secondary.withOpacity(.13),
                      foregroundColor: Theme.of(ctx).colorScheme.secondary),
                  onPressed: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const PhrasebookScreen())),
                  child: const Text('Start Task')),
            ),
          ),
      ]),
    );
  }

/* ──────────────────── main HOME layout ──────────────────── */

  Widget _buildHomeScreen() {
    final Color primaryTeal = Theme.of(context).colorScheme.primary;
    final double statusBar = MediaQuery.of(context).padding.top;

    return Column(children: [
      // HEADER  (⚠️ only this grey box differs from guest)
      Container(
        width: double.infinity,
        color: primaryTeal,
        padding: EdgeInsets.only(
            top: statusBar + 15, bottom: 10, left: 20, right: 20),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Welcome back!', // ← guest header is just the logo
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
                Text(
                  _currentUser?.displayName ??
                      _currentUser?.email?.split('@')[0] ??
                      'User',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white, fontSize: 24),
                ),
              ]),
              PopupMenuButton<String>(
                icon: const Icon(Icons.account_circle, size: 32, color: Colors.white),
                onSelected: (value) {
                  if (value == 'settings') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  } else if (value == 'signout') {
                    _signOut();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(children: [Icon(Icons.settings), SizedBox(width: 8), Text('Settings')]),
                  ),
                  const PopupMenuItem(
                    value: 'signout',
                    child: Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 8), Text('Sign Out', style: TextStyle(color: Colors.red))]),
                  ),
                ],
              )
            ]),
      ),

      // BODY
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: MediaQuery.of(context).size.height * .02),
            _buildStreakPanel(context),
            _buildXPPanel(context),
            _buildFeatureStatsBoxes(context),
            _buildDailyTaskPanel(context),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    ]);
  }

/* ──────────────────── build() ──────────────────── */

  @override
  Widget build(BuildContext context) {
    final Color primaryTeal = Theme.of(context).colorScheme.primary;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: primaryTeal,
        body: const Center(
            child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
          SyncStatusBar(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_outlined), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.auto_stories_outlined), label: 'Phrasebook'),
          BottomNavigationBarItem(icon: Icon(Icons.diamond_outlined), label: 'Flashcards'),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
