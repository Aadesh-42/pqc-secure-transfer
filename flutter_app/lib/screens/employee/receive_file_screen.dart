import 'package:flutter/material.dart';

class ReceiveFileScreen extends StatefulWidget {
  const ReceiveFileScreen({super.key});

  @override
  State<ReceiveFileScreen> createState() => _ReceiveFileScreenState();
}

class _ReceiveFileScreenState extends State<ReceiveFileScreen> {
  final Map<String, dynamic> _file = {
    'id': 'file-123',
    'sender': 'Admin',
    'date': 'Oct 25, 2026',
    'status': 'pending', // pending, confirmed, decrypted
  };
  bool _isDecrypting = false;
  String? _decryptedText;

  void _confirmReceipt() async {
    // API call to POST /files/{id}/confirm
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt confirmed. Ready to decrypt.')));
    setState(() => _file['status'] = 'confirmed');
  }

  void _decryptFile() async {
    setState(() => _isDecrypting = true);
    
    // Simulate Kyber decapsulation & AES decryption flow
    await Future.delayed(const Duration(seconds: 2));
    
    setState(() {
      _isDecrypting = false;
      _file['status'] = 'decrypted';
      _decryptedText = "Confidential Q1 Earnings Data: \nRevenue: \$1M\nGrowth: 40%\n[This highly sensitive data was decrypted safely via Kyber+Dilithium!]";
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File successfully decrypted locally!')));
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
                icon: const Icon(Icons.check),
                label: const Text('CONFIRM RECEIPT'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: _confirmReceipt,
              ),
            if (_file['status'] == 'confirmed')
              ElevatedButton.icon(
                icon: _isDecrypting ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.key),
                label: Text(_isDecrypting ? 'DECRYPTING...' : 'DECRYPT FILE'),
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
