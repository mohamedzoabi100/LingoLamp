//lib/screens/chat_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/database_helper.dart';
import '../models/conversation_model.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({super.key});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Conversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (mounted) setState(() => _isLoading = true);
    final conversations = await _dbHelper.getAllConversations();
    if (mounted) {
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmAndDeleteConversation(Conversation conversation) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Chat'),
          content: Text('Are you sure you want to delete this chat "${conversation.title ?? 'this chat'}"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete'), onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (shouldDelete == true && conversation.id != null) {
      int result = await _dbHelper.deleteConversation(conversation.id!);
      if (result > 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat deleted successfully')));
        _loadConversations(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete chat.')));
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat History'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? const Center(
                  child: Text('No chat history yet.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                )
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = _conversations[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      elevation: 2,
                      child: ListTile(
                        leading: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                          tooltip: "More options",
                          onSelected: (String value) {
                            if (value == 'delete') {
                              _confirmAndDeleteConversation(conversation);
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(children: [Icon(Icons.delete_outline, color: Colors.redAccent), SizedBox(width: 8), Text('Delete Chat', style: TextStyle(color: Colors.redAccent))]),
                            ),
                          ],
                        ),
                        title: Text(
                          conversation.title ?? 'Chat - ${DateFormat.yMd().add_jm().format(conversation.createdAt)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Last active: ${DateFormat.yMd().add_jm().format(conversation.lastMessageTimestamp)}',
                        ),

                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),

                        onTap: () {
                          Navigator.pop(context, conversation.id);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}