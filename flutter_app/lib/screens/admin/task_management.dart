import 'package:flutter/material.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  final List<Map<String, dynamic>> _tasks = [
    {'title': 'Review Q1 Report', 'assignee': 'Employee 1', 'status': 'pending', 'priority': 'high'},
    {'title': 'Update Security Policies', 'assignee': 'Employee 2', 'status': 'completed', 'priority': 'medium'},
  ];

  void _showCreateTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(decoration: InputDecoration(labelText: 'Task Title')),
            DropdownButtonFormField<String>(
              value: 'Employee 1',
              items: const [
                DropdownMenuItem(value: 'Employee 1', child: Text('Employee 1')),
                DropdownMenuItem(value: 'Employee 2', child: Text('Employee 2')),
              ],
              onChanged: (v) {},
              decoration: const InputDecoration(labelText: 'Assign To'),
            ),
            DropdownButtonFormField<String>(
              value: 'medium',
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                DropdownMenuItem(value: 'medium', child: Text('Medium Priority')),
                DropdownMenuItem(value: 'high', child: Text('High Priority')),
              ],
              onChanged: (v) {},
              decoration: const InputDecoration(labelText: 'Priority'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _tasks.add({'title': 'New Task', 'assignee': 'Employee 1', 'status': 'pending', 'priority': 'medium'});
              });
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Management')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(
                task['status'] == 'completed' ? Icons.check_circle : Icons.radio_button_unchecked,
                color: task['status'] == 'completed' ? Colors.green : Colors.grey,
              ),
              title: Text(task['title']),
              subtitle: Text("Assigned to: ${task['assignee']} • Priority: ${task['priority']}"),
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  setState(() => task['status'] = val);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'pending', child: Text('Mark Pending')),
                  PopupMenuItem(value: 'completed', child: Text('Mark Completed')),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
