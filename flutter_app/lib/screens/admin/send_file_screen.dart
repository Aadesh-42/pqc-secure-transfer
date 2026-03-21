import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
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
    final api = Provider.of<ApiService>(context, listen: false);
    final auth = AuthService();
    
    try {
      final token = await auth.getToken();
      if (token == null) {
        throw Exception('You must be logged in (Token missing)');
      }
      print("DEBUG [SendFile]: Token found: ${token.substring(0, 10)}...");

      final currentUser = await auth.getCurrentUser();
      if (currentUser == null) {
        throw Exception('You must be logged in (User data missing)');
      }

      // STEP 1: Get Employee Public Key
      print("Step 1: Fetching employee public key");
      final keyRes = await api.getUserPublicKey(_selectedEmployeeId!).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception("Failed to fetch recipient public key (Timeout)")
      );
      final String employeePublicKey = keyRes.data['public_key'];
      print("Employee public key obtained: ${employeePublicKey.substring(0, 20)}...");

      // STEP 2: Encrypt with Kyber-768
      setState(() => _currentStep = 1); 
      print("Step 2: Starting Kyber encryption");
      print("File bytes length: ${_fileBytes!.length}");
      
      final String fileB64 = base64Encode(_fileBytes!);
      final encryptRes = await api.encryptFile({
        'file_bytes_b64': fileB64,
        'public_key': employeePublicKey,
      }).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception("Encryption timeout (Kyber-768 is computationally intensive)")
      );
      
      final String encryptedPayload = encryptRes.data['encrypted_payload'];
      final String kyberCiphertext = encryptRes.data['kyber_ciphertext'];
      print("Kyber encryption completed successfully");

      // STEP 3: Sign with Dilithium3
      setState(() => _currentStep = 2);
      print("Step 3: Signing with Dilithium3");
      
      // We need a private key for testing. In a real app, it might be in secure storage.
      // For now, we'll use a dummy key that the backend mock architecture handles.
      final signRes = await api.signFile({
        'encrypted_payload_b64': encryptedPayload,
        'private_key': "dummy_private_key_for_dilithium3",
      }).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception("Signing timeout")
      );
      
      final String signature = signRes.data['signature'];
      print("Dilithium signature generated");

      // STEP 4: Upload to Server
      setState(() => _currentStep = 3);
      print("Step 4: Uploading to server");
      
      final sendRes = await api.sendFile({
        'sender_id': currentUser.id,
        'receiver_id': _selectedEmployeeId,
        'encrypted_payload': encryptedPayload,
        'kyber_ciphertext': kyberCiphertext,
        'dilithium_signature': signature,
      });

      if (sendRes.statusCode == 200) {
        setState(() => _currentStep = 4);
        print("Step 5: File delivered successfully");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File successfully PQC-encrypted and sent!')));
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      print("PQC TRANSFER ERROR: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Transfer failed: $e'), duration: const Duration(seconds: 5)));
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
            title: const Text('Kyber-768 Encryption'),
            content: const LinearProgressIndicator(),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : _currentStep == 1 && _isSending ? StepState.editing : StepState.indexed,
          ),
          Step(
            title: const Text('Dilithium3 Digital Signature'),
            content: const LinearProgressIndicator(),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : _currentStep == 2 && _isSending ? StepState.editing : StepState.indexed,
          ),
          Step(
            title: const Text('Quantum-Safe Transmission'),
            content: const LinearProgressIndicator(),
            isActive: _currentStep >= 3,
            state: _currentStep > 3 ? StepState.complete : _currentStep == 3 && _isSending ? StepState.editing : StepState.indexed,
          ),
          Step(
            title: const Text('Delivered Securely'),
            content: const Text('The file is encrypted with post-quantum algorithms and stored safely.'),
            isActive: _currentStep >= 4,
            state: _currentStep >= 4 ? StepState.complete : StepState.indexed,
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CustomButton(
          text: 'Initiate PQC Transfer',
          isLoading: _isSending,
          onPressed: _fileBytes != null && !_isSending && _selectedEmployeeId != null ? _handleSend : null,
        ),
      ),
    );
  }
}
