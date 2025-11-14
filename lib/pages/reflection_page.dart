import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../adapters/dailylog_adapter.dart';

class ReflectionPage extends StatelessWidget {
  const ReflectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final adapter = context.watch<DailyLogAdapter>();
    final items = adapter.latestReflections(limit: 20);

    return Scaffold(
      appBar: AppBar(title: const Text('Reflection')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemBuilder: (_, i) {
          final r = items[i];
          return ListTile(
            title: Text(r.content.isEmpty ? '(无内容)' : r.content),
            subtitle: Text('${r.date.toLocal()} • ${r.minutes} 分钟'),
            leading: const Icon(Icons.notes),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: items.length,
      ),
    );
  }
}

