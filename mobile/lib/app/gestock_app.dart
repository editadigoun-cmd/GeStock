import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/business/business_setup_screen.dart';
import '../features/business/businesses_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/inventory/inventory_screen.dart';
import '../features/inventory/inventory_count_screen.dart';
import '../features/inventory/transfers_screen.dart';
import '../features/products/products_screen.dart';
import '../features/sales/sales_screen.dart';
import '../features/customers/customers_screen.dart';
import '../features/suppliers/suppliers_screen.dart';
import '../features/purchases/purchases_screen.dart';
import '../features/expenses/expenses_screen.dart';
import '../features/cash/cash_screen.dart';
import '../features/employees/employees_screen.dart';
import '../features/reports/reports_screen.dart';
import '../features/shell/more_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/shell/sync_status_screen.dart';
import '../features/shell/support_screen.dart';
import '../theme/gestock_theme.dart';

final appRouterProvider = Provider<GoRouter>((ref) => GoRouter(
  initialLocation: '/sign-in',
  routes: [
    GoRoute(path: '/sign-in', builder: (_, __) => const SignInScreen()),
    GoRoute(path: '/business/setup', builder: (_, __) => const BusinessSetupScreen()),
    ShellRoute(builder: (_, __, child) => AppShell(child: child), routes: [
      GoRoute(path: '/home', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/more', builder: (_, __) => const MoreScreen()),
      GoRoute(path: '/sync', builder: (_, __) => const SyncStatusScreen()),
      GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
      GoRoute(path: '/inventory', builder: (_, __) => const InventoryScreen()),
      GoRoute(path: '/inventory-count', builder: (_, __) => const InventoryCountScreen()),
      GoRoute(path: '/transfers', builder: (_, __) => const TransfersScreen()),
      GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
      GoRoute(path: '/sales', builder: (_, __) => const SalesScreen()),
      GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
      GoRoute(path: '/suppliers', builder: (_, __) => const SuppliersScreen()),
      GoRoute(path: '/purchases', builder: (_, __) => const PurchasesScreen()),
      GoRoute(path: '/expenses', builder: (_, __) => const ExpensesScreen()),
      GoRoute(path: '/cash', builder: (_, __) => const CashScreen()),
      GoRoute(path: '/employees', builder: (_, __) => const EmployeesScreen()),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/businesses', builder: (_, __) => const BusinessesScreen()),
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
