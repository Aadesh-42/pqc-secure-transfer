import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/pqc_service.dart';

import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/admin/send_file_screen.dart';
import 'screens/admin/task_management.dart';
import 'screens/admin/audit_log_screen.dart';
import 'screens/employee/employee_dashboard.dart';
import 'screens/employee/receive_file_screen.dart';
import 'screens/employee/task_checklist.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<ApiService>(create: (_) => ApiService()),
        Provider<PqcService>(create: (_) => PqcService()),
      ],
      child: const PQCSecureApp(),
    ),
  );
}

class PQCSecureApp extends StatelessWidget {
  const PQCSecureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PQC Secure Transfer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.blueAccent,
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueAccent,
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/admin_dashboard': (context) => const AdminDashboard(),
        '/send_file': (context) => const SendFileScreen(),
        '/task_management': (context) => const TaskManagementScreen(),
        '/audit_logs': (context) => const AuditLogScreen(),
        '/employee_dashboard': (context) => const EmployeeDashboard(),
        '/receive_file': (context) => const ReceiveFileScreen(),
        '/task_checklist': (context) => const TaskChecklistScreen(),
        '/chat': (context) => const ChatScreen(),
      },
    );
  }
}
