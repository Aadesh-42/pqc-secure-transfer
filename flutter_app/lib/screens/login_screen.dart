import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  String _userId = '';

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
          _userId = res.data['user_id'];
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credentials verified. Enter MFA code.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid credentials')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleMfaVerify() async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);

    try {
      final res = await api.verifyMfa({
        'user_id': _userId,
        'code': _mfaCtrl.text.trim(),
      });

      if (res.statusCode == 200) {
        final token = res.data['access_token'];
        await auth.saveToken(token);
        
        // In a real app, query user profile here. For now, decode token or derive.
        // Let's assume the dummy role logic for routing
        final isEmployee = _emailCtrl.text.contains("employee");
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            isEmployee ? '/employee_dashboard' : '/admin_dashboard',
          );
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid MFA code')));
    } finally {
      setState(() => _isLoading = false);
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
                'Welcome Back',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
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
                  label: 'MFA Code',
                  hint: 'Enter 6-digit TOTP code',
                  controller: _mfaCtrl,
                  prefixIcon: Icons.security,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Verify MFA',
                  isLoading: _isLoading,
                  onPressed: _handleMfaVerify,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
