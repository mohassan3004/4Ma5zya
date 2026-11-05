import 'package:flutter/material.dart';

import '../widgets/mini_player.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'voices_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  static void switchTab(BuildContext context, int index) {
    context.findAncestorStateOfType<_HomeShellState>()?.select(index);
  }

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), LibraryScreen(), VoicesScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: select,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
              NavigationDestination(
                  icon: Icon(Icons.library_books_outlined), selectedIcon: Icon(Icons.library_books), label: 'مكتبتي'),
              NavigationDestination(
                  icon: Icon(Icons.record_voice_over_outlined),
                  selectedIcon: Icon(Icons.record_voice_over),
                  label: 'أصواتي'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
            ],
          ),
        ],
      ),
    );
  }
}
