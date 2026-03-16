import 'package:flutter/material.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy logs
    final logs = [
      {'user': 'Admin', 'action': 'send_file', 'ip': '192.168.1.1', 'time': '10 minutes ago'},
      {'user': 'Employee 1', 'action': 'decrypt_file', 'ip': '10.0.0.5', 'time': '1 hour ago'},
      {'user': 'System', 'action': 'kyber_key_gen', 'ip': 'localhost', 'time': '2 hours ago'},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Logs'), actions: [
        IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
      ]),
      body: ListView.separated(
        itemCount: logs.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final log = logs[index];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueGrey,
              child: Icon(Icons.verified_user, color: Colors.white, size: 20),
            ),
            title: Text("${log['action']} by ${log['user']}"),
            subtitle: Text("IP: ${log['ip']}"),
            trailing: Text(log['time']!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          );
        },
      ),
    );
  }
}
