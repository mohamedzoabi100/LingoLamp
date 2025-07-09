import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class XPEventTracker {
  static final XPEventTracker _instance = XPEventTracker._internal();
  factory XPEventTracker() => _instance;
  XPEventTracker._internal();

  static const String _totalXPKey = 'total_xp';
  static const String _todayXPKey = 'today_xp';
  static const String _lastDateKey = 'last_xp_date';

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

  Future<void> addXP(int amount, String reason) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Get current values
    final totalXP = prefs.getInt(_totalXPKey) ?? 0;
    final lastDate = prefs.getString(_lastDateKey);
    final lastDateObj = lastDate != null ? DateTime.parse(lastDate) : null;
    
    // Reset today's XP if it's a new day
    int todayXP = 0;
    if (lastDateObj == null || !_isSameDay(lastDateObj, today)) {
      todayXP = amount;
    } else {
      todayXP = prefs.getInt(_todayXPKey) ?? 0;
      todayXP += amount;
    }

    // Save values
    await prefs.setInt(_totalXPKey, totalXP + amount);
    await prefs.setInt(_todayXPKey, todayXP);
    await prefs.setString(_lastDateKey, today.toIso8601String());
    print('🎉 +$amount XP for $reason (Total: ${totalXP + amount}, Today: $todayXP)');

    // Sync XP to Firestore if authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'totalXP': totalXP + amount,
          'todayXP': todayXP,
          'lastXPDate': today.toIso8601String(),
        }, SetOptions(merge: true));
        print('[SYNC] XP synced to Firestore');
      } catch (e) {
        print('[SYNC] Error syncing XP to Firestore: $e');
      }
    }
    // Notify listeners for UI update
    _notifyXPListeners();
  }

  Future<int> getTotalXP() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalXPKey) ?? 0;
  }

  Future<int> getTodayXP() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_lastDateKey);
    if (lastDate == null) return 0;
    
    final lastDateObj = DateTime.parse(lastDate);
    final today = DateTime.now();
    
    if (!_isSameDay(lastDateObj, today)) {
      return 0; // New day, reset today's XP
    }
    
    return prefs.getInt(_todayXPKey) ?? 0;
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year && 
           date1.month == date2.month && 
           date1.day == date2.day;
  }

  // XP rewards for different activities
  static const int flashcardEasy = 20;
  static const int flashcardGood = 15;
  static const int flashcardHard = 5;
  static const int flashcardAgain = 0;
  static const int favoriteAdded = 5; // Adding a phrase to favourites
  static const int phraseLearned = 5; // AI generated phrase
  static const int chatMessage = 3;
  static const int flashcardCreatedFromChat = 10;
  static const int streakMaintained = 25;
  static const int dailyGoal = 50;
} 