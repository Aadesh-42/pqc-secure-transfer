import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() =>
    _EmployeeListScreenState();
}

class _EmployeeListScreenState 
  extends State<EmployeeListScreen> {
  
  List<dynamic> _employees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final api = Provider.of<ApiService>(
        context, listen: false);
      final res = await api.getEmployees();
      setState(() {
        _employees = res.data;
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading employees: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Employee"),
      ),
      body: _isLoading
        ? const Center(
            child: CircularProgressIndicator())
        : _employees.isEmpty
          ? const Center(
              child: Text("No employees found"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _employees.length,
              itemBuilder: (ctx, i) {
                final emp = _employees[i];
                return Card(
                  margin: const EdgeInsets
                    .only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: 
                        Colors.blue,
                      child: Text(
                        emp["email"][0]
                          .toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white)
                      ),
                    ),
                    title: Text(emp["email"]),
                    subtitle: Text(
                      emp["role"].toString()
                        .toUpperCase()),
                    trailing: const Icon(
                      Icons.chat,
                      color: Colors.blue),
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/chat',
                        arguments: {
                          'receiver_id': 
                            emp["id"],
                          'receiver_email': 
                            emp["email"]
                        }
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
