import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_providers.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/admin/admin_terminal.dart';
import 'presentation/staff/staff_dashboard.dart';
import 'presentation/warehouse/warehouse_dashboard.dart';

class TelecallerApp extends ConsumerWidget {
  const TelecallerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final activeUser = ref.watch(activeUserProvider);

    return MaterialApp(
      title: 'HT TELECALING',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: activeUser == null
          ? const LoginScreen()
          : (activeUser.role == 'admin'
              ? const AdminTerminal()
              : (activeUser.role == 'warehouse'
                  ? const WarehouseDashboard()
                  : const StaffDashboard())),
    );
  }
}
