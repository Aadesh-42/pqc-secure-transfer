class User {
  final String id;
  final String email;
  final String role;
  final String? kyberPublicKey;
  final String? dilithiumPublicKey;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.role,
    this.kyberPublicKey,
    this.dilithiumPublicKey,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      role: json['role'],
      kyberPublicKey: json['kyber_public_key'],
      dilithiumPublicKey: json['dilithium_public_key'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
