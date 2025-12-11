import 'package:flutter/material.dart';

import '../pages/editors/goal_edit_page.dart';
import '../pages/editors/task_edit_page.dart';
import '../pages/editors/reflection_edit_page.dart';

/// Plus 面板：提供三个入口
/// - Add Goal
/// - Add Task
/// - Add Reflection
///
/// 被 TargetNotebookApp 和 plus_panel_test 使用。
class PlusPanel extends StatelessWidget {
  const PlusPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Wrap(
          spacing: 24,
          runSpacing: 24,
          alignment: WrapAlignment.center,
          children: [
            _SquareButton(
              icon: Icons.flag_outlined,
              label: 'Add Goal', // 🔑 测试通过 plusTile('Add Goal') 查找
              color: colorScheme.primaryContainer,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GoalEditPage(),
                  ),
                );
              },
            ),
            _SquareButton(
              icon: Icons.checklist,
              label: 'Add Task', // 🔑 plusTile('Add Task')
              color: colorScheme.secondaryContainer,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TaskEditPage(),
                  ),
                );
              },
            ),
            _SquareButton(
              icon: Icons.edit_note,
              label: 'Add Reflection', // 🔑 plusTile('Add Reflection')
              color: colorScheme.tertiaryContainer,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReflectionEditPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SquareButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onColor = Theme.of(context).colorScheme.onPrimaryContainer;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          width: 140,
          height: 140,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: onColor),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: onColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

