import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class ReceiveFileScreen extends StatefulWidget {
  const ReceiveFileScreen({super.key});

  @override
  State<ReceiveFileScreen> createState() => _ReceiveFileScreenState();
}

class _ReceiveFileScreenState extends State<ReceiveFileScreen> {
  // In a real scenario we'd query /files/pending for the user. 
  // Let's mock the file object for scaffolding that backend would return
  final Map<String, dynamic> _file = {
    'id': 'file-1234-5678', // mock id
    'sender': 'Admin',
    'date': 'Today',
    'status': 'pending', // pending, confirmed, decrypted
  };
  bool _isDecrypting = false;
  bool _isConfirming = false;
  String? _decryptedText;

  Future<void> _confirmReceipt() async {
    setState(() => _isConfirming = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      // Wait for dummy ID logic or actual ID if we fetched a list
      // final res = await api.confirmFile(_file['id']);
      // Simulate backend delay for scaffolding
      await Future.delayed(const Duration(seconds: 1));
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt confirmed. Ready to decrypt.')));
      setState(() => _file['status'] = 'confirmed');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to confirm receipt: $e')));
    } finally {
      setState(() => _isConfirming = false);
    }
  }

  Future<void> _decryptFile() async {
    setState(() => _isDecrypting = true);
    
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      /*
      Actual Call:
      final res = await api.decryptFile(_file['id'], {
        'receiver_private_key_b64': 'mock_kyber_private',
        'admin_public_key_b64': 'mock_dilithium_public',
      });
      _decryptedText = utf8.decode(base64Decode(res.data['file_bytes_b64']));
      */
      
      // Simulate backend delay for scaffolding
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _file['status'] = 'decrypted';
        _decryptedText = "Confidential Q1 Earnings Data: \nRevenue: \$1M\nGrowth: 40%\n[This highly sensitive data was decrypted safely via Kyber+Dilithium!]";
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File signature verified and decrypted locally!')));
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.insert_drive_file, size: 40, color: Colors.blueGrey),
                        Icon(Icons.lock, color: Colors.amber),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Incoming Secure Transfer', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('From: ${_file['sender']}'),
                    Text('Date: ${_file['date']}'),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _file['status'] == 'pending' ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Status: ${_file['status'].toUpperCase()}',
                        style: TextStyle(
                          color: _file['status'] == 'pending' ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_file['status'] == 'pending')
              ElevatedButton.icon(
                icon: _isConfirming ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
                label: const Text('CONFIRM RECEIPT'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: _isConfirming ? null : _confirmReceipt,
              ),
            if (_file['status'] == 'confirmed')
              ElevatedButton.icon(
                icon: _isDecrypting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.key),
                label: Text(_isDecrypting ? 'VERIFYING & DECRYPTING...' : 'DECRYPT FILE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: _isDecrypting ? null : _decryptFile,
              ),
            if (_file['status'] == 'decrypted' && _decryptedText != null)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _decryptedText!,
                      style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
