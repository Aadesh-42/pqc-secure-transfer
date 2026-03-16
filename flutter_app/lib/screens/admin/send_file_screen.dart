import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../services/pqc_service.dart';
import '../../widgets/custom_button.dart';

class SendFileScreen extends StatefulWidget {
  const SendFileScreen({super.key});

  @override
  State<SendFileScreen> createState() => _SendFileScreenState();
}

class _SendFileScreenState extends State<SendFileScreen> {
  int _currentStep = 0;
  String? _fileName;
  Uint8List? _fileBytes;
  bool _isSending = false;
  
  // Hardcoded for dummy until we have a real users endpoint
  String _selectedEmployeeId = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';
  final List<Map<String, String>> _employees = [
    {'id': 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d', 'name': 'Employee 1'},
  ];

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null) {
      setState(() {
        _fileName = result.files.single.name;
        _fileBytes = result.files.single.bytes;
        _currentStep = 1;
      });
    }
  }

  Future<void> _handleSend() async {
    if (_fileBytes == null) return;
    
    setState(() => _isSending = true);
    
    try {
      final pqc = Provider.of<PqcService>(context, listen: false);
      final api = Provider.of<ApiService>(context, listen: false);

      // Step 2 & 3: Encrypt and Sign (Using pqc_service mock for now, 
      // but passing real base64 to backend later where the actual encryption logic resides in our backend design)
      // *Wait, the backend logic decrypts/encrypts ON the server based on requirements*
      // Let's send the raw base64 to the backend /files/send, as the backend pqc_service does the enc/sign.
      
      setState(() => _currentStep = 2); // Kyber 
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() => _currentStep = 3); // Dilithium
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() => _currentStep = 4); // Uploading
      
      final String fileB64 = base64Encode(_fileBytes!);
      
      // We pass the raw file to backend, backend does Kyber encap + Dilithium sign.
      final res = await api.sendFile({
        'sender_id': '00000000-0000-0000-0000-000000000000', // Mock Admin
        'receiver_id': _selectedEmployeeId,
        'file_bytes_b64': fileB64,
        'admin_private_key_b64': 'dummy_private_key', // Mocked, ideally from secure storage
      });

      if (res.statusCode == 200) {
        setState(() {
          _currentStep = 5; // Delivered
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File successfully encrypted and sent!')));
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer failed: $e')));
    } finally {
      setState(() => _isSending = false);
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
                  value: _selectedEmployeeId,
                  decoration: const InputDecoration(labelText: 'Recipient', border: OutlineInputBorder()),
                  items: _employees.map((e) => DropdownMenuItem(value: e['id'], child: Text(e['name']!))).toList(),
                  onChanged: (val) => setState(() => _selectedEmployeeId = val!),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.attach_file),
                    label: Text(_fileName ?? 'Choose File'),
                     onPressed: _pickFile,
                  ),
                )
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
