import 'package:flutter/material.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Hello! Did you get the file?', 'isMe': false, 'time': '10:00 AM'},
    {'text': 'Yes, I just confirmed receipt.', 'isMe': true, 'time': '10:05 AM'},
    {'text': 'Great. Make sure to decrypt it locally.', 'isMe': false, 'time': '10:06 AM'},
  ];

  void _send() {
    if (_msgCtrl.text.trim().isEmpty) return;
    setState(() {
      _messages.add({
        'text': _msgCtrl.text.trim(),
        'isMe': true,
        'time': 'Just now'
      });
      _msgCtrl.clear();
    });
    // Optional: simulate reply
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _messages.add({
            'text': 'Understood.',
            'isMe': false,
            'time': 'Just now'
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['isMe'];
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
                          msg['text'],
                          style: TextStyle(color: isMe ? Colors.white : null),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['time'],
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
