class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isPqcSigned;
  final String? signature;

  Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isEncrypted,
    required this.createdAt,
    this.isPqcSigned = false,
    this.signature,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      content: json['content'],
      isEncrypted: json['is_encrypted'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      isPqcSigned: json['is_pqc_signed'] ?? false,
      signature: json['signature'],
    );
  }
}
