import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _mfaCtrl = TextEditingController();

  bool _isLoading = false;
  bool _showMfa = false;
  
  Timer? _resendTimer;
  int _secondsRemaining = 0;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _mfaCtrl.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _secondsRemaining = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _resendTimer?.cancel();
        }
      });
    });
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      final res = await api.login({
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
      });

      if (res.statusCode == 200) {
        setState(() {
          _showMfa = true;
        });
        _startResendTimer();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP sent to your email.')));
      }
    } on DioException catch (e) {
      final msg = e.response?.data['detail'] ?? 'Invalid credentials';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMfaVerify() async {
    final body = {
      "email": _emailCtrl.text.trim().toLowerCase(),
      "otp_code": _mfaCtrl.text.trim()
    };
    print("SENDING VERIFY: $body");
    
    final apiService = Provider.of<ApiService>(context, listen: false);
    final storage = Provider.of<AuthService>(context, listen: false);

    try {
      final response = await apiService.verifyMfa(body);
      print("VERIFY RESPONSE: ${response.statusCode}");
      print("VERIFY BODY: ${response.data}");
      
      final role = response.data["role"];
      final token = response.data["access_token"];
      final userId = response.data["user_id"];
      final email = _emailCtrl.text.trim().toLowerCase();
      
      await storage.saveToken(token); 
      await storage.saveUserId(userId);
      await storage.saveRole(role);
      await storage.saveEmail(email);
      
      print("DEBUG [Login]: Saved User $userId with role $role");
      
      if (mounted) {
        if (role == "admin") {
          Navigator.pushReplacementNamed(context, "/admin_dashboard");
        } else {
          Navigator.pushReplacementNamed(context, "/employee_dashboard");
        }
      }
    } catch (e) {
      print("VERIFY ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("OTP Failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 32),
              Text(
                _showMfa ? 'Check your email!' : 'Welcome Back',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (_showMfa) ...[
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to ${_emailCtrl.text.trim()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
              const SizedBox(height: 32),
              
              if (!_showMfa) ...[
                CustomTextField(
                  label: 'Email',
                  hint: 'Enter your email',
                  controller: _emailCtrl,
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
                CustomTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordCtrl,
                  prefixIcon: Icons.lock,
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Login',
                  isLoading: _isLoading,
                  onPressed: _handleLogin,
                ),
              ] else ...[
                CustomTextField(
                  label: 'OTP Code',
                  hint: 'Enter 6-digit code',
                  controller: _mfaCtrl,
                  prefixIcon: Icons.security,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Verify OTP',
                  isLoading: _isLoading,
                  onPressed: _handleMfaVerify,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _secondsRemaining == 0 ? _handleLogin : null,
                  child: Text(
                    _secondsRemaining > 0 
                      ? 'Resend OTP in ${_secondsRemaining}s' 
                      : 'Resend OTP',
                    style: TextStyle(
                      color: _secondsRemaining == 0 ? Colors.blueAccent : Colors.grey,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
