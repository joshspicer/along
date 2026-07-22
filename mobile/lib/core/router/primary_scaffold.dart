import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../platform/haptics.dart';

class PrimaryScaffold extends StatelessWidget {
  const PrimaryScaffold({
    required this.location,
    required this.child,
    super.key,
  });

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final index = location.startsWith('/look-back') ? 1 : 0;
    return Scaffold(
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (selected) {
          if (selected == index) {
            return;
          }
          AlongHaptics.selection();
          context.go(selected == 0 ? '/focus' : '/look-back');
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Look back',
          ),
        ],
      ),
    );
  }
}
