import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  int _index(String path) => path.startsWith('/inventory') || path.startsWith('/products') ? 1 : path.startsWith('/sales') ? 2 : path.startsWith('/customers') ? 3 : path.startsWith('/more') || path.startsWith('/sync') || path.startsWith('/businesses') || path.startsWith('/suppliers') || path.startsWith('/purchases') || path.startsWith('/expenses') ? 4 : 0;
  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index(path),
        onDestinationSelected: (i) => context.go(['/home', '/inventory', '/sales', '/customers', '/more'][i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Stock'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_rounded), label: 'Ventes'),
          NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'Clients'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Plus'),
        ],
      ),
    );
  }
}
