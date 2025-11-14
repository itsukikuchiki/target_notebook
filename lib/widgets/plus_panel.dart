import 'package:flutter/material.dart';

class PlusPanel extends StatelessWidget {
  const PlusPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SquareButton(
          icon: Icons.note_add,
          label: '快速日志',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _DummyPage(title: 'Quick Log')),
          ),
        ),
        _SquareButton(
          icon: Icons.timer,
          label: '计时器',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const _DummyPage(title: 'Timer')),
          ),
        ),
      ],
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SquareButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceVariant,
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _DummyPage extends StatelessWidget {
  final String title;
  const _DummyPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(title)));
  }
}

