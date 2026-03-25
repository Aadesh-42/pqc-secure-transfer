class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isEncrypted;
  final DateTime createdAt;
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

  factory Message.fromJson(
    Map<String, dynamic> json
  ) {
    return Message(
      id: json['id']?.toString() ?? '',
      senderId: json['sender_id']
        ?.toString() ?? '',
      receiverId: json['receiver_id']
        ?.toString() ?? '',
      content: json['content']
        ?.toString() ?? '',
      isEncrypted: json['is_encrypted'] 
        ?? false,
      createdAt: json['created_at'] != null
        ? DateTime.parse(
            json['created_at'].toString())
        : DateTime.now(),
      isPqcSigned: json['is_pqc_signed'] 
        ?? false,
      signature: json['signature']
        ?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'is_encrypted': isEncrypted,
      'created_at': createdAt
        .toIso8601String(),
      'is_pqc_signed': isPqcSigned,
      'signature': signature,
    };
  }
}
