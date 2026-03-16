import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  List<Message> _messages = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  // Assuming current user is "mock_user_1" and we converse with "mock_user_2"
  final String _currentUserId = '00000000-0000-0000-0000-000000000000';
  final String _receiverId = 'a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Auto refresh every 5 seconds per requirement
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadMessages(hideLoading: true));
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool hideLoading = false}) async {
    if (!hideLoading) setState(() => _isLoading = true);
    try {
      final res = await Provider.of<ApiService>(context, listen: false).getMessages(_currentUserId);
      if (res.statusCode == 200) {
        setState(() {
          _messages = (res.data as List).map((m) => Message.fromJson(m)).toList();
          // Sort by date ascending to show newest at bottom
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        });
      }
    } catch (e) {
      if (mounted && !hideLoading) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load chat: $e')));
      }
    } finally {
      if (mounted && !hideLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _send() async {
    if (_msgCtrl.text.trim().isEmpty) return;
    
    final text = _msgCtrl.text.trim();
    _msgCtrl.clear();
    
    // Optimistic UI
    final tempMsg = Message(
      id: 'temp', senderId: _currentUserId, receiverId: _receiverId,
      content: text, isEncrypted: false, createdAt: DateTime.now(),
    );
    setState(() => _messages.add(tempMsg));

    try {
      await Provider.of<ApiService>(context, listen: false).sendMessage({
        'receiver_id': _receiverId,
        'content': text,
        'is_encrypted': false,
      });
      _loadMessages(hideLoading: true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      // Remove temp message if failed
      setState(() => _messages.removeWhere((m) => m.id == 'temp'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Chat')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isMe = msg.senderId == _currentUserId;
                    
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(20).copyWith(
                            bottomRight: isMe ? const Radius.circular(0) : null,
                            bottomLeft: isMe ? null : const Radius.circular(0),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              msg.content,
                              style: TextStyle(color: isMe ? Colors.white : null),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${msg.createdAt.hour}:${msg.createdAt.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                        filled: true,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
