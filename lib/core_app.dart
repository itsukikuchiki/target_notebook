import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/hive_init.dart';
import 'providers/goal_provider.dart' as goals;   // 👈 别名
import 'providers/task_provider.dart' as tasks;   // 👈 别名
import 'providers/daily_log_provider.dart' as logs;
import 'main_screen.dart';

class CoreApp extends StatelessWidget {
  const CoreApp({super.key});

  Future<void> _startup(BuildContext context) async {
    await initHive();
    await context.read<goals.GoalProvider>().init();
    await context.read<tasks.TaskProvider>().init();
    await context.read<logs.DailyLogProvider>().init();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => goals.GoalProvider()),
        ChangeNotifierProvider(create: (_) => tasks.TaskProvider()),
        ChangeNotifierProvider(create: (_) => logs.DailyLogProvider()),
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

