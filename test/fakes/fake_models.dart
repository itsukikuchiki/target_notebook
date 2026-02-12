import 'package:flutter/material.dart';

class FakeGoal {
  final int key;
  final String title;
  final int priority;
  final int? color; // ARGB int
  FakeGoal({
    required this.key,
    required this.title,
    this.priority = 3,
    this.color,
  });
}

class FakeSubGoal {
  final int key;
  final int goalId;
  final String title;
  final int? color;
  FakeSubGoal({
    required this.key,
    required this.goalId,
    required this.title,
    this.color,
  });
}

class FakeTask {
  final int key;
  final String title;
  final int priority;
  final bool done;
  final int? goalId;
  final int? subGoalId;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime? deadline;
  final int? color; // ARGB int
  FakeTask({
    required this.key,
    required this.title,
    this.priority = 3,
    this.done = false,
    this.goalId,
    this.subGoalId,
    this.startAt,
    this.endAt,
    this.deadline,
    this.color,
  });
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

