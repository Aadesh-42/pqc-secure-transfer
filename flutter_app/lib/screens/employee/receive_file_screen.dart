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
  bool _isRegenerating = false;
  String? _decryptedText;
  String? _activeFileId;
  String? _localKyberPrivateKey;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final auth = AuthService();
    _localKyberPrivateKey = await auth.getKyberPrivateKey();
    _fetchFiles();
  }

  Future<void> _fetchFiles() async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.getReceivedFiles();
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

  Future<void> _regenerateKeys() async {
    setState(() => _isRegenerating = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final auth = AuthService();
      final res = await api.regenerateKeys();
      
      if (res.statusCode == 200) {
        final String privKey = res.data['kyber_private_key'];
        await auth.saveKyberPrivateKey(privKey);
        setState(() {
          _localKyberPrivateKey = privKey;
          _isRegenerating = false;
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post-Quantum keys regenerated and stored locally.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Key regeneration failed: $e')));
      setState(() => _isRegenerating = false);
    }
  }

  Future<void> _confirmReceipt(String fileId) async {
    setState(() {
      _isConfirming = true;
      _activeFileId = fileId;
    });
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.confirmFile(fileId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt confirmed. Ready to decrypt.')));
      _fetchFiles();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to confirm receipt: $e')));
    } finally {
      setState(() => _isConfirming = false);
    }
  }

  Future<void> _decryptFile(Map<String, dynamic> file) async {
    if (_localKyberPrivateKey == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local private key missing. Please regenerate keys.')));
      return;
    }

    setState(() {
      _isDecrypting = true;
      _activeFileId = file['id'];
      _decryptedText = null;
    });
    
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      
      // The backend needs the receiver's private key and the sender's (admin) public key
      // For now, admin public key is assumed known by backend or provided as a static mock identifier
      final res = await api.decryptFile(file['id'], {
        'receiver_private_key_b64': _localKyberPrivateKey,
        'admin_public_key_b64': 'admin_dilithium_public_key_standard',
      });
      
      if (res.statusCode == 200) {
        setState(() {
          _decryptedText = utf8.decode(base64Decode(res.data['file_bytes_b64']));
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File decrypted successfully!')));
      }
    } catch (e) {
      print("DECRYPTION ERROR: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Decryption failed: $e')));
    } finally {
      setState(() => _isDecrypting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Secure Inbox'),
        actions: [
          IconButton(
            icon: _isRegenerating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.vpn_key),
            onPressed: _isRegenerating ? null : _regenerateKeys,
            tooltip: 'Regenerate PQC Keys',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchFiles,
              child: _files.isEmpty
              ? const Center(child: Text('No secure files found.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _files.length,
                  itemBuilder: (context, index) {
                    final file = _files[index];
                    final isSelected = _activeFileId == file['id'];
                    final status = file['status'] as String;

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
                                Row(
                                  children: [
                                    const Icon(Icons.description, size: 28, color: Colors.blueAccent),
                                    const SizedBox(width: 12),
                                    Text('File #${file['id'].toString().substring(0, 6)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                _statusBadge(status),
                              ],
                            ),
                            const Divider(height: 24),
                            
                            if (status == 'pending')
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline),
                                label: _isConfirming && isSelected ? const Text('Confirming...') : const Text('CONFIRM RECEIPT'),
                                onPressed: _isConfirming ? null : () => _confirmReceipt(file['id']),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                              ),
                            
                            if (status == 'confirmed')
                              Column(
                                children: [
                                  if (_localKyberPrivateKey == null)
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 8.0),
                                      child: Text('⚠️ Local PQC key missing. Regenerate keys above to decrypt.', style: TextStyle(color: Colors.red, fontSize: 12)),
                                    ),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.enhanced_encryption),
                                    label: _isDecrypting && isSelected ? const Text('Decrypting...') : const Text('DECRYPT WITH PQC'),
                                    onPressed: _isDecrypting || _localKyberPrivateKey == null ? null : () => _decryptFile(file),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                                  ),
                                ],
                              ),
                            
                            if (_decryptedText != null && isSelected)
                              Container(
                                margin: const EdgeInsets.only(top: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade200)
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Decrypted Content:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                    const SizedBox(height: 8),
                                    Text(_decryptedText!, style: const TextStyle(fontFamily: 'monospace')),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ),
    );
  }

  Widget _statusBadge(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'pending': color = Colors.orange; icon = Icons.timer; break;
      case 'confirmed': color = Colors.blue; icon = Icons.verified; break;
      case 'decrypted': color = Colors.green; icon = Icons.lock_open; break;
      default: color = Colors.grey; icon = Icons.help_outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
