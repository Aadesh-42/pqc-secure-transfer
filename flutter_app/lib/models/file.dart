class SecureFile {
  final String id;
  final String senderId;
  final String receiverId;
  final String status;
  final DateTime createdAt;

  SecureFile({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
  });

  factory SecureFile.fromJson(Map<String, dynamic> json) {
    return SecureFile(
      id: json['id'],
      senderId: json['sender_id'] ?? '',
      receiverId: json['receiver_id'] ?? '',
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
