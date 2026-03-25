import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    
    try {
      final token = await authService.getToken();
      if (token == null) {
        Navigator.pushReplacementNamed(context, "/login");
        return;
      }

      print("DEBUG [Splash]: Token found, validating...");
      final api = Provider.of<ApiService>(context, listen: false);
      
      // Attempt a simple authenticated call to verify the token
      final response = await api.getTasks().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception("Validation Timeout")
      );

      if (response.statusCode == 200) {
        final role = await authService.getRole();
        print("DEBUG [Splash]: Token valid. Role: $role");
        
        if (mounted) {
          if (role == "admin") {
            Navigator.pushReplacementNamed(context, "/admin_dashboard");
          } else {
            Navigator.pushReplacementNamed(context, "/employee_dashboard");
          }
        }
      } else {
        throw Exception("Invalid token status");
      }
    } catch (e) {
      print("DEBUG [Splash]: Validation failed ($e). Clearing session.");
      await authService.logout();
      if (mounted) Navigator.pushReplacementNamed(context, "/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 24),
            Text(
              'PQC Secure',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quantum-Safe Transfer',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
