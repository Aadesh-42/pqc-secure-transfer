import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_textfield.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  
  String _selectedRole = "employee";
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain an uppercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain a number';
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return 'Must contain a special character';
    return null;
  }

  Future<void> _register() async {
    print("=== REGISTER DEBUG ===");
    print("First: ${_firstNameCtrl.text}");
    print("Last: ${_lastNameCtrl.text}");
    print("Email: ${_emailCtrl.text}");
    print("Password length: ${_passwordCtrl.text.length}");
    
    if (!_formKey.currentState!.validate()) {
      print("Form validation failed!");
      return;
    }
    print("Form valid! Proceeding...");
    
    setState(() => _isLoading = true);
    
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      
      print("Calling register API...");
      final response = await api.registerRequest({
        "first_name": _firstNameCtrl.text,
        "last_name": _lastNameCtrl.text,
        "email": _emailCtrl.text.trim().toLowerCase(),
        "password": _passwordCtrl.text,
        "role": "employee"
      });
      
      print("Response: ${response.statusCode}");
      print("Body: ${response.data}");
      
      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/register-otp',
            arguments: {
              'email': _emailCtrl.text.trim().toLowerCase()
            }
          );
        }
      }
    } catch (e) {
      print("Register error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: Colors.red,
          content: Text("Error: ${e.toString()}")
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 24),
                CustomTextField(
                  label: 'First Name',
                  hint: 'Enter first name',
                  controller: _firstNameCtrl,
                  prefixIcon: Icons.person,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                CustomTextField(
                  label: 'Last Name',
                  hint: 'Enter last name',
                  controller: _lastNameCtrl,
                  prefixIcon: Icons.person_outline,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                CustomTextField(
                  label: 'Email',
                  hint: 'Enter email address',
                  controller: _emailCtrl,
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                CustomTextField(
                  label: 'Password',
                  hint: 'Min 8 chars, 1 Upper, 1 Special',
                  controller: _passwordCtrl,
                  prefixIcon: Icons.lock,
                  obscureText: true,
                  validator: _validatePassword,
                ),
                CustomTextField(
                  label: 'Confirm Password',
                  hint: 'Re-enter password',
                  controller: _confirmPasswordCtrl,
                  prefixIcon: Icons.lock_clock,
                  obscureText: true,
                  validator: (v) => v != _passwordCtrl.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Create Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
