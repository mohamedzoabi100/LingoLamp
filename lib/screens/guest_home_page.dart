// lib/screens/guest_home_page.dart
import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'phrasebook_screen.dart';
import 'flashcards_screen.dart';
import 'guest_settings_screen.dart';

class GuestHomePage extends StatefulWidget {
  const GuestHomePage({super.key});

  @override
  State<GuestHomePage> createState() => _GuestHomePageState();
}

class _GuestHomePageState extends State<GuestHomePage> {
/* ──────────────────────────  bottom-nav state  ────────────────────────── */

  int _selectedIndex = -1; // –1 = Home
  int? _currentConversationId;

  List<Widget> get _navPages => [
    ChatScreen(
      onBackToHome: _returnToHome,
      conversationId: _currentConversationId,
      onConversationIdChanged: (id) {
        setState(() {
          _currentConversationId = id;
        });
      },
    ),
    PhrasebookScreen(onBackToHome: _returnToHome),
    FlashcardsScreen(onBackToHome: _returnToHome),
  ];

  Widget get _body =>
      _selectedIndex == -1 ? _homeContent() : _navPages[_selectedIndex];

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  Color _selectedNavColor(BuildContext ctx) =>
    _selectedIndex == -1                       // home?
        ? Theme.of(ctx).colorScheme.onSurface.withAlpha((255 * .6).round())   // same as unselected
        : Theme.of(ctx).colorScheme.primary;   // normal highlight

  void _returnToHome() => setState(() => _selectedIndex = -1);

/* ──────────────────────────  small helpers  ───────────────────────────── */

  Widget _buildStreakPanel(BuildContext context) {
    const int currentStreak = 5;
    const int longestStreak = 12;
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withAlpha((255 * .10).round()),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: Column(
              children: [
                Text('$currentStreak 🔥',
                    style: TextStyle(
                        fontSize: 35,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 4),
                Text('Current Streak',
                    style: TextStyle(
                        fontSize: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withAlpha(255)),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
          Container(
              height: 55,
              width: 1,
              color: Theme.of(context).colorScheme.primary),
          Expanded(
            child: Column(
              children: [
                Text('$longestStreak 🏆',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 4),
                Text('Longest Streak',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withAlpha(255)),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTaskPanel(BuildContext context) {
    const String taskTitle = 'Learn 10 new vocabulary words';
    const String taskDescription =
        'Focus on common verbs and nouns related to travel.';
    const bool isTaskCompleted = false;

    return Container(
      margin: const EdgeInsets.only(top: 25, bottom: 15),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isTaskCompleted
            ? Colors.green.withAlpha((255 * .08).round())
            : Theme.of(context).colorScheme.secondary.withAlpha((255 * .10).round()),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isTaskCompleted
              ? Colors.green.withAlpha((255 * .25).round())
              : Theme.of(context).colorScheme.secondary,
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
                    color: isTaskCompleted
                        ? Colors.green[700]
                        : Theme.of(context).colorScheme.secondary)),
          ),
          Icon(
              isTaskCompleted
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: isTaskCompleted
                  ? Colors.green[700]
                  : Theme.of(context).colorScheme.secondary,
              size: 26)
        ]),
        const SizedBox(height: 10),
        Text(taskTitle,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(height: 5),
        Text(taskDescription,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface)),
        if (!isTaskCompleted)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withAlpha((255 * .13).round()),
                    foregroundColor: Theme.of(context).colorScheme.secondary),
                onPressed: () => debugPrint('Start Task pressed'),
                child: const Text('Start Task'),
              ),
            ),
          ),
      ]),
    );
  }

/* ──────────────────────────  home (default) UI  ───────────────────────── */

  Widget _homeContent() {
    final Color primaryTeal = Theme.of(context).colorScheme.primary;
    final double statusBar = MediaQuery.of(context).padding.top;

    return Column(children: [
      // HEADER
      Container(
        width: double.infinity,
        color: primaryTeal,
        padding: EdgeInsets.only(
            top: statusBar + 15, bottom: 10, left: 20, right: 20),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LingoLamp',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                      )),
              IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      size: 30, color: Colors.white),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const GuestSettingsScreen())))
            ]),
      ),

      // BODY (scrollable)
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
      )
    ]);
  }

/* ──────────────────────────  build()  ─────────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _body,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex < 0 ? 0 : _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: _selectedNavColor(context),
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withAlpha((255 * .6).round()),

          selectedFontSize: _selectedIndex == -1 ? 12 : 14,
          unselectedFontSize: 12,
        items: const [
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
