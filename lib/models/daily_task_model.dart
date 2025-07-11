import 'package:flutter/foundation.dart';

enum TaskType {
  chatWithAI,
  reviewFlashcards,
  earnXP,
  learnPhrases,
  practiceSpeaking,
  completeStreak,
}

enum TaskStatus {
  notStarted,
  inProgress,
  completed,
}

class DailyTask {
  final String id;
  final String title;
  final String description;
  final TaskType type;
  final int targetValue;
  final int currentValue;
  final TaskStatus status;
  final int xpReward;
  final DateTime? completedAt;
  final DateTime createdAt;

  DailyTask({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetValue,
    this.currentValue = 0,
    this.status = TaskStatus.notStarted,
    this.xpReward = 10,
    this.completedAt,
    required this.createdAt,
  });

  DailyTask copyWith({
    String? id,
    String? title,
    String? description,
    TaskType? type,
    int? targetValue,
    int? currentValue,
    TaskStatus? status,
    int? xpReward,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return DailyTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      status: status ?? this.status,
      xpReward: xpReward ?? this.xpReward,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isCompleted => status == TaskStatus.completed;
  bool get isInProgress => status == TaskStatus.inProgress;
  double get progressPercentage => targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.index,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'status': status.index,
      'xpReward': xpReward,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    return DailyTask(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: TaskType.values[json['type']],
      targetValue: json['targetValue'],
      currentValue: json['currentValue'] ?? 0,
      status: TaskStatus.values[json['status']],
      xpReward: json['xpReward'] ?? 10,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class DailyTaskSet {
  final String id;
  final DateTime date;
  final List<DailyTask> tasks;
  final bool isCompleted;
  final int totalXP;

  DailyTaskSet({
    required this.id,
    required this.date,
    required this.tasks,
    this.isCompleted = false,
    this.totalXP = 0,
  });

  int get completedTasksCount => tasks.where((task) => task.isCompleted).length;
  int get totalTasksCount => tasks.length;
  double get completionPercentage => totalTasksCount > 0 ? completedTasksCount / totalTasksCount : 0.0;

  DailyTaskSet copyWith({
    String? id,
    DateTime? date,
    List<DailyTask>? tasks,
    bool? isCompleted,
    int? totalXP,
  }) {
    return DailyTaskSet(
      id: id ?? this.id,
      date: date ?? this.date,
      tasks: tasks ?? this.tasks,
      isCompleted: isCompleted ?? this.isCompleted,
      totalXP: totalXP ?? this.totalXP,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'isCompleted': isCompleted,
      'totalXP': totalXP,
    };
  }

  factory DailyTaskSet.fromJson(Map<String, dynamic> json) {
    return DailyTaskSet(
      id: json['id'],
      date: DateTime.parse(json['date']),
      tasks: (json['tasks'] as List).map((taskJson) => DailyTask.fromJson(taskJson)).toList(),
      isCompleted: json['isCompleted'] ?? false,
      totalXP: json['totalXP'] ?? 0,
    );
  }
} 