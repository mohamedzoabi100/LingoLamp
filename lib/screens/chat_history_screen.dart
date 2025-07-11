//lib/screens/chat_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
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
  
  // Spanish-only configuration
  static const String _languageCode = 'es';

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
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Chat'),
          content: Text(
              'Are you sure you want to delete "${conversation.title ?? 'this chat'}"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false)),
            TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
                onPressed: () => Navigator.of(dialogContext).pop(true)),
          ],
        );
      },
    );

    if (shouldDelete == true && conversation.id.isNotEmpty) {
      await _dbHelper.deleteConversation(conversation.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chat deleted successfully')));
      }
      _loadConversations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false, // No arrow when reached from bottom-nav
        title: const Text('Spanish Chats'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'No Spanish chats yet.\nTap the "+" button to start a new conversation!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = _conversations[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      elevation: 2,
                      child: ListTile(
                        leading: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.7)),
                          onSelected: (value) {
                            if (value == 'delete') {
                              _confirmAndDeleteConversation(conversation);
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline,
                                    color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text('Delete Chat',
                                    style: TextStyle(color: Colors.redAccent))
                              ]),
                            ),
                          ],
                        ),
                        title: Text(
                          conversation.title ?? 'Chat',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          'Last active: ${DateFormat.yMd().add_jm().format(conversation.updatedAt)}',
                        ),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                        onTap: () async {
                          await context.push('/chat/${conversation.id}');
                          // Refresh list when returning from chat
                          _loadConversations();
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'newChatFab',
        onPressed: () async {
          await context.push('/chat/new');
          // Refresh list when returning from new chat
          _loadConversations();
        },
        label: const Text('New Chat'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}