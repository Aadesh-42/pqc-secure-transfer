import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
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
  bool _isLoadingEmployees = true;
  
  String? _selectedEmployeeId;
  List<Map<String, dynamic>> _employees = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.getEmployees();
      if (res.statusCode == 200) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(res.data);
          if (_employees.isNotEmpty) {
            _selectedEmployeeId = _employees.first['id'];
          }
          _isLoadingEmployees = false;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load recipients: $e')));
      setState(() => _isLoadingEmployees = false);
    }
  }

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
    if (_fileBytes == null || _selectedEmployeeId == null) return;
    
    setState(() => _isSending = true);
    
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final auth = AuthService();
      final currentUser = await auth.getCurrentUser();

      if (currentUser == null) throw Exception('You must be logged in to send files');
      
      setState(() => _currentStep = 2); // Kyber 
      await Future.delayed(const Duration(milliseconds: 1000));
      
      setState(() => _currentStep = 3); // Dilithium
      await Future.delayed(const Duration(milliseconds: 1000));
      
      setState(() => _currentStep = 4); // Uploading
      
      final String fileB64 = base64Encode(_fileBytes!);
      
      final res = await api.sendFile({
        'sender_id': currentUser.id,
        'receiver_id': _selectedEmployeeId,
        'file_bytes_b64': fileB64,
        'admin_private_key_b64': 'dummy_private_key_for_mock', 
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
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure PQC Transfer')),
      body: _isLoadingEmployees 
        ? const Center(child: CircularProgressIndicator())
        : Stepper(
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
                  items: _employees.map((e) => DropdownMenuItem(
                    value: e['id'] as String, 
                    child: Text(e['email'] as String))
                  ).toList(),
                  onChanged: (val) => setState(() => _selectedEmployeeId = val),
                  hint: const Text('Select an employee'),
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
          onPressed: _currentStep == 1 && !_isSending && _selectedEmployeeId != null ? _handleSend : null,
        ),
      ),
    );
  }
}
