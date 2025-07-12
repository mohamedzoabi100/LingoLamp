import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class XPService {
  static final XPService _instance = XPService._internal();
  factory XPService() => _instance;
  XPService._internal();

  // Storage keys
  static const String _totalXPKey = 'total_xp';
  static const String _todayXPKey = 'today_xp';
  static const String _currentStreakKey = 'current_streak';
  static const String _longestStreakKey = 'longest_streak';
  static const String _lastActivityDateKey = 'last_activity_date';

  // XP change listeners
  static final List<VoidCallback> _xpListeners = [];
  static void addXPListener(VoidCallback listener) {
    _xpListeners.add(listener);
  }
  static void removeXPListener(VoidCallback listener) {
    _xpListeners.remove(listener);
  }
  void _notifyXPListeners() {
    for (final listener in _xpListeners) {
      listener();
    }
  }

  // XP rewards for different activities
  static const int chatMessage = 3;
  static const int flashcardCreated = 10;
  static const int flashcardEasy = 20;
  static const int flashcardGood = 15;
  static const int flashcardHard = 5;
  static const int flashcardAgain = 0;
  static const int phraseLearned = 5;
  static const int dailyStreak = 25;

  /// Add XP for an activity and update streak
  Future<void> addXP(int amount, String reason) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Get current values
    final totalXP = prefs.getInt(_totalXPKey) ?? 0;
    final lastActivityDate = prefs.getString(_lastActivityDateKey);
    DateTime? lastActivity;
    try {
      lastActivity = (lastActivityDate != null && lastActivityDate.isNotEmpty)
          ? DateTime.parse(lastActivityDate)
          : null;
    } catch (_) {
      lastActivity = null;
    }
    
    // Update streak first
    await _updateStreak(today, lastActivity);
    
    // Update today's XP
    int todayXP = prefs.getInt(_todayXPKey) ?? 0;
    if (lastActivity == null || !_isSameDay(lastActivity, today)) {
      // New day, reset today's XP
      todayXP = amount;
    } else {
      // Same day, add to existing XP
      todayXP += amount;
    }

    // Save values
    await prefs.setInt(_totalXPKey, totalXP + amount);
    await prefs.setInt(_todayXPKey, todayXP);
    await prefs.setString(_lastActivityDateKey, today.toIso8601String());
    
    print('🎉 +$amount XP for $reason (Total: ${totalXP + amount}, Today: $todayXP)');

    // Sync to Firestore if authenticated
    await _syncToFirestore(totalXP + amount, todayXP, today);

    // Notify listeners for UI update
    _notifyXPListeners();
  }

  /// Update streak based on activity
  Future<void> _updateStreak(DateTime today, DateTime? lastActivity) async {
    final prefs = await SharedPreferences.getInstance();
    int currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
    int longestStreak = prefs.getInt(_longestStreakKey) ?? 0;

    if (lastActivity == null) {
      // First time using the app
      currentStreak = 1;
    } else if (_isSameDay(lastActivity, today)) {
      // Already used the app today, don't change streak
      return;
    } else if (_isConsecutiveDay(lastActivity, today)) {
      // Consecutive day, increment streak
      currentStreak++;
    } else {
      // Missed a day, reset streak
      currentStreak = 1;
    }

    // Update longest streak if current is higher
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    // Save streak values
    await prefs.setInt(_currentStreakKey, currentStreak);
    await prefs.setInt(_longestStreakKey, longestStreak);

    print('🔥 Streak updated: $currentStreak days (Longest: $longestStreak)');

    // Award XP for maintaining streak (only on consecutive days) - FIXED: Don't call addXP recursively
    if (currentStreak > 1) {
      // Directly update XP without calling addXP to avoid infinite loop
      final totalXP = prefs.getInt(_totalXPKey) ?? 0;
      final todayXP = prefs.getInt(_todayXPKey) ?? 0;
      
      await prefs.setInt(_totalXPKey, totalXP + dailyStreak);
      await prefs.setInt(_todayXPKey, todayXP + dailyStreak);
      
      print('🎉 +$dailyStreak XP for Daily streak maintained (Total: ${totalXP + dailyStreak}, Today: ${todayXP + dailyStreak})');
      
      // Sync to Firestore if authenticated
      await _syncToFirestore(totalXP + dailyStreak, todayXP + dailyStreak, today);
      
      // Notify listeners for UI update
      _notifyXPListeners();
    }
  }

  /// Sync XP and streak data to Firestore
  Future<void> _syncToFirestore(int totalXP, int todayXP, DateTime lastActivity) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
      final longestStreak = prefs.getInt(_longestStreakKey) ?? 0;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'totalXP': totalXP,
        'todayXP': todayXP,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastActivityDate': lastActivity.toIso8601String(),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('XP sync timeout');
        },
      );
      print('[SYNC] XP and streak synced to Firestore');
    } catch (e) {
      print('[SYNC] Error syncing XP to Firestore: $e');
      // Don't let sync errors affect local XP tracking
    }
  }

  /// Get current XP statistics
  Future<Map<String, dynamic>> getXPStats() async {
    final prefs = await SharedPreferences.getInstance();
    final totalXP = prefs.getInt(_totalXPKey) ?? 0;
    final todayXP = prefs.getInt(_todayXPKey) ?? 0;
    final currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
    final longestStreak = prefs.getInt(_longestStreakKey) ?? 0;
    final lastActivityDate = prefs.getString(_lastActivityDateKey);

    return {
      'totalXP': totalXP,
      'todayXP': todayXP,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'lastActivityDate': lastActivityDate,
    };
  }

  /// Load XP data from Firestore for authenticated users
  Future<void> loadFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(Duration(seconds: 10));

      if (doc.exists) {
        final data = doc.data()!;
        final prefs = await SharedPreferences.getInstance();
        
        await prefs.setInt(_totalXPKey, data['totalXP'] ?? 0);
        await prefs.setInt(_todayXPKey, data['todayXP'] ?? 0);
        await prefs.setInt(_currentStreakKey, data['currentStreak'] ?? 0);
        await prefs.setInt(_longestStreakKey, data['longestStreak'] ?? 0);
        await prefs.setString(_lastActivityDateKey, data['lastActivityDate'] ?? '');

        print('[SYNC] XP data loaded from Firestore');
        _notifyXPListeners();
      }
    } catch (e) {
      print('[SYNC] Error loading XP from Firestore: $e');
    }
  }

  /// Check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  /// Check if two dates are consecutive days
  bool _isConsecutiveDay(DateTime date1, DateTime date2) {
    final difference = date2.difference(date1).inDays;
    return difference == 1;
  }

  /// Convenience methods for common XP activities
  Future<void> awardChatMessage() async {
    await addXP(chatMessage, 'Chat message sent');
  }

  Future<void> awardFlashcardCreated() async {
    await addXP(flashcardCreated, 'Flashcard created from chat');
  }

  Future<void> awardFlashcardReview(String difficulty) async {
    int xp = 0;
    String reason = '';
    
    switch (difficulty.toLowerCase()) {
      case 'easy':
        xp = flashcardEasy;
        reason = 'Flashcard marked as Easy';
        break;
      case 'good':
        xp = flashcardGood;
        reason = 'Flashcard marked as Good';
        break;
      case 'hard':
        xp = flashcardHard;
        reason = 'Flashcard marked as Hard';
        break;
      case 'again':
        xp = flashcardAgain;
        reason = 'Flashcard marked as Again';
        break;
    }
    
    if (xp > 0) {
      await addXP(xp, reason);
    }
  }

  Future<void> awardPhraseLearned() async {
    await addXP(phraseLearned, 'Phrase learned');
  }
} 