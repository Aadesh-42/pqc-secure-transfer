mport 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/task.dart';

class TaskChecklistScreen extends StatefulWidget {
  const TaskChecklistScreen({super.key});

  @override
  State<TaskChecklistScreen> createState() => _TaskChecklistScreenState();
}

class _TaskChecklistScreenState extends State<TaskChecklistScreen> {
  List<TaskModel> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await api.getTasks();
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

  Color _getPriorityColor(String p) {
    if (p == 'high') return Colors.red;
    if (p == 'medium') return Colors.orange;
    return Colors.green;
  }

  Future<void> _toggleTask(int index, bool? val) async {
    final task = _tasks[index];
    final bool isCompleted = val ?? false;
    final newStatus = isCompleted ? 'completed' : 'pending';
    
    // Optimistic UI update
    setState(() {
      _tasks[index] = TaskModel(
        id: task.id, title: task.title, description: task.description,
        assignedTo: task.assignedTo, priority: task.priority,
        dueDate: task.dueDate, createdAt: task.createdAt,
        status: newStatus,
      );
    });

    try {
      final res = await Provider.of<ApiService>(context, listen: false).updateTask(task.id, {'status': newStatus});
      if (res.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Task marked as $newStatus')));
      }
    } catch (e) {
      // Revert if failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update task: $e')));
        setState(() {
           _tasks[index] = task; // Revert to old state
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Checklist')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadTasks,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final t = _tasks[index];
                final isCompleted = t.status == 'completed';
                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: CheckboxListTile(
                    value: isCompleted,
                    onChanged: (val) => _toggleTask(index, val),
                    title: Text(
                      t.title,
                      style: TextStyle(
                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                        fontWeight: isCompleted ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Icon(Icons.circle, size: 10, color: _getPriorityColor(t.priority)),
                        const SizedBox(width: 4),
                        Text("${t.priority.toUpperCase()} - Due: ${t.dueDate != null ? t.dueDate.toString().split(' ')[0] : 'None'}"),
                      ],
                    ),
                    secondary: const Icon(Icons.assignment_turned_in, color: Colors.blueGrey),
                  ),
                );
              },
            ),
          ),
    );
  }
}
