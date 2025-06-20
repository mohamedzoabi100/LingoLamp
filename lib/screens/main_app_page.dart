// lib/screens/main_app_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/user_data_service.dart';
import 'chat_screen.dart';
import 'phrasebook_screen.dart';
import 'flashcards_screen.dart';
import 'loggedin_settings_screen.dart';

class MainAppPage extends StatefulWidget {
  const MainAppPage({super.key});

  @override
  State<MainAppPage> createState() => _MainAppPageState();
}

class _MainAppPageState extends State<MainAppPage> {
/* ──────────────────── auth / user state ──────────────────── */

  final AuthService _authService = AuthService();
  final UserDataService _userDataService = UserDataService();

  bool _isLoading = false;
  User? _currentUser;

  Map<String, dynamic> _userStats = {
    'currentStreak': 0,
    'longestStreak': 0,
    'flashcardsCount': 0,
    'chatsCount': 0,
  };

/* ──────────────────── bottom-bar state (unchanged) ──────────────────── */

  int _selectedIndex = -1; // –1 = Home

  late final List<Widget> _navPages = [
    ChatScreen(onBackToHome: _returnToHome),
    PhrasebookScreen(onBackToHome: _returnToHome),
    FlashcardsScreen(onBackToHome: _returnToHome),
  ];

  Widget get _body =>
      _selectedIndex == -1 ? _homeContent() : _navPages[_selectedIndex];

  void _onItemTapped(int i) => setState(() => _selectedIndex = i);

  Color _selectedNavColor(BuildContext ctx) =>
    _selectedIndex == -1                       // home?
        ? Theme.of(ctx).colorScheme.onSurface.withOpacity(.6)   // same as unselected
        : Theme.of(ctx).colorScheme.primary;   // normal highlight

  void _returnToHome() => setState(() => _selectedIndex = -1);

/* ──────────────────── lifecycle ──────────────────── */

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
      final stats = await _userDataService.getUserStats();
      if (mounted) setState(() => _userStats = stats);
      await Future.delayed(const Duration(milliseconds: 400));
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Widget _homeContent() {
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
                icon: const Icon(Icons.account_circle,
                    size: 32, color: Colors.white),
                onSelected: (v) => v == 'settings'
                    ? Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()))
                    : _signOut(),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'settings',
                      child: Row(children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('Settings')
                      ])),
                  const PopupMenuItem(
                      value: 'signout',
                      child: Row(children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Sign Out',
                            style: TextStyle(color: Colors.red))
                      ])),
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
      body: _body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex < 0 ? 0 : _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: _selectedNavColor(context),
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(.6),

        selectedFontSize: _selectedIndex == -1 ? 12 : 14,
        unselectedFontSize: 12,
        
        items: const [
          // Still 3 tabs for now ── Home tab decision comes later
          BottomNavigationBarItem(
              icon: Icon(Icons.chat_outlined), label: 'Chat'),
          BottomNavigationBarItem(
              icon: Icon(Icons.auto_stories_outlined), label: 'Phrasebook'),
          BottomNavigationBarItem(
              icon: Icon(Icons.diamond_outlined), label: 'Flashcards'),
        ],
      ),
    );
  }
}
