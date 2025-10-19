import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../adapters/dailylog_adapter.dart';

class ReflectionPage extends StatelessWidget {
  const ReflectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final reflections = context.select(
      (DailyLogAdapter a) => a.latestReflections(),
    );

    if (reflections.isEmpty) {
      return const Center(
        child: Text(
          '还没有反思日记，试着在 Daily 页面写下一条吧！',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (ctx, i) {
        final r = reflections[i];
        return Card(
          elevation: 0,
          color: Theme.of(context)
              .colorScheme
              .surfaceVariant
              .withOpacity(0.5),
          child: ListTile(
            title: Text(
              r.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              DateFormat('yyyy-MM-dd (EEE)').format(r.date),
            ),
            leading: const Icon(Icons.bookmark_border),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: reflections.length,
    );
  }
}

