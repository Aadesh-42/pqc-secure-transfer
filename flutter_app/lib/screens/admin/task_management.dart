import 'package:flutter/material.dart';
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
                  hint: const Text('Select Assignee'),
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
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final api = Provider.of<ApiService>(context, listen: false);
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                try {
                  final res = await api.createTask({
                    'title': titleCtrl.text,
                    'description': descCtrl.text,
                    'priority': priority,
                    'assigned_to': assignedTo,
                  });
                  if (res.statusCode == 201 || res.statusCode == 200) {
                    await _loadTasks();
                  } else {
                     setState(() => _isLoading = false);
                  }
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create task: $e')));
                  setState(() => _isLoading = false);
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
