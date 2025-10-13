import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  final _pages = const [
    _JourneyPage(),
    _DailyPage(),
    _InsightPage(),
    _ReflectionPage(),
    _MePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.route), label: 'My Journey'),
          NavigationDestination(icon: Icon(Icons.today), label: 'Daily'),
          NavigationDestination(icon: Icon(Icons.auto_graph), label: 'Insight'),
          NavigationDestination(icon: Icon(Icons.self_improvement), label: 'Reflection'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Me'),
        ],
      ),
    );
  }
}

class _JourneyPage extends StatelessWidget {
  const _JourneyPage();
  @override
  Widget build(BuildContext context) => const _Stub(title: 'My Journey');
}

class _DailyPage extends StatelessWidget {
  const _DailyPage();
  @override
  Widget build(BuildContext context) => const _Stub(title: 'Daily');
}

class _InsightPage extends StatelessWidget {
  const _InsightPage();
  @override
  Widget build(BuildContext context) => const _Stub(title: 'Insight');
}

class _ReflectionPage extends StatelessWidget {
  const _ReflectionPage();
  @override
  Widget build(BuildContext context) => const _Stub(title: 'Reflection');
}

class _MePage extends StatelessWidget {
  const _MePage();
  @override
  Widget build(BuildContext context) => const _Stub(title: 'Me');
}

class _Stub extends StatelessWidget {
  final String title;
  const _Stub({required this.title});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}

