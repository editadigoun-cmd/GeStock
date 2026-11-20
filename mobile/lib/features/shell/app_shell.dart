import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;
  int _index(String path) => path.startsWith('/inventory') || path.startsWith('/products') ? 1 : path.startsWith('/sales') ? 2 : path.startsWith('/businesses') ? 3 : path.startsWith('/customers') ? 4 : path.startsWith('/suppliers') ? 5 : path.startsWith('/purchases') ? 6 : path.startsWith('/expenses') ? 7 : 0;
  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index(path),
        onDestinationSelected: (i) => context.go(['/home', '/inventory', '/sales', '/businesses', '/customers', '/suppliers', '/purchases', '/expenses'][i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Stock'),
          NavigationDestination(icon: Icon(Icons.point_of_sale_rounded), label: 'Ventes'),
          NavigationDestination(icon: Icon(Icons.storefront_outlined), label: 'Entreprise'),
        NavigationDestination(icon: Icon(Icons.people_alt_outlined), label: 'Clients'),
          NavigationDestination(icon: Icon(Icons.local_shipping_outlined), label: 'Fournisseurs'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), label: 'Achats'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Dépenses'),
        ],
      ),
    );
  }
}
