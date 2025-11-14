import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'providers/task_provider.dart';
import 'providers/daily_log_provider.dart';
import 'providers/goal_provider.dart';
import 'adapters/dailylog_adapter.dart';
import 'pages/daily_page.dart';
import 'pages/insight_page.dart';
import 'pages/reflection_page.dart';
import 'widgets/plus_panel.dart';

class CoreApp extends StatefulWidget {
  const CoreApp({super.key});

  @override
  State<CoreApp> createState() => _CoreAppState();
}

class _CoreAppState extends State<CoreApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    final tp = TaskProvider();
    final dp = DailyLogProvider();
    final gp = GoalProvider();

    await tp.init();
    await dp.init();
    await gp.init();

    setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => DailyLogProvider()),
        ChangeNotifierProvider(create: (context) {
          final dp = context.read<DailyLogProvider>();
          return DailyLogAdapter(dp);
        }),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
      ],
      child: MaterialApp(
        title: 'Target Notebook',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
        ),
        home: const _MainScaffold(),
      ),
    );
  }
}

class _MainScaffold extends StatefulWidget {
  const _MainScaffold();

  @override
  State<_MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<_MainScaffold> {
  int _index = 0;
  final _pages = const [
    DailyPage(),
    InsightPage(),
    ReflectionPage(),
    PlusPanel(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calendar_today), label: 'Daily'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Insight'),
          NavigationDestination(icon: Icon(Icons.book), label: 'Reflection'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Plus'),
        ],
        onDestinationSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

