import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/breakpoints.dart';

class HomeShell extends StatelessWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  static const _destinations = [
    (path: '/dashboard', label: 'Início', icon: Icons.dashboard_outlined, selected: Icons.dashboard),
    (path: '/pedidos', label: 'Pedidos', icon: Icons.assignment_outlined, selected: Icons.assignment),
    (path: '/agenda', label: 'Agenda', icon: Icons.calendar_month_outlined, selected: Icons.calendar_month),
    (path: '/clientes', label: 'Clientes', icon: Icons.people_outline, selected: Icons.people),
    (path: '/configuracoes', label: 'Ajustes', icon: Icons.settings_outlined, selected: Icons.settings),
  ];

  int _indexOf(String location) {
    for (var i = 0; i < _destinations.length; i++) {
      if (location.startsWith(_destinations[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexOf(location);
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.compact;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              labelType: NavigationRailLabelType.all,
              groupAlignment: -0.9,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.print_outlined,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Baray',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
              onDestinationSelected: (i) => context.go(_destinations[i].path),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
        onDestinationSelected: (i) => context.go(_destinations[i].path),
      ),
    );
  }
}