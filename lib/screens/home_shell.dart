import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/counter_provider.dart';
import 'counter_screen.dart';
import 'history_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for navigation requests from history (e.g. tapping a saved image).
    final counterProvider = context.read<CounterProvider>();
    counterProvider.removeListener(_onCounterProviderChanged);
    counterProvider.addListener(_onCounterProviderChanged);
  }

  @override
  void dispose() {
    context.read<CounterProvider>().removeListener(_onCounterProviderChanged);
    super.dispose();
  }

  void _onCounterProviderChanged() {
    final provider = context.read<CounterProvider>();
    if (provider.pendingCounterNav) {
      provider.consumeCounterNav();
      if (mounted) setState(() => _index = 0);
    }
  }

  static const _titles = ['Home', 'History'];
  static const _screens = [CounterScreen(), HistoryScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 0)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Detection settings',
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const SettingsSheet(),
                );
              },
            ),
        ],
      ),
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
