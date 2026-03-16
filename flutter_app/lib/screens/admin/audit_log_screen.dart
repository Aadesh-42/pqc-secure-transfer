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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load audit logs: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      return "${d.month}/${d.day}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs'), actions: [
        IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
      ]),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
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
                  title: Text("${log['action']} by user ${log['user_id']?.substring(0, 8) ?? 'Unknown'}"),
                  subtitle: Text("IP: ${log['ip_address'] ?? 'Unknown'}"),
                  trailing: Text(_formatDate(log['timestamp']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                );
              },
            ),
          ),
    );
  }
}
