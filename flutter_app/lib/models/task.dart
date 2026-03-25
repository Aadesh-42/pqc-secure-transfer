class Task {
  final String id;
  final String title;
  final String? description;
  final String? assignedTo;
  final String status;
  final String priority;
  final String? dueDate;
  final bool isPqcVerified;
  final String? pqcSignature;

  Task({
    required this.id,
    required this.title,
    this.description,
    this.assignedTo,
    required this.status,
    required this.priority,
    this.dueDate,
    this.isPqcVerified = false,
    this.pqcSignature,
  });

  factory Task.fromJson(
    Map<String, dynamic> json
  ) {
    return Task(
      id: json['id']?.toString() ?? '',
      title: json['title']
        ?.toString() ?? '',
      description: json['description']
        ?.toString(),
      assignedTo: json['assigned_to']
        ?.toString(),
      status: json['status']
        ?.toString() ?? 'pending',
      priority: json['priority']
        ?.toString() ?? 'medium',
      dueDate: json['due_date']
        ?.toString(),
      isPqcVerified: 
        json['is_pqc_verified'] ?? false,
      pqcSignature: json['pqc_signature']
        ?.toString(),
    );
  }
}
