import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserStats {
  final int currentStreak;
  final int longestStreak;
  final int totalXP;
  final int todayXP;
  final Map<String, dynamic> flashcardsToday;
  final Map<String, dynamic> chatToday;
  final Map<String, dynamic> phrasesToday;

  UserStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalXP,
    required this.todayXP,
    required this.flashcardsToday,
    required this.chatToday,
    required this.phrasesToday,
  });

  factory UserStats.initial() {
    return UserStats(
      currentStreak: 0,
      longestStreak: 0,
      totalXP: 0,
      todayXP: 0,
      flashcardsToday: {'count': 0, 'xp': 0, 'time': 0},
      chatToday: {'count': 0, 'xp': 0, 'time': 0},
      phrasesToday: {'count': 0, 'xp': 0, 'time': 0},
    );
  }

  UserStats copyWith({
    int? currentStreak,
    int? longestStreak,
    int? totalXP,
    int? todayXP,
    Map<String, dynamic>? flashcardsToday,
    Map<String, dynamic>? chatToday,
    Map<String, dynamic>? phrasesToday,
  }) {
    return UserStats(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalXP: totalXP ?? this.totalXP,
      todayXP: todayXP ?? this.todayXP,
      flashcardsToday: flashcardsToday ?? this.flashcardsToday,
      chatToday: chatToday ?? this.chatToday,
      phrasesToday: phrasesToday ?? this.phrasesToday,
    );
  }
}

class UserProvider extends ChangeNotifier {
  User? _currentUser;
  UserStats _userStats = UserStats.initial();
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  UserStats get userStats => _userStats;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setUser(User? user) {
    _currentUser = user;
    if (user != null) {
      _loadUserStats();
    } else {
      _userStats = UserStats.initial();
    }
    notifyListeners();
  }

  Future<void> _loadUserStats() async {
    if (_currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      // TODO: Load user stats from Firebase/local storage
      // For now, using mock data
      await Future.delayed(const Duration(milliseconds: 500));
      
      _userStats = UserStats(
        currentStreak: 5,
        longestStreak: 12,
        totalXP: 1250,
        todayXP: 85,
        flashcardsToday: {'count': 15, 'xp': 45, 'time': 20},
        chatToday: {'count': 8, 'xp': 25, 'time': 15},
        phrasesToday: {'count': 12, 'xp': 15, 'time': 10},
      );

      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load user stats: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserStats(UserStats newStats) async {
    try {
      _userStats = newStats;
      notifyListeners();
      
      // TODO: Save to Firebase/local storage
    } catch (e) {
      _errorMessage = 'Failed to update user stats: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
} 