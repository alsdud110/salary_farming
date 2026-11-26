import 'package:flutter/material.dart';

import '../app_store.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      // 탭을 옮길 때마다 새로 그려서 결산이 항상 지금 시각 기준이 되게 한다.
      body: switch (_index) {
        0 => HomeScreen(store: store),
        1 => StatsScreen(store: store),
        _ => SettingsScreen(store: store),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grass_outlined),
            selectedIcon: Icon(Icons.grass),
            label: '오늘',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '결산',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
