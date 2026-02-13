import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/my_journey_page.dart';
import 'pages/daily_page.dart';
import 'pages/insight_page.dart';
import 'pages/reflection_page.dart';
import 'pages/me_page.dart';

import 'pages/editors/task_edit_page.dart';
import 'pages/editors/subgoal_edit_page.dart';
import 'pages/editors/goal_edit_page.dart';

import 'providers/nav_provider.dart';

class TargetNotebookApp extends StatelessWidget {
  const TargetNotebookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Target Notebook',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      routes: {
        TaskEditPage.route: (_) => const TaskEditPage(),
        SubGoalEditPage.route: (_) => const SubGoalEditPage(),
        GoalEditPage.route: (_) => const GoalEditPage(),
      },
      home: const _MainScaffold(),
    );
  }
}

class _MainScaffold extends StatefulWidget {
  const _MainScaffold();

  @override
  State<_MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<_MainScaffold> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;

    // ✅ 读取上次保存的 tab index
    // 不阻塞 UI；加载完成后 provider 自己会 notify（你 setIndex 里 notify 了，但 load 里目前没有）
    // 所以这里 load 后我们 setState 触发一次刷新更稳。
    final nav = context.read<NavProvider>();
    nav.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavProvider>();

    final pages = const [
      MyJourneyPage(), // 0
      DailyPage(), // 1
      InsightPage(), // 2
      ReflectionPage(), // 3
      MePage(), // 4
    ];

    final idx = nav.index.clamp(0, pages.length - 1);

    return Scaffold(
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,

        // ✅ 修复：Future<void> -> void Function(int)
        onDestinationSelected: (i) {
          nav.setIndex(i);
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.flag),
            label: 'Journey',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_today),
            label: 'Daily',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Insight',
          ),
          NavigationDestination(
            icon: Icon(Icons.book),
            label: 'Reflection',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

