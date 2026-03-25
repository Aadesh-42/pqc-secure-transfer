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
  List<Task> _tasks = [];
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
          _tasks = (res.data as List).map((t) => Task.fromJson(t)).toList();
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

  Future<void> _updateTask(String id, String newStatus) async {
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
    String selectedPriority = 'medium';
    String? selectedEmployee;

    showDialog(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)
        ),
        child: Container(
          width: MediaQuery.of(context)
            .size.width * 0.9,
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: 
                CrossAxisAlignment.start,
              children: [
                Text(
                  "Create New Task",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white
                  )
                ),
                SizedBox(height: 20),
                
                TextField(
                  controller: titleCtrl,
                  style: TextStyle(
                    color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Task Title",
                    labelStyle: TextStyle(
                      color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: 
                        BorderRadius.circular(8)
                    ),
                    filled: true,
                    fillColor: Colors.grey[850]
                  )
                ),
                SizedBox(height: 12),
                
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  style: TextStyle(
                    color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Description",
                    labelStyle: TextStyle(
                      color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: 
                        BorderRadius.circular(8)
                    ),
                    filled: true,
                    fillColor: Colors.grey[850]
                  )
                ),
                SizedBox(height: 12),
                
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  dropdownColor: Colors.grey[850],
                  decoration: InputDecoration(
                    labelText: "Priority",
                    labelStyle: TextStyle(
                      color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: 
                        BorderRadius.circular(8)
                    ),
                    filled: true,
                    fillColor: Colors.grey[850]
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'low',
                      child: Text("Low",
                        style: TextStyle(
                          color: Colors.white))
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text("Medium",
                        style: TextStyle(
                          color: Colors.white))
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text("High",
                        style: TextStyle(
                          color: Colors.white))
                    ),
                  ],
                  onChanged: (v) => 
                    selectedPriority = v ?? 'medium'
                ),
                SizedBox(height: 12),
                
                DropdownButtonFormField<String>(
                  value: selectedEmployee,
                  dropdownColor: Colors.grey[850],
                  decoration: InputDecoration(
                    labelText: "Assign to Employee",
                    labelStyle: TextStyle(
                      color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: 
                        BorderRadius.circular(8)
                    ),
                    filled: true,
                    fillColor: Colors.grey[850]
                  ),
                  items: _employees.map((emp) =>
                    DropdownMenuItem(
                      value: emp["id"].toString(),
                      child: Text(
                        emp["email"].toString(),
                        overflow: 
                          TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13
                        )
                      )
                    )
                  ).toList(),
                  onChanged: (v) => 
                    selectedEmployee = v
                ),
                SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment:
                    MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => 
                        Navigator.pop(ctx),
                      child: Text("Cancel",
                        style: TextStyle(
                          color: Colors.grey))
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: 
                          Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: 
                            BorderRadius.circular(8)
                        )
                      ),
                      onPressed: () async {
                        if (titleCtrl.text
                          .trim().isEmpty) return;
                        Navigator.pop(ctx);
                        await _createTask(
                          titleCtrl.text.trim(),
                          descCtrl.text.trim(),
                          selectedEmployee,
                          selectedPriority
                        );
                      },
                      child: Text("Create",
                        style: TextStyle(
                          color: Colors.white))
                    )
                  ]
                )
              ]
            )
          )
        )
      )
    );
  }

  Future<void> _createTask(String title, String desc, String? assignedTo, String priority) async {
    setState(() => _isLoading = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.createTask({
        'title': title,
        'description': desc,
        'priority': priority,
        'assigned_to': assignedTo,
        'status': 'pending',
      });
      if (res.statusCode == 201 || res.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task created successfully!')));
        await _loadTasks();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create task: ${res.statusCode}')));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
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
                        margin: EdgeInsets.only(bottom: 12),
                        color: Colors.grey[900],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: task.isPqcVerified
                              ? Colors.teal.withOpacity(0.5)
                              : Colors.grey[700]!,
                            width: 1
                          )
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: task.status == 
                              'completed'
                              ? Colors.teal
                              : Colors.grey[700],
                            child: Icon(
                              task.status == 'completed'
                                ? Icons.check
                                : Icons.assignment,
                              color: Colors.white,
                              size: 20
                            )
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.title,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold
                                  )
                                )
                              ),
                              if (task.isPqcVerified)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.teal
                                      .withOpacity(0.2),
                                    borderRadius: 
                                      BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.teal,
                                      width: 0.5
                                    )
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.verified_user,
                                        size: 10,
                                        color: Colors.teal
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        "PQC",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.teal,
                                          fontWeight: 
                                            FontWeight.bold
                                        )
                                      )
                                    ]
                                  )
                                )
                            ]
                          ),
                          subtitle: Column(
                            crossAxisAlignment: 
                              CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 4),
                              Text(
                                "Assignee: ${_getAssigneeEmail(task.assignedTo)}",
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12
                                )
                              ),
                              Text(
                                "Priority: ${task.priority
                                  .toUpperCase()}",
                                style: TextStyle(
                                  color: task.priority == 'high'
                                    ? Colors.red[300]
                                    : task.priority == 'medium'
                                      ? Colors.orange[300]
                                      : Colors.green[300],
                                  fontSize: 12
                                )
                              ),
                              if (task.isPqcVerified)
                                Text(
                                  "Secured with Dilithium3 PQC",
                                  style: TextStyle(
                                    color: Colors.teal[300],
                                    fontSize: 11
                                  )
                                )
                            ]
                          ),
                          trailing: PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert,
                              color: Colors.grey),
                            color: Colors.grey[850],
                            onSelected: (status) => 
                              _updateTask(task.id, status),
                            itemBuilder: (ctx) => [
                              PopupMenuItem(
                                value: 'pending',
                                child: Text("Mark Pending",
                                  style: TextStyle(
                                    color: Colors.white))
                              ),
                              PopupMenuItem(
                                value: 'completed',
                                child: Text("Mark Completed",
                                  style: TextStyle(
                                    color: Colors.white))
                              ),
                            ]
                          )
                        )
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
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
