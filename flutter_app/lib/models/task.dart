class TaskModel {
  final String id;
  final String title;
  final String? description;
  final String? assignedTo;
  final String status;
  final String priority;
  final DateTime? dueDate;
  final DateTime createdAt;
  final String? pqcSignature;
  final bool isPqcVerified;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.assignedTo,
    required this.status,
    required this.priority,
    this.dueDate,
    required this.createdAt,
    this.pqcSignature,
    this.isPqcVerified = false,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      assignedTo: json['assigned_to'],
      status: json['status'],
      priority: json['priority'],
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      createdAt: DateTime.parse(json['created_at']),
      pqcSignature: json['pqc_signature'],
      isPqcVerified: json['is_pqc_verified'] ?? false,
    );
  }
}
