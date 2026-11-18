import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/business/business_setup_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/products/products_screen.dart';
import '../features/sales/sales_screen.dart';
import '../features/shell/app_shell.dart';
import '../theme/gestock_theme.dart';
final appRouterProvider = Provider<GoRouter>((ref) => GoRouter(
  initialLocation: '/sign-in',
  routes: [
    GoRoute(path: '/sign-in', builder: (_, __) => const SignInScreen()),
    GoRoute(path: '/business/setup', builder: (_, __) => const BusinessSetupScreen()),
    ShellRoute(builder: (_, __, child) => AppShell(child: child), routes: [
      GoRoute(path: '/home', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
      GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
      GoRoute(path: '/sales', builder: (_, __) => const SalesScreen()),
    ]),
  ],
));
class GeStockApp extends ConsumerWidget {
  const GeStockApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'GeStock', debugShowCheckedModeBanner: false,
    theme: GeStockTheme.light, darkTheme: GeStockTheme.dark,
    themeMode: ThemeMode.system, routerConfig: ref.watch(appRouterProvider),
  );
}
