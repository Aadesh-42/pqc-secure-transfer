import 'package:flutter/material.dart';
import '../../widgets/custom_button.dart';
import 'package:file_picker/file_picker.dart';

class SendFileScreen extends StatefulWidget {
  const SendFileScreen({super.key});

  @override
  State<SendFileScreen> createState() => _SendFileScreenState();
}

class _SendFileScreenState extends State<SendFileScreen> {
  int _currentStep = 0;
  String? _fileName;
  bool _isSending = false;
  String _selectedEmployee = 'Employee 1';

  final List<String> _employees = ['Employee 1', 'Employee 2', 'Employee 3'];

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _fileName = result.files.single.name;
        _currentStep = 1;
      });
    }
  }

  Future<void> _handleSend() async {
    if (_fileName == null) return;
    
    setState(() => _isSending = true);
    
    // Simulate Step 2: Kyber-768 Encryption
    setState(() => _currentStep = 2);
    await Future.delayed(const Duration(seconds: 1));
    
    // Simulate Step 3: Dilithium3 Signing
    setState(() => _currentStep = 3);
    await Future.delayed(const Duration(seconds: 1));
    
    // Simulate Step 4: Uploading
    setState(() => _currentStep = 4);
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _currentStep = 5;
      _isSending = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File successfully encrypted and sent!')),
      );
      // Wait a moment then close
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure PQC Transfer')),
      body: Stepper(
        currentStep: _currentStep < 5 ? _currentStep : 4,
        controlsBuilder: (context, details) => const SizedBox.shrink(),
        physics: const ClampingScrollPhysics(),
        steps: [
          Step(
            title: const Text('Select Recipient & File'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedEmployee,
                  decoration: const InputDecoration(labelText: 'Recipient', border: OutlineInputBorder()),
                  items: _employees.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (val) => setState(() => _selectedEmployee = val!),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: _fileName ?? 'Choose File',
                  icon: Icons.attach_file,
                  onPressed: _pickFile,
                ),
              ],
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
          ),
          Step(
            title: const Text('Encrypting with Kyber-768'),
            content: const LinearProgressIndicator(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : _currentStep == 1 && _isSending ? StepState.editing : StepState.indexed,
          ),
          Step(
            title: const Text('Signing with Dilithium3'),
            content: const LinearProgressIndicator(),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : _currentStep == 2 ? StepState.editing : StepState.indexed,
          ),
          Step(
            title: const Text('Uploading to Server'),
            content: const LinearProgressIndicator(),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : _currentStep == 3 ? StepState.editing : StepState.indexed,
          ),
          Step(
            title: const Text('File Delivered & Waiting Confirmation'),
            content: const Text('The file is securely resting on the server.'),
            isActive: _currentStep >= 4,
            state: _currentStep >= 5 ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CustomButton(
          text: 'Send File Safely',
          isLoading: _isSending,
          onPressed: _currentStep == 1 && !_isSending ? _handleSend : null,
        ),
      ),
    );
  }
}

// Temporary override for CustomButton to support icons in this file
// if CustomButton doesn't have an icon parameter natively.
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        icon: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon ?? Icons.check),
        label: Text(text),
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
