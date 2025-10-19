import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/my_journey_page.dart';
import 'pages/daily_page.dart';
import 'pages/insight_page.dart';
import 'pages/reflection_page.dart';
import 'pages/me_page.dart';

import 'providers/nav_provider.dart';
import 'widgets/plus_panel.dart';

import 'pages/editors/goal_edit_page.dart';
import 'pages/editors/subgoal_edit_page.dart';
import 'pages/editors/task_edit_page.dart';
import 'pages/editors/dailylog_edit_page.dart';
import 'pages/editors/reflection_edit_page.dart';

class TargetNotebookApp extends StatelessWidget {
  const TargetNotebookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '目標手帳',
      // —— 最小主题同步（品牌色：靛蓝 0xFF3F51B5）——
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3F51B5),
        brightness: Brightness.light,
      ),
      // （可选）深色主题保持同一品牌色
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3F51B5),
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system, // 跟随系统（你也可以固定为 ThemeMode.light）
      home: const _HomeShell(),
      routes: {
        GoalEditPage.route: (_) => const GoalEditPage(),
        SubGoalEditPage.route: (_) => const SubGoalEditPage(),
        TaskEditPage.route: (_) => const TaskEditPage(),
        DailyLogEditPage.route: (_) => const DailyLogEditPage(),
        ReflectionEditPage.route: (_) => const ReflectionEditPage(),
      },
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell();

  static final _pages = <Widget>[
    const MyJourneyPage(),
    const DailyPage(),
    const InsightPage(),
    const ReflectionPage(),
    const MePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch (nav.index) {
            0 => 'My Journey',
            1 => 'Daily',
            2 => 'Insight',
            3 => 'Reflection',
            4 => 'Me',
            _ => '目標手帳',
          },
        ),
        centerTitle: false,
      ),
      body: IndexedStack(index: nav.index, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final action = await showModalBottomSheet<String>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            builder: (ctx) => const PlusPanel(),
          );
          switch (action) {
            case PlusPanel.addGoal:
              if (context.mounted) Navigator.of(context).pushNamed(GoalEditPage.route);
              break;
            case PlusPanel.addSubGoal:
              if (context.mounted) Navigator.of(context).pushNamed(SubGoalEditPage.route);
              break;
            case PlusPanel.addTask:
              if (context.mounted) Navigator.of(context).pushNamed(TaskEditPage.route);
              break;
            case PlusPanel.addDailyLog:
              if (context.mounted) Navigator.of(context).pushNamed(DailyLogEditPage.route);
              break;
            case PlusPanel.addReflection:
              if (context.mounted) Navigator.of(context).pushNamed(ReflectionEditPage.route);
              break;
            default:
              break;
          }
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: nav.index,
        onDestinationSelected: nav.setIndex,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'My Journey',
          ),
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Daily',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insight',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Reflection',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}

