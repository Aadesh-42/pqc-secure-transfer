mport 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/task.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  List<TaskModel> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final res = await Provider.of<ApiService>(context, listen: false).getTasks();
      if (res.statusCode == 200) {
        setState(() {
          _tasks = (res.data as List).map((t) => TaskModel.fromJson(t)).toList();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load tasks: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTaskStatus(String id, String newStatus) async {
    try {
      final res = await Provider.of<ApiService>(context, listen: false).updateTask(id, {'status': newStatus});
      if (res.statusCode == 200) {
        _loadTasks();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
    }
  }

  void _showCreateTaskDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'medium';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Task Title')),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
            DropdownButtonFormField<String>(
              value: priority,
              items: const [
                DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                DropdownMenuItem(value: 'medium', child: Text('Medium Priority')),
                DropdownMenuItem(value: 'high', child: Text('High Priority')),
              ],
              onChanged: (v) => priority = v ?? 'medium',
              decoration: const InputDecoration(labelText: 'Priority'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await Provider.of<ApiService>(context, listen: false).createTask({
                  'title': titleCtrl.text,
                  'description': descCtrl.text,
                  'priority': priority,
                });
                _loadTasks();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create task: $e')));
                setState(() => _isLoading = false);
              }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(
                        task.status == 'completed' ? Icons.check_circle : Icons.radio_button_unchecked,
                        color: task.status == 'completed' ? Colors.green : Colors.grey,
                      ),
                      title: Text(task.title),
                      subtitle: Text("Assignee: ${task.assignedTo ?? 'Unassigned'} - Priority: ${task.priority}"),
                      trailing: PopupMenuButton<String>(
                        onSelected: (val) => _updateTaskStatus(task.id, val),
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'pending', child: Text('Mark Pending')),
                          PopupMenuItem(value: 'completed', child: Text('Mark Completed')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
