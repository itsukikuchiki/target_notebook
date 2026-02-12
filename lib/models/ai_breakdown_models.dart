// lib/models/ai_breakdown_models.dart
import 'dart:convert';

class AiBreakdownResult {
  final List<AiSubGoalDraft> subGoals;

  AiBreakdownResult({required this.subGoals});

  factory AiBreakdownResult.empty() => AiBreakdownResult(subGoals: []);

  Map<String, dynamic> toJson() => {
        'subGoals': subGoals.map((e) => e.toJson()).toList(),
      };

  factory AiBreakdownResult.fromJson(Map<String, dynamic> json) {
    final list = (json['subGoals'] as List<dynamic>? ?? [])
        .map((e) => AiSubGoalDraft.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return AiBreakdownResult(subGoals: list);
  }

  /// 容错：有些返回会把 JSON 包在字符串里
  static AiBreakdownResult tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return AiBreakdownResult.empty();

    dynamic data;
    try {
      data = jsonDecode(text);
    } catch (_) {
      // 尝试从文本中截取第一段 {...}
      final start = text.indexOf('{');
      final end = text.lastIndexOf('}');
      if (start >= 0 && end > start) {
        final sliced = text.substring(start, end + 1);
        data = jsonDecode(sliced);
      } else {
        rethrow;
      }
    }
    return AiBreakdownResult.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

class AiSubGoalDraft {
  String title;
  String? description;
  String? why;
  int estimateDays;
  int priority; // 1~5
  List<AiTaskDraft> tasks;

  AiSubGoalDraft({
    required this.title,
    this.description,
    this.why,
    this.estimateDays = 7,
    this.priority = 3,
    List<AiTaskDraft>? tasks,
  }) : tasks = tasks ?? [];

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'why': why,
        'estimateDays': estimateDays,
        'priority': priority,
        'tasks': tasks.map((e) => e.toJson()).toList(),
      };

  factory AiSubGoalDraft.fromJson(Map<String, dynamic> json) {
    return AiSubGoalDraft(
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : '子目标',
      description: (json['description'] as String?)?.trim(),
      why: (json['why'] as String?)?.trim(),
      estimateDays: (json['estimateDays'] as num?)?.toInt() ?? 7,
      priority: _clampInt((json['priority'] as num?)?.toInt() ?? 3, 1, 5),
      tasks: (json['tasks'] as List<dynamic>? ?? [])
          .map((e) => AiTaskDraft.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class AiTaskDraft {
  String title;
  int minutes; // 15~240
  int dueInDays; // >=0
  int priority; // 1~5
  String? note;

  AiTaskDraft({
    required this.title,
    this.minutes = 45,
    this.dueInDays = 2,
    this.priority = 3,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'minutes': minutes,
        'dueInDays': dueInDays,
        'priority': priority,
        'note': note,
      };

  factory AiTaskDraft.fromJson(Map<String, dynamic> json) {
    return AiTaskDraft(
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String).trim()
          : '任务',
      minutes: _clampInt((json['minutes'] as num?)?.toInt() ?? 45, 15, 240),
      dueInDays: ((json['dueInDays'] as num?)?.toInt() ?? 2).clamp(0, 3650),
      priority: _clampInt((json['priority'] as num?)?.toInt() ?? 3, 1, 5),
      note: (json['note'] as String?)?.trim(),
    );
  }
}

int _clampInt(int v, int min, int max) => v < min ? min : (v > max ? max : v);

