import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

class ReceiveFileScreen extends StatefulWidget {
  const ReceiveFileScreen({super.key});

  @override
  State<ReceiveFileScreen> createState() => _ReceiveFileScreenState();
}

class _ReceiveFileScreenState extends State<ReceiveFileScreen> {
  List<Map<String, dynamic>> _files = [];
  bool _isLoading = true;
  bool _isDecrypting = false;
  bool _isConfirming = false;
  String? _decryptedText;
  String? _activeFileId;

  @override
  void initState() {
    super.initState();
    _fetchFiles();
  }

  Future<void> _fetchFiles() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final auth = AuthService();
      final user = await auth.getCurrentUser();
      if (user == null) return;

      final res = await api.getReceivedFiles(user.id);
      if (res.statusCode == 200) {
        setState(() {
          _files = List<Map<String, dynamic>>.from(res.data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to fetch files: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmReceipt(String fileId) async {
    setState(() {
      _isConfirming = true;
      _activeFileId = fileId;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final auth = AuthService();
      final user = await auth.getCurrentUser();
      if (user == null) return;

      await api.confirmFile(fileId, user.id);
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt confirmed. Ready to decrypt.')));
      _fetchFiles();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to confirm receipt: $e')));
    } finally {
      setState(() => _isConfirming = false);
    }
  }

  Future<void> _decryptFile(Map<String, dynamic> file) async {
    setState(() {
      _isDecrypting = true;
      _activeFileId = file['id'];
    });
    
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      
      // We pass dummy keys for now as they are handled in backend pqc_service mock
      final res = await api.decryptFile(file['id'], {
        'receiver_private_key_b64': 'mock_kyber_private_key',
        'admin_public_key_b64': 'mock_dilithium_public_key',
      });
      
      if (res.statusCode == 200) {
        setState(() {
          _decryptedText = utf8.decode(base64Decode(res.data['file_bytes_b64']));
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File decrypted successfully!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to decrypt file: $e')));
    } finally {
      setState(() => _isDecrypting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encrypted Inbox')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? const Center(child: Text('No secure files found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final isSelected = _activeFileId == file['id'];

                    return Card(
                      elevation: isSelected ? 8 : 2,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.insert_drive_file, size: 32, color: Colors.blueGrey),
                                Icon(file['status'] == 'decrypted' ? Icons.lock_open : Icons.lock, color: Colors.amber),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('Secure File: ${file['id'].toString().substring(0, 8)}...', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Status: ${file['status'].toUpperCase()}', 
                              style: TextStyle(color: file['status'] == 'pending' ? Colors.orange : Colors.green, fontWeight: FontWeight.bold)),
                            
                            const SizedBox(height: 16),
                            if (file['status'] == 'pending')
                              ElevatedButton(
                                onPressed: _isConfirming ? null : () => _confirmReceipt(file['id']),
                                child: _isConfirming && isSelected ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('CONFIRM RECEIPT'),
                              ),
                            if (file['status'] == 'confirmed')
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                                onPressed: _isDecrypting ? null : () => _decryptFile(file),
                                child: _isDecrypting && isSelected ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('DECRYPT FILE'),
                              ),
                            if (file['status'] == 'decrypted' && isSelected && _decryptedText != null)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                                child: Text(_decryptedText!, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
