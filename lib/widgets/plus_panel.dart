import 'package:flutter/material.dart';

class PlusPanel extends StatelessWidget {
  const PlusPanel({super.key});

  static const addGoal = 'add_goal';
  static const addSubGoal = 'add_subgoal';
  static const addTask = 'add_task';
  static const addDailyLog = 'add_dailylog';
  static const addReflection = 'add_reflection';

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Add Goal', Icons.flag, addGoal),
      ('Add SubGoal', Icons.subdirectory_arrow_right, addSubGoal),
      ('Add Task', Icons.task_alt, addTask),
      ('Add Daily Log', Icons.schedule, addDailyLog),
      ('Add Reflection', Icons.edit_note, addReflection),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('快速添加', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...actions.map((a) => ListTile(
                  leading: Icon(a.$2),
                  title: Text(a.$1),
                  onTap: () => Navigator.of(context).pop(a.$3),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

