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
  String? _currentRole;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initialize();
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
    
    print("=== CHAT INITIALIZE ===");
    print("Current user: $_currentUserId");
    print("Current role: $_currentRole");
    
    final api = Provider.of<ApiService>(context, listen: false);
    
    try {
      if (_currentRole == "admin") {
        final res = await api.getEmployees();
        if ((res.data as List).isNotEmpty) {
          _receiverId = res.data[0]["id"];
          print("Admin receiver (employee): $_receiverId");
        }
      } else {
        final res = await api.getAdmins();
        if ((res.data as List).isNotEmpty) {
          _receiverId = res.data[0]["id"];
          print("Employee receiver (admin): $_receiverId");
        }
      }
    } catch (e) {
      print("Error getting receiver: $e");
    }
    
    if (_receiverId != null) {
      await _loadMessages();
      _pollingTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _loadMessages(hideLoading: true)
      );
    } else {
      print("ERROR: receiver is null!");
    }
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
    if (_msgCtrl.text.trim().isEmpty || 
        _currentUserId == null || 
        _receiverId == null) return;

    print("=== SEND DEBUG ===");
    print("SENDING TO: $_receiverId");
    print("MY ID: $_currentUserId");
    
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentRole == "admin" 
            ? "Chat with Employee" 
            : "Chat with Admin"
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                ? const Center(
                    child: Text(
                      "No messages yet!\nSend the first message.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = _messages[i];
                      final isMe = msg.senderId == _currentUserId;
                      return Align(
                        alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey[800],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg.content,
                            style: const TextStyle(color: Colors.white)
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
