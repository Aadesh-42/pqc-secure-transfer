import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../services/api_service.dart';
import '../../models/task.dart';

class TaskManagementScreen extends StatefulWidget {
  const TaskManagementScreen({super.key});

  @override
  State<TaskManagementScreen> createState() => _TaskManagementScreenState();
}

class _TaskManagementScreenState extends State<TaskManagementScreen> {
  List<TaskModel> _tasks = [];
  List<Map<String, dynamic>> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadTasks(),
      _loadEmployees(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadTasks() async {
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

  Future<void> _loadEmployees() async {
    try {
      final res = await Provider.of<ApiService>(context, listen: false).getEmployees();
      if (res.statusCode == 200) {
        setState(() {
          _employees = List<Map<String, dynamic>>.from(res.data);
        });
      }
    } catch (e) {
      print('Failed to load employees: $e');
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

  String _getAssigneeEmail(String? id) {
    if (id == null) return 'Unassigned';
    final emp = _employees.firstWhere((e) => e['id'] == id, orElse: () => {});
    return emp['email'] ?? 'Unknown User';
  }

  void _showCreateTaskDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String priority = 'medium';
    String? assignedTo;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Create New Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Task Title')),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: priority,
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low Priority')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium Priority')),
                    DropdownMenuItem(value: 'high', child: Text('High Priority')),
                  ],
                  onChanged: (v) => setStateDialog(() => priority = v ?? 'medium'),
                  decoration: const InputDecoration(labelText: 'Priority'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: assignedTo,
                  hint: const Text('Select Employee'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Unassigned')),
                    ..._employees.map((e) => DropdownMenuItem(
                          value: e['id'] as String,
                          child: Text(e['email'] as String),
                        )),
                  ],
                  onChanged: (v) => setStateDialog(() => assignedTo = v),
                  decoration: const InputDecoration(labelText: 'Assign to Employee'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: () async {
                print("DEBUG [TaskDialog]: Create button clicked");
                if (titleCtrl.text.isEmpty) {
                  print("DEBUG [TaskDialog]: Title is empty, aborting");
                  return;
                }
                
                final api = Provider.of<ApiService>(context, listen: false);
                setState(() => _isLoading = true);
                print("DEBUG [TaskDialog]: Closing dialog and starting loading");
                Navigator.pop(ctx); 
                
                try {
                  final taskData = {
                    'title': titleCtrl.text,
                    'description': descCtrl.text,
                    'priority': priority,
                    'assigned_to': assignedTo, // Will be null if Unassigned
                    'status': 'pending',
                  };
                  print("DEBUG [TaskDialog]: Sending request to API: $taskData");
                  
                  final res = await api.createTask(taskData);
                  print("DEBUG [TaskDialog]: API Response Code: ${res.statusCode}");
                  print("DEBUG [TaskDialog]: API Response Body: ${res.data}");
                  
                  if (res.statusCode == 201 || res.statusCode == 200) {
                    print("DEBUG [TaskDialog]: Creation SUCCESS");
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Task created successfully!'))
                      );
                    }
                    print("DEBUG [TaskDialog]: Refreshing task list");
                    await _loadTasks();
                  } else {
                    print("DEBUG [TaskDialog]: Creation FAILED with code ${res.statusCode}");
                    setState(() => _isLoading = false);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Server Error: ${res.statusCode} - ${res.data}'))
                      );
                    }
                  }
                } on DioException catch (e) {
                  print("DEBUG [TaskDialog]: DIO ERROR: ${e.response?.statusCode}");
                  print("DEBUG [TaskDialog]: ERROR BODY: ${e.response?.data}");
                  final msg = e.response?.data['detail'] ?? e.message;
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('API Error: $msg'))
                    );
                    setState(() => _isLoading = false);
                  }
                } catch (e) {
                  print("DEBUG [TaskDialog]: GENERAL ERROR: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Unexpected Error: $e'))
                    );
                    setState(() => _isLoading = false);
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
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
              onRefresh: () async {
                await _loadTasks();
                await _loadEmployees();
              },
              child: _tasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.task_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          "No tasks yet. Click + to create one!",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        TextButton(
                          onPressed: _loadInitialData, 
                          child: const Text("Refresh")
                        )
                      ],
                    ),
                  )
                : ListView.builder(
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
                          subtitle: Text("Assignee: ${_getAssigneeEmail(task.assignedTo)} - Priority: ${task.priority}"),
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
