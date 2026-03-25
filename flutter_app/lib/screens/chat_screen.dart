import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../models/message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _storage = const FlutterSecureStorage();
  final _msgCtrl = TextEditingController();
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _currentUserId;
  String? _receiverId;
  String? _receiverEmail;
  String? _currentRole;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so ModalRoute.of(context) is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    _currentUserId = await _storage.read(key: "user_id");
    _currentRole = await _storage.read(key: "role");

    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    print("INIT - Role: $_currentRole");
    print("INIT - My ID: $_currentUserId");
    print("INIT - Args: $args");

    if (args != null && args['receiver_id'] != null) {
      setState(() {
        _receiverId = args['receiver_id'];
        _receiverEmail = args['receiver_email'];
      });
      print("INIT - Receiver from args: $_receiverId");
    } else {
      final api = Provider.of<ApiService>(context, listen: false);
      try {
        if (_currentRole == "admin") {
          final res = await api.getEmployees();
          print("ALL EMPLOYEES: ${res.data}");
          if ((res.data as List).isNotEmpty) {
            setState(() => _receiverId = res.data[0]["id"]);
          }
        } else {
          final res = await api.getAdmins();
          print("ALL ADMINS: ${res.data}");
          if ((res.data as List).isNotEmpty) {
            setState(() => _receiverId = res.data[0]["id"]);
          }
        }
      } catch (e) {
        print("Error getting receiver: $e");
      }
    }

    print("FINAL receiver: $_receiverId");
    await _loadMessages();
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadMessages(hideLoading: true)
    );
  }

  Future<void> _loadMessages({bool hideLoading = false}) async {
    if (_currentUserId == null || _receiverId == null) return;
    
    if (!hideLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final res = await api.getMessages(_receiverId!);
      
      if (mounted) {
        setState(() {
          _messages = (res.data as List)
            .map((m) => Message.fromJson(m))
            .toList();
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });

        print("=== CHAT DEBUG ===");
        print("My ID: $_currentUserId");
        print("Receiver ID: $_receiverId");
        print("Role: $_currentRole");
        print("Calling: /messages/$_receiverId");
        print("Messages found: ${_messages.length}");
        for (var m in _messages) {
          print("MSG: sender=${m.senderId} content=${m.content}");
        }
      }
    } catch (e) {
      print("Error loading messages: $e");
      if (mounted && !hideLoading) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed to load chat: $e")));
      }
    } finally {
      if (mounted && !hideLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    print("=== SEND DEBUG ===");
    print("Message: ${_msgCtrl.text}");
    print("My ID: $_currentUserId");
    print("Receiver ID: $_receiverId");

    if (_msgCtrl.text.trim().isEmpty) {
      print("ERROR: Empty message!");
      return;
    }
    if (_receiverId == null) {
      print("ERROR: No receiver!");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: No receiver selected!")));
      }
      return;
    }
    if (_currentUserId == null) {
      print("ERROR: No sender!");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Not logged in!")));
      }
      return;
    }

    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();
    
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      await api.sendMessage({
        "receiver_id": _receiverId,
        "content": text,
        "is_encrypted": false
      });
      print("Sent to: $_receiverId");
      await _loadMessages(hideLoading: true);
    } catch (e) {
      print("Error sending message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Failed to send: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          _receiverEmail ??
          (_currentRole == "admin"
            ? "Chat with Employee"
            : "Chat with Admin")
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 16),
                          const Text(
                            "No messages yet!\nSend the first message.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey))
                        ],
                      ))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) {
                        final msg = _messages[i];
                        final isMe = msg.senderId == _currentUserId;
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Align(
                            alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 2),
                                  child: Text(
                                    isMe ? "You" : (_receiverEmail ?? "Other"),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[500]
                                    )
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  constraints: BoxConstraints(
                                    maxWidth: screenWidth * 0.75
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe 
                                      ? Colors.teal[700] 
                                      : Colors.grey[800],
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(16),
                                      topRight: const Radius.circular(16),
                                      bottomLeft: Radius.circular(isMe ? 16 : 0),
                                      bottomRight: Radius.circular(isMe ? 0 : 16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              msg.content,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15
                                              )
                                            ),
                                          ),
                                          if (msg.isPqcSigned) ...[
                                            const SizedBox(width: 6),
                                            const Icon(
                                              Icons.verified_user,
                                              size: 14,
                                              color: Colors.cyanAccent,
                                            ),
                                          ]
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
                                  child: Text(
                                    "${msg.createdAt.hour}:${msg.createdAt.minute.toString().padLeft(2, '0')}",
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Colors.grey[600]
                                    )
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            _buildInputField(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          top: BorderSide(
            color: Colors.grey[800]!
          )
        )
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Type a message...",
                hintStyle: TextStyle(color: Colors.grey[500]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none
                ),
                filled: true,
                fillColor: Colors.grey[800],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10
                )
              ),
            )
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: Colors.teal,
            radius: 22,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _sendMessage
            )
          )
        ]
      )
    );
  }
}
