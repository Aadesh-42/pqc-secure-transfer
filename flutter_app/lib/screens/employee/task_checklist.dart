import 'package:flutter/material.dart';

class TaskChecklistScreen extends StatefulWidget {
  const TaskChecklistScreen({super.key});

  @override
  State<TaskChecklistScreen> createState() => _TaskChecklistScreenState();
}

class _TaskChecklistScreenState extends State<TaskChecklistScreen> {
  final List<Map<String, dynamic>> _tasks = [
    {'title': 'Review Q1 Report', 'due': 'Tomorrow', 'priority': 'high', 'completed': false},
    {'title': 'Submit Timecard', 'due': 'End of Week', 'priority': 'medium', 'completed': true},
    {'title': 'Complete Security Training', 'due': 'Next Monday', 'priority': 'high', 'completed': false},
  ];

  Color _getPriorityColor(String p) {
    if (p == 'high') return Colors.red;
    if (p == 'medium') return Colors.orange;
    return Colors.green;
  }

  void _toggleTask(int index, bool? val) {
    setState(() {
      _tasks[index]['completed'] = val ?? false;
    });
    // In real app, call PATCH /tasks/{id}/status
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tasks[index]['completed'] ? 'Task marked as completed' : 'Task marked as pending')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Checklist')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final t = _tasks[index];
          return Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 12),
            child: CheckboxListTile(
              value: t['completed'],
              onChanged: (val) => _toggleTask(index, val),
              title: Text(
                t['title'],
                style: TextStyle(
                  decoration: t['completed'] ? TextDecoration.lineThrough : null,
                  fontWeight: t['completed'] ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Row(
                children: [
                  Icon(Icons.circle, size: 10, color: _getPriorityColor(t['priority'])),
                  const SizedBox(width: 4),
                  Text("${t['priority'].toUpperCase()} • Due: ${t['due']}"),
                ],
              ),
              secondary: const Icon(Icons.assignment_turned_in, color: Colors.blueGrey),
            ),
          );
        },
      ),
    );
  }
}
