import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import '../models/daily_task_model.dart';
import 'xp_service.dart';

class DailyTaskService {
  static final DailyTaskService _instance = DailyTaskService._internal();
  factory DailyTaskService() => _instance;
  DailyTaskService._internal();

  // Storage keys
  static const String _currentTaskSetKey = 'current_daily_task_set';
  static const String _lastTaskResetDateKey = 'last_task_reset_date';
  static const String _taskVersionKey = 'daily_task_version';
  static const int _currentTaskVersion = 2; // Increment when changing task structure

  // Task change listeners
  static final List<VoidCallback> _taskListeners = [];
  static void addTaskListener(VoidCallback listener) {
    _taskListeners.add(listener);
  }
  static void removeTaskListener(VoidCallback listener) {
    _taskListeners.remove(listener);
  }
  void _notifyTaskListeners() {
    for (final listener in _taskListeners) {
      listener();
    }
  }

  /// Get current daily task set, creating new one if needed
  Future<DailyTaskSet> getCurrentTaskSet() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayString = _formatDate(today);
    
    // Check if we need to reset tasks for a new day or version update
    final lastResetDate = prefs.getString(_lastTaskResetDateKey);
    final currentVersion = prefs.getInt(_taskVersionKey) ?? 1;
    
    if (lastResetDate != todayString || currentVersion != _currentTaskVersion) {
      // New day or version update, create fresh task set
      final newTaskSet = _generateDailyTasks(today);
      await _saveTaskSet(newTaskSet);
      await prefs.setString(_lastTaskResetDateKey, todayString);
      await prefs.setInt(_taskVersionKey, _currentTaskVersion);
      print('🔄 Daily tasks reset: ${currentVersion != _currentTaskVersion ? "version update" : "new day"}');
      return newTaskSet;
    }

    // Load existing task set
    final taskSetJson = prefs.getString(_currentTaskSetKey);
    if (taskSetJson != null) {
      try {
        final taskSet = DailyTaskSet.fromJson(jsonDecode(taskSetJson));
        return taskSet;
      } catch (e) {
        print('Error loading task set: $e');
      }
    }

    // Fallback: create new task set
    final newTaskSet = _generateDailyTasks(today);
    await _saveTaskSet(newTaskSet);
    await prefs.setString(_lastTaskResetDateKey, todayString);
    return newTaskSet;
  }

  /// Generate daily tasks based on user level and preferences
  DailyTaskSet _generateDailyTasks(DateTime date) {
    final taskId = _formatDate(date);
    final tasks = [
      DailyTask(
        id: '${taskId}_chat',
        title: 'Practice with AI',
        description: 'Have a conversation with AI to improve your language skills',
        type: TaskType.chatWithAI,
        targetValue: 3, // 3 messages
        xpReward: 15,
        createdAt: date,
      ),
      DailyTask(
        id: '${taskId}_flashcards',
        title: 'Review Flashcards',
        description: 'Review 5 flashcards to reinforce your learning',
        type: TaskType.reviewFlashcards,
        targetValue: 5,
        xpReward: 20,
        createdAt: date,
      ),
    ];

    return DailyTaskSet(
      id: taskId,
      date: date,
      tasks: tasks,
    );
  }

  /// Update task progress based on user activity
  Future<void> updateTaskProgress(TaskType taskType, int progress) async {
    final taskSet = await getCurrentTaskSet();
    final updatedTasks = <DailyTask>[];
    bool hasChanges = false;

    for (final task in taskSet.tasks) {
      if (task.type == taskType && !task.isCompleted) {
        final newCurrentValue = task.currentValue + progress;
        final newStatus = newCurrentValue >= task.targetValue 
            ? TaskStatus.completed 
            : TaskStatus.inProgress;
        
        final updatedTask = task.copyWith(
          currentValue: newCurrentValue,
          status: newStatus,
          completedAt: newStatus == TaskStatus.completed ? DateTime.now() : null,
        );
        
        updatedTasks.add(updatedTask);
        
        if (newStatus == TaskStatus.completed) {
          // Award XP for task completion
          await XPService().addXP(task.xpReward, 'Daily task completed: ${task.title}');
          hasChanges = true;
          
          // Check if all tasks are now completed and award bonus
          final allCompleted = updatedTasks.every((t) => t.status == TaskStatus.completed);
          if (allCompleted) {
            // Award bonus XP for completing all daily tasks
            await XPService().addXP(30, '🎉 All daily tasks completed!');
            print('🎉 Bonus XP awarded for completing all daily tasks!');
          }
        }
      } else {
        updatedTasks.add(task);
      }
    }

    // Always notify listeners when task progress is updated
    final updatedTaskSet = taskSet.copyWith(tasks: updatedTasks);
    await _saveTaskSet(updatedTaskSet);
    _notifyTaskListeners();
  }

  /// Check and update task progress based on current user stats
  Future<void> checkAndUpdateTasks() async {
    try {
      final xpStats = await XPService().getXPStats();
      final todayXP = xpStats['todayXP'] ?? 0;
      
      // Update XP task
      await updateTaskProgress(TaskType.earnXP, todayXP);
      
      // TODO: Add other task type updates based on user activity
      // This will be expanded as we integrate with other services
      
    } catch (e) {
      print('Error checking task progress: $e');
    }
  }

  /// Save task set to local storage
  Future<void> _saveTaskSet(DailyTaskSet taskSet) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentTaskSetKey, jsonEncode(taskSet.toJson()));
  }

  /// Sync tasks to Firestore for authenticated users
  Future<void> syncToFirestore(DailyTaskSet taskSet) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyTasks')
          .doc(taskSet.id)
          .set(taskSet.toJson(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));
      
      print('[SYNC] Daily tasks synced to Firestore');
    } catch (e) {
      print('[SYNC] Error syncing daily tasks to Firestore: $e');
    }
  }

  /// Load tasks from Firestore for authenticated users
  Future<void> loadFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final today = DateTime.now();
      final todayString = _formatDate(today);
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('dailyTasks')
          .doc(todayString)
          .get()
          .timeout(const Duration(seconds: 10));

      if (doc.exists) {
        final data = doc.data()!;
        final taskSet = DailyTaskSet.fromJson(data);
        await _saveTaskSet(taskSet);
        
        print('[SYNC] Daily tasks loaded from Firestore');
        _notifyTaskListeners();
      }
    } catch (e) {
      print('[SYNC] Error loading daily tasks from Firestore: $e');
    }
  }

  /// Get task completion statistics
  Future<Map<String, dynamic>> getTaskStats() async {
    final taskSet = await getCurrentTaskSet();
    return {
      'completedTasks': taskSet.completedTasksCount,
      'totalTasks': taskSet.totalTasksCount,
      'completionPercentage': taskSet.completionPercentage,
      'isCompleted': taskSet.isCompleted,
      'totalXP': taskSet.totalXP,
    };
  }

  /// Format date for consistent ID generation
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
} 