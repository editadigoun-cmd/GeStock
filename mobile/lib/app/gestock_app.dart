import 'package:flutter/material.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../theme/gestock_theme.dart';

class GeStockApp extends StatelessWidget {
  const GeStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeStock',
      debugShowCheckedModeBanner: false,
      theme: GeStockTheme.light,
      darkTheme: GeStockTheme.dark,
      themeMode: ThemeMode.system,
      home: const DashboardScreen(),
    );
  }
}
