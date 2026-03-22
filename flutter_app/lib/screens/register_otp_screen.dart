import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';

class RegisterOtpScreen extends StatefulWidget {
  const RegisterOtpScreen({super.key});

  @override
  State<RegisterOtpScreen> createState() => _RegisterOtpScreenState();
}

class _RegisterOtpScreenState extends State<RegisterOtpScreen> {
  final _otpCtrl = TextEditingController();
  bool _isLoading = false;
  String _email = '';
  Timer? _resendTimer;
  int _secondsRemaining = 60;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() => _email = args['email'] ?? '');
      }
      _startTimer();
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _secondsRemaining = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _handleResend() async {
    // Resend is handled by going back and submitting again.
    // For simplicity, pop back so they can re-enter their info.
    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleVerify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit OTP')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.verifyRegistration({
        'email': _email,
        'otp_code': otp,
      });

      if (res.statusCode == 200) {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.check_circle, color: Colors.green, size: 56),
              title: const Text('Account Created!', textAlign: TextAlign.center),
              content: const Text(
                'Your account has been created successfully.\nYou can now log in.',
                textAlign: TextAlign.center,
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Go to Login', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } on DioException catch (e) {
      final msg = e.response?.data['detail'] ?? 'Verification failed';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              const Text(
                'Verify Your Email',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a 6-digit code to\n$_email',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 8),
                decoration: const InputDecoration(
                  labelText: 'OTP Code',
                  hintText: '- - - - - -',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify & Activate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: _secondsRemaining == 0 ? _handleResend : null,
                child: Text(
                  _secondsRemaining > 0
                    ? 'Resend OTP in ${_secondsRemaining}s'
                    : 'Resend OTP',
                  style: TextStyle(
                    color: _secondsRemaining == 0 ? Colors.blueAccent : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Wrong email? ', style: TextStyle(color: Colors.grey)),
                  GestureDetector(
                    onTap: () => Navigator.popUntil(context, ModalRoute.withName('/login')),
                    child: const Text(
                      'Back to Login',
                      style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
