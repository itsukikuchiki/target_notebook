import 'package:hive/hive.dart';

part 'task.g.dart';

@HiveType(typeId: 4)
class Task extends HiveObject {
  // ====== Core ======

  @HiveField(0)
  String title;

  /// 备注 / 备忘录（兼容你原来的 note）
  @HiveField(1)
  String? note;

  /// 关联目标（为空=普通日程）
  @HiveField(2)
  int? goalId;

  /// 关联子目标（为空=直接挂在 goal 下，或普通日程）
  @HiveField(3)
  int? subGoalId;

  /// 开始时间（为空表示未安排）
  @HiveField(4)
  DateTime? startAt;

  /// 结束时间（为空表示未知/全日/仅开始）
  @HiveField(5)
  DateTime? endAt;

  /// 是否完成（基础逻辑：done=true 即完成）
  @HiveField(6)
  bool done;

  /// 今日三件事（Pinned）
  @HiveField(7)
  bool isTodayTop3;

  // ====== W5 Additions (append-only for Hive safety) ======

  /// 12/11：优先度（1最高～5）
  @HiveField(8)
  int priority;

  /// 12/14：是否全日
  @HiveField(9)
  bool isAllDay;

  /// 12/14：地点
  @HiveField(10)
  String? location;

  /// 12/14：参与者邮箱（建议先用逗号分隔字符串，避免 Hive List<String> 的类型坑）
  /// 例如："a@a.com,b@b.com"
  @HiveField(11)
  String? participantEmailsRaw;

  /// 12/14：提醒开关
  @HiveField(12)
  bool hasAlarm;

  /// 12/14：提醒时间
  @HiveField(13)
  DateTime? alarmAt;

  /// 12/14：图标 key（如 "briefcase" / "study" / "heart" 等）
  @HiveField(14)
  String? iconKey;

  /// 12/14：完成度（0.0 ~ 1.0），done=true 时可视为 1.0
  @HiveField(15)
  double completion;

  /// 12/14：deadline（与 dueDate 概念一致，但属于 task 层）
  @HiveField(16)
  DateTime? deadline;

  /// 12/14：照片路径（本地 path 或 URL）
  @HiveField(17)
  String? photoPath;

  /// 12/15：任务颜色（可选）
  /// - 若 goalId != null，通常用 Goal.color（本字段可不用/可覆盖）
  /// - 若普通日程，可用默认色或用户选择色
  @HiveField(18)
  int? color;

  Task({
    required this.title,
    this.note,
    this.goalId,
    this.subGoalId,
    this.startAt,
    this.endAt,
    this.done = false,
    this.isTodayTop3 = false,

    // new
    this.priority = 3,
    this.isAllDay = false,
    this.location,
    this.participantEmailsRaw,
    this.hasAlarm = false,
    this.alarmAt,
    this.iconKey,
    this.completion = 0.0,
    this.deadline,
    this.photoPath,
    this.color,
  });

  // ====== Convenience getters (non-persisted) ======

  /// 参与者列表（从 participantEmailsRaw 拆分）
  List<String> get participantEmails {
    final raw = participantEmailsRaw?.trim();
    if (raw == null || raw.isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  set participantEmails(List<String> emails) {
    participantEmailsRaw = emails.map((e) => e.trim()).where((e) => e.isNotEmpty).join(',');
  }

  /// 用于日历显示的“日期归属”（优先 startAt，其次 deadline）
  DateTime? get dateAnchor => startAt ?? deadline;

  /// 统一完成度（done 优先）
  double get effectiveCompletion => done ? 1.0 : completion.clamp(0.0, 1.0);

  // ====== JSON (import/export) ======

  Map<String, dynamic> toMap() => {
        'title': title,
        'note': note,
        'goalId': goalId,
        'subGoalId': subGoalId,
        'startAt': startAt?.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
        'done': done,
        'isTodayTop3': isTodayTop3,

        // new
        'priority': priority,
        'isAllDay': isAllDay,
        'location': location,
        'participantEmailsRaw': participantEmailsRaw,
        'hasAlarm': hasAlarm,
        'alarmAt': alarmAt?.toIso8601String(),
        'iconKey': iconKey,
        'completion': completion,
        'deadline': deadline?.toIso8601String(),
        'photoPath': photoPath,
        'color': color,
      };

  static Task fromMap(Map<String, dynamic> m) => Task(
        title: m['title'] as String,
        note: m['note'] as String?,
        goalId: m['goalId'] as int?,
        subGoalId: m['subGoalId'] as int?,
        startAt: (m['startAt'] as String?) != null
            ? DateTime.parse(m['startAt'] as String)
            : null,
        endAt: (m['endAt'] as String?) != null
            ? DateTime.parse(m['endAt'] as String)
            : null,
        done: (m['done'] as bool?) ?? false,
        isTodayTop3: (m['isTodayTop3'] as bool?) ?? false,

        // new
        priority: (m['priority'] as int?) ?? 3,
        isAllDay: (m['isAllDay'] as bool?) ?? false,
        location: m['location'] as String?,
        participantEmailsRaw: m['participantEmailsRaw'] as String?,
        hasAlarm: (m['hasAlarm'] as bool?) ?? false,
        alarmAt: (m['alarmAt'] as String?) != null
            ? DateTime.parse(m['alarmAt'] as String)
            : null,
        iconKey: m['iconKey'] as String?,
        completion: (m['completion'] as num?)?.toDouble() ?? 0.0,
        deadline: (m['deadline'] as String?) != null
            ? DateTime.parse(m['deadline'] as String)
            : null,
        photoPath: m['photoPath'] as String?,
        color: m['color'] as int?,
      );
}


