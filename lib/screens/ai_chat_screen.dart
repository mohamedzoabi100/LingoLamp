import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message_model.dart';
import '../models/conversation_model.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/chat_input_bar.dart';

class AIChatScreen extends StatefulWidget {
  final String? conversationId;

  const AIChatScreen({super.key, this.conversationId});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Load conversation if ID is provided
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.conversationId != null) {
        context.read<ChatProvider>().loadConversation(widget.conversationId!);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final showScrollToBottom = _scrollController.offset < 
        _scrollController.position.maxScrollExtent - 100;
    
    if (showScrollToBottom != _showScrollToBottom) {
      setState(() {
        _showScrollToBottom = showScrollToBottom;
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final conversation = chatProvider.currentConversation;
        final messages = chatProvider.currentMessages;
        final isLoading = chatProvider.isLoading;
        final isSending = chatProvider.isSending;
        final error = chatProvider.error;

        return Scaffold(
          appBar: AppBar(
            title: _buildAppBarTitle(conversation),
            actions: _buildAppBarActions(chatProvider, conversation),
            elevation: 0,
            scrolledUnderElevation: 1,
          ),
          body: Column(
            children: [
              // Error banner
              if (error != null) _buildErrorBanner(error, chatProvider),
              
              // Messages list
              Expanded(
                child: _buildMessagesList(chatProvider, messages, isLoading),
              ),
              
              // Input bar
              ChatInputBar(
                onSendMessage: (text) => chatProvider.sendMessage(text),
                isSending: isSending,
                onScrollToBottom: _scrollToBottom,
              ),
            ],
          ),
          floatingActionButton: _showScrollToBottom
              ? FloatingActionButton.small(
                  onPressed: _scrollToBottom,
                  child: const Icon(Icons.keyboard_arrow_down),
                )
              : null,
        );
      },
    );
  }

  Widget _buildAppBarTitle(Conversation? conversation) {
    if (conversation == null) {
      return const Text('New Chat');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          conversation.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          '${conversation.createdAt.day}/${conversation.createdAt.month}/${conversation.createdAt.year}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAppBarActions(ChatProvider chatProvider, Conversation? conversation) {
    if (conversation == null) return [];

    return [
      IconButton(
        icon: const Icon(Icons.history),
        onPressed: () => _showChatHistory(context),
        tooltip: 'Chat History',
      ),
      PopupMenuButton<String>(
        onSelected: (value) => _handleMenuAction(value, chatProvider, conversation),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'rename',
            child: Row(
              children: [
                Icon(Icons.edit),
                SizedBox(width: 8),
                Text('Rename'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildErrorBanner(String error, ChatProvider chatProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: () => chatProvider.initialize(),
            child: Text(
              'Retry',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList(ChatProvider chatProvider, List<ChatMessage> messages, bool isLoading) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (chatProvider.hasMoreMessages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0 && chatProvider.hasMoreMessages) {
          return _buildLoadMoreButton(chatProvider);
        }
        
        final messageIndex = chatProvider.hasMoreMessages ? index - 1 : index;
        final message = messages[messageIndex];
        
        return ChatMessageBubble(
          message: message,
          onCopy: () => _copyMessageToClipboard(message.text),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Start a conversation',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Ask me anything about language learning!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton(ChatProvider chatProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: chatProvider.isLoadingMore
            ? const CircularProgressIndicator()
            : TextButton(
                onPressed: () => chatProvider.loadMoreMessages(),
                child: const Text('Load more messages'),
              ),
      ),
    );
  }

  void _showChatHistory(BuildContext context) {
    context.push('/chat-history');
  }

  void _handleMenuAction(String action, ChatProvider chatProvider, Conversation conversation) {
    switch (action) {
      case 'rename':
        _showRenameDialog(chatProvider, conversation);
        break;
      case 'delete':
        _showDeleteDialog(chatProvider, conversation);
        break;
    }
  }

  void _showRenameDialog(ChatProvider chatProvider, Conversation conversation) {
    final controller = TextEditingController(text: conversation.title);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Conversation'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                chatProvider.renameConversation(conversation.id, newTitle);
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(ChatProvider chatProvider, Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text(
          'Are you sure you want to delete this conversation? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              chatProvider.deleteConversation(conversation.id);
              Navigator.pop(context);
              context.go('/home');
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _copyMessageToClipboard(String text) {
    // TODO: Implement clipboard functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }
} 