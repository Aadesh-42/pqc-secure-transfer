import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';

class TaskChecklistScreen extends StatefulWidget {
  const TaskChecklistScreen({super.key});

  @override
  State<TaskChecklistScreen> createState() => _TaskChecklistScreenState();
}

class _TaskChecklistScreenState extends State<TaskChecklistScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    print("DEBUG [Checklist]: Starting _loadTasks");
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final response = await api.getTasks();
      
      print("DEBUG [Checklist]: Status Code: ${response.statusCode}");
      print("DEBUG [Checklist]: Data: ${response.data}");

      setState(() {
        if (response.data is List) {
          _tasks = List<Map<String, dynamic>>.from(response.data);
          print("DEBUG [Checklist]: Parsed ${_tasks.length} tasks");
        } else {
          print("DEBUG [Checklist]: Data is NOT a list");
          _tasks = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      print("DEBUG [Checklist]: ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tasks: $e'))
        );
      }
      setState(() {
        _tasks = [];
        _isLoading = false;
      });
    }
  }

  Color _getPriorityColor(String? p) {
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
      _tasks[index]['status'] = newStatus;
    });

    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.updateTask(task['id'], {'status': newStatus});
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Task marked as $newStatus'))
          );
        }
      }
    } catch (e) {
      print("DEBUG [Checklist]: Update Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update task: $e'))
        );
        // Revert on error
        setState(() {
           _tasks[index]['status'] = isCompleted ? 'pending' : 'completed';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Checklist'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _tasks.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No tasks assigned yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: _loadTasks,
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadTasks,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _tasks.length,
                  itemBuilder: (context, index) {
                    final t = _tasks[index];
                    final isCompleted = t['status'] == 'completed';
                    final priority = t['priority']?.toString().toLowerCase() ?? 'medium';
                    final dueDate = t['due_date']?.toString().split(' ')[0] ?? 'None';

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: _getPriorityColor(priority).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isCompleted,
                        onChanged: (val) => _toggleTask(index, val),
                        activeColor: Colors.green,
                        title: Text(
                          t['title'] ?? 'Untitled Task',
                          style: TextStyle(
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            fontWeight: isCompleted ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _getPriorityColor(priority),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "${priority.toUpperCase()} • Due: $dueDate",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        secondary: Icon(
                          Icons.assignment_outlined, 
                          color: isCompleted ? Colors.grey : Colors.blueGrey
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
