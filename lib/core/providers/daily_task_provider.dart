import 'package:flutter/foundation.dart';
import '../../models/daily_task_model.dart';
import '../../services/daily_task_service.dart';

class DailyTaskProvider extends ChangeNotifier {
  final DailyTaskService _taskService = DailyTaskService();
  
  DailyTaskSet? _currentTaskSet;
  bool _isLoading = false;
  String? _errorMessage;
  String _currentLanguage = 'es'; // Default to Spanish

  // Getters
  DailyTaskSet? get currentTaskSet => _currentTaskSet;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentLanguage => _currentLanguage;
  
  int get completedTasksCount => _currentTaskSet?.completedTasksCount ?? 0;
  int get totalTasksCount => _currentTaskSet?.totalTasksCount ?? 0;
  double get completionPercentage => _currentTaskSet?.completionPercentage ?? 0.0;
  bool get isCompleted => _currentTaskSet?.isCompleted ?? false;

  /// Set current language and reload tasks
  void setLanguage(String languageCode) {
    if (_currentLanguage != languageCode) {
      _currentLanguage = languageCode;
      loadDailyTasks(); // Reload tasks for new language
    }
  }

  /// Load current daily tasks
  Future<void> loadDailyTasks() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final taskSet = await _taskService.getCurrentTaskSet(languageCode: _currentLanguage);
      
      _currentTaskSet = taskSet;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to load daily tasks: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update task progress
  Future<void> updateTaskProgress(TaskType taskType, int progress) async {
    try {
      await _taskService.updateTaskProgress(taskType, progress, languageCode: _currentLanguage);
      await loadDailyTasks(); // Reload to get updated state
    } catch (e) {
      _errorMessage = 'Failed to update task progress: $e';
      notifyListeners();
    }
  }

  /// Check and update all tasks based on current user activity
  Future<void> checkAndUpdateTasks() async {
    try {
      await _taskService.checkAndUpdateTasks(languageCode: _currentLanguage);
      await loadDailyTasks(); // Reload to get updated state
    } catch (e) {
      _errorMessage = 'Failed to check task progress: $e';
      notifyListeners();
    }
  }

  /// Get task by type
  DailyTask? getTaskByType(TaskType type) {
    return _currentTaskSet?.tasks.firstWhere(
      (task) => task.type == type,
      orElse: () => DailyTask(
        id: '',
        title: '',
        description: '',
        type: type,
        targetValue: 0,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Get task progress for specific type
  double getTaskProgress(TaskType type) {
    final task = getTaskByType(type);
    return task?.progressPercentage ?? 0.0;
  }

  /// Check if task is completed
  bool isTaskCompleted(TaskType type) {
    final task = getTaskByType(type);
    return task?.isCompleted ?? false;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
} 