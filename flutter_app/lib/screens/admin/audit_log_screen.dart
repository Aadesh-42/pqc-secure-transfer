import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final res = await Provider.of<ApiService>(context, listen: false).getAuditLogs();
      if (res.statusCode == 200) {
        setState(() {
          _logs = res.data;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load audit logs: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null) return 'Unknown';
    try {
      final d = DateTime.parse(isoDate).toLocal();
      return "${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return isoDate;
    }
  }

  String _getDisplayEmail(dynamic log) {
    // Try users join first, fall back to truncated user_id
    final usersData = log['users'];
    if (usersData != null && usersData['email'] != null) {
      return usersData['email'];
    }
    final uid = log['user_id']?.toString() ?? 'Unknown';
    return uid.length > 8 ? uid.substring(0, 8) + '...' : uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _logs.isEmpty
          ? const Center(child: Text('No audit logs found'))
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: ListView.separated(
                itemCount: _logs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blueGrey,
                      child: Icon(Icons.verified_user, color: Colors.white, size: 20),
                    ),
                    title: Text("${log['action']} by ${_getDisplayEmail(log)}"),
                    subtitle: Text("IP: ${log['ip_address'] ?? 'Unknown'}"),
                    trailing: Text(
                      _formatDate(log['timestamp']),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
