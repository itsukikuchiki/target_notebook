import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/hive_init.dart';
import 'providers/goal_provider.dart';
import 'providers/task_provider.dart';
import 'main_screen.dart';

class CoreApp extends StatelessWidget {
  const CoreApp({super.key});

  Future<void> _startup(BuildContext context) async {
    await initHive();
    await context.read<GoalProvider>().init();
    await context.read<TaskProvider>().init();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: MaterialApp(
        title: '目標手帳',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: Builder(
          builder: (context) {
            return FutureBuilder(
              future: _startup(context),
              builder: (c, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return const MainScreen();
              },
            );
          },
        ),
      ),
    );
  }
}

