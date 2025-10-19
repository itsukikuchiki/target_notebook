import 'package:flutter/material.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text('Itsuki Yang'),
            subtitle: Text('Premium'),
          ),
        ),
        SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text('Theme（占位）'),
            subtitle: Text('Material 3 · Seed Color'),
          ),
        ),
        SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(Icons.cloud_outlined),
            title: Text('Sync（占位）'),
            subtitle: Text('iCloud / Firebase / Notion'),
          ),
        ),
      ],
    );
  }
}

