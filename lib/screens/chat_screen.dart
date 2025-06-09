//lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:flutter_tts/flutter_tts.dart';
// import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

import '../utils/database_helper.dart';
import '../models/chat_message_model.dart' as model; 
import '../models/conversation_model.dart';
import '../models/flashcard_model.dart';
import 'chat_history_screen.dart';

const sourceLang = TranslateLanguage.english;
const targetLang = TranslateLanguage.spanish;


class ChatScreen extends StatefulWidget {
  final int? conversationId;

  const ChatScreen({super.key, this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final _uiMessages = <_ChatLineUi>[];
  final ScrollController _scrollController = ScrollController();
  late OnDeviceTranslator _translator;
  late FlutterTts _tts;
  // late stt.SpeechToText _stt;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  // bool _sttReady = false;
  // bool _listening = false;
  bool _modelsReady = false;
  double _speechRate = 0.5;
  String _currentSttError = '';
  int? _currentConversationId;
  Conversation? _currentConversation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentConversationId = widget.conversationId;
    _requestPermissionsAndInitEngines();
    if (_currentConversationId != null) {
      _loadConversationAndMessages(_currentConversationId!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveCurrentChat(isAppClosing: true);
    }
  }

  Future<void> _requestPermissionsAndInitEngines() async {
    // var status = await Permission.microphone.status;
    // if (!status.isGranted) {
    //   status = await Permission.microphone.request();
    // }

    // if (status.isGranted) {
      _initEngines();
    // } else {
    //   if (mounted) {
    //     setState(() {
    //       _modelsReady = false; 
    //       _currentSttError = "Microphone permission denied. Please enable it in settings.";
    //     });
    //   }
    // }
  }


  Future<void> _initEngines() async {
    if (mounted) setState(() => _modelsReady = false);

    final modelManager = OnDeviceTranslatorModelManager();
    try {
      if (!await modelManager.isModelDownloaded(sourceLang.bcpCode)) {
        print('Downloading model for: ${sourceLang.bcpCode}');
        await modelManager.downloadModel(sourceLang.bcpCode, isWifiRequired: false);
      }
      if (!await modelManager.isModelDownloaded(targetLang.bcpCode)) {
        print('Downloading model for: ${targetLang.bcpCode}');
        await modelManager.downloadModel(targetLang.bcpCode, isWifiRequired: false);
      }
    } catch (e) {
      print("Error downloading models: $e");
      if(mounted) {
        setState(() {
          _currentSttError = "Failed to download language models. Please check internet connection.";
          _modelsReady = false; 
        });
      }
      return; //Stop initialization if models fail
    }

    _translator = OnDeviceTranslator(sourceLanguage: sourceLang, targetLanguage: targetLang);
    _tts = FlutterTts();
    await _tts.setLanguage(targetLang.bcpCode);
    await _tts.setSpeechRate(_speechRate);

    // _stt = stt.SpeechToText();
    // _sttReady = await _stt.initialize(
    //   onStatus: (s) {
    //     if (s == 'done' || s == 'notListening') {
    //       if(mounted) setState(() => _listening = false);
    //     }
    //   },
    //   onError: (e) {
    //     if(mounted) {
    //       setState(() {
    //         _listening = false;
    //         _currentSttError = "STT Error: ${e.errorMsg}";
    //       });
    //     }
    //   },
    // );
    if (mounted) setState(() => _modelsReady = true);
  }

  Future<void> _loadConversationAndMessages(int conversationId) async {
    _currentConversation = await _dbHelper.getConversation(conversationId);
    if (_currentConversation == null) { //Handle case where conversation might have been deleted
        if (mounted) {
            setState(() {
                _uiMessages.clear();
                _currentConversationId = null; //Reset if not found
            });
        }
        return;
    }
    List<model.ChatMessage> dbMessages = await _dbHelper.getMessagesForConversation(conversationId);
    if (mounted) {
      setState(() {
        _uiMessages.clear();
        for (var msg in dbMessages) {
          // For user messages, originalText is the same as text
          // For bot messages (translations), originalText is the translatedText field (which contains the original user input)
          String? originalText = msg.isUserMessage ? msg.text : msg.translatedText;
          _uiMessages.add(_ChatLineUi(msg.text, isUser: msg.isUserMessage, timestamp: msg.timestamp, originalText: originalText));
        }
      });
    }
    _scrollToBottom(milliseconds: 100);
  }

  Future<void> _ensureConversationExists() async {
    if (_currentConversationId == null && _uiMessages.isNotEmpty) {
      DateTime now = DateTime.now();
      String convoTitle = "Chat - ${DateFormat.yMd().add_jm().format(now)} (${targetLang.name})";
      Conversation newConvo = Conversation(title: convoTitle, createdAt: now, lastMessageTimestamp: now);
      _currentConversationId = await _dbHelper.insertConversation(newConvo);
      _currentConversation = await _dbHelper.getConversation(_currentConversationId!);
       if (mounted) setState(() {});
    } else if (_currentConversationId != null && _currentConversation == null) {
      //If ID exists but conversation object isn't loaded yet (e.g., after app restart and loading from history)
      _currentConversation = await _dbHelper.getConversation(_currentConversationId!);
      if (mounted) setState(() {});
    }
  }

  Future<void> _saveCurrentChat({bool isAppClosing = false}) async {
    if (_isSaving || _uiMessages.isEmpty && _currentConversationId == null) return;
    if (mounted) setState(() => _isSaving = true);

    await _ensureConversationExists();

    if (_currentConversationId == null) {
      print("Error: Could not create or find conversation to save.");
       if (mounted) setState(() => _isSaving = false);
      return;
    }

    if (_currentConversation != null && _uiMessages.isNotEmpty) {
        _currentConversation!.lastMessageTimestamp = _uiMessages.last.timestamp;
        //Ensure title is set, especially for new conversations
        if (_currentConversation!.title == null || _currentConversation!.title!.startsWith("Chat -")) {
             _currentConversation!.title = "Chat - ${DateFormat.yMd().add_jm().format(_currentConversation!.createdAt)} (${targetLang.name})";
        }
        await _dbHelper.updateConversation(_currentConversation!);
    }

    print("Chat for conversation ID $_currentConversationId saved.");
    if (mounted) setState(() => _isSaving = false);

    if (!isAppClosing && Navigator.canPop(context)) {
      _currentConversationId = null;
      _currentConversation = null;
       if(mounted) {
         setState(() {
          _uiMessages.clear();
        });
       }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveCurrentChat(isAppClosing: true);
    if (_modelsReady) { //Only close if initialized
        _translator.close();
        _tts.stop();
        // _stt.stop();
        // _stt.cancel();
    }
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({int milliseconds = 300}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _scrollController.position.hasPixels) { 
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: Duration(milliseconds: milliseconds),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessageToDb(String text, bool isUser, DateTime timestamp, {String? translatedText}) async {
    await _ensureConversationExists();
    if (_currentConversationId != null) {
      model.ChatMessage dbMessage = model.ChatMessage(
        conversationId: _currentConversationId!,
        text: text,
        isUserMessage: isUser,
        timestamp: timestamp,
        translatedText: translatedText,
      );
      await _dbHelper.insertMessage(dbMessage);
    }
  }

  Future<void> _handleSubmittedText() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || !_modelsReady) return;
    _inputController.clear();
    FocusScope.of(context).unfocus();

    DateTime messageTimestamp = DateTime.now();
    if (mounted) {
      setState(() {
        _uiMessages.add(_ChatLineUi(text, isUser: true, timestamp: messageTimestamp, originalText: text));
      });
    }
    _scrollToBottom();
    await _sendMessageToDb(text, true, messageTimestamp, translatedText: text);

    try {
      final translated = await _translator.translateText(text);
      DateTime botMessageTimestamp = DateTime.now();
      if (mounted) {
        setState(() {
          _uiMessages.add(_ChatLineUi(translated, isUser: false, timestamp: botMessageTimestamp, originalText: text));
        });
      }
      _scrollToBottom();
      await _sendMessageToDb(translated, false, botMessageTimestamp, translatedText: text); //Pass original as translatedText for bot
    } catch (e) {
      print("Translation Error: $e");
      DateTime errorTimestamp = DateTime.now();
      if (mounted) {
        setState(() {
          _uiMessages.add(_ChatLineUi("Sorry, translation failed. Error: ${e.toString()}", isUser: false, timestamp: errorTimestamp, originalText: text));
        });
      }
      _scrollToBottom();
      await _sendMessageToDb("Sorry, translation failed. Error: ${e.toString()}", false, errorTimestamp, translatedText: text);
    }
  }

  Future<void> _startListening() async {
    // if (!_sttReady || _listening) return;
    if (mounted) setState(() { _currentSttError = ''; });
    // await _stt.listen(
    //   localeId: sourceLang.bcpCode,
    //   onResult: (r) {
    //     if (r.finalResult) {
    //       _inputController.text = r.recognizedWords;
    //       _handleSubmittedText();
    //     }
    //   },
    //   listenFor: const Duration(seconds: 10),
    //   pauseFor: const Duration(seconds: 3),
    // );
  }

  Future<void> _stopListening() async {
    // if (!_sttReady || !_listening) return; //Added check for _sttReady
    // await _stt.stop();
    if (mounted) setState(() => _currentSttError = '');
  }

  Future<void> _addToFlashcards(String originalText, String translatedText) async {
    try {
      // Check if flashcard already exists
      bool exists = await _dbHelper.flashcardExists(originalText, translatedText);
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This flashcard already exists!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      DateTime now = DateTime.now();
      Flashcard flashcard = Flashcard(
        originalText: originalText,
        translatedText: translatedText,
        sourceLanguage: sourceLang.bcpCode,
        targetLanguage: targetLang.bcpCode,
        createdAt: now,
        lastStudied: now,
        timesStudied: 0,
        difficulty: 2, // Medium difficulty by default
        isFavorite: false,
      );

      await _dbHelper.insertFlashcard(flashcard);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to flashcards! 📚'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to flashcards: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    String appBarTitle = 'Chat (${targetLang.name})'; 
    if (_currentConversation != null && _currentConversation!.title != null && _currentConversation!.title!.isNotEmpty) {
        appBarTitle = _currentConversation!.title!;
    } else if (_currentConversationId != null && _currentConversation == null && _uiMessages.isNotEmpty){
        //Case: Re-entering a chat that was just created but _currentConversation not fully loaded yet
        appBarTitle = "Chat - ${DateFormat.yMd().add_jm().format(_uiMessages.first.timestamp)} (${targetLang.name})";
    }


    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        await _saveCurrentChat(); 
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(appBarTitle, overflow: TextOverflow.ellipsis),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Chat History',
              onPressed: () async {
                await _saveCurrentChat(isAppClosing: true);

                final selectedConversationId = await Navigator.push<int?>(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatHistoryScreen()),
                );

                if (selectedConversationId != null) {
                  if (_currentConversationId != selectedConversationId) { //Only load if it's a different chat
                    _currentConversationId = selectedConversationId;
                    await _loadConversationAndMessages(selectedConversationId);
                  }
                } else {
                  //No conversation selected, user backed out of history.
                  if (_currentConversationId != null) {
                    Conversation? stillExists = await _dbHelper.getConversation(_currentConversationId!);
                    if (stillExists == null) {
                      if (mounted) {
                        setState(() {
                          _uiMessages.clear();
                          _currentConversationId = null;
                          _currentConversation = null;
                        });
                      }
                    }
                    //If it still exists, the ChatScreen remains as it was.
                  }
                }
              },
            ),
          ],
        ),
        backgroundColor: surfaceColor,
        body: Column(
            children: [
            Expanded(
              child: !_modelsReady && _currentSttError.isEmpty //Show loading if models not ready and no error
                ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 10), Text("Initializing engines...")],))
                : _uiMessages.isEmpty && _modelsReady //Models ready but no messages
                  ? Center(child: Text('Start a conversation!', style: TextStyle(color: onSurfaceColor.withOpacity(0.7))))
                  : ListView.builder( //Messages exist or models were not ready but there was an error
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: _uiMessages.length,
                      itemBuilder: (_, index) {
                        final messageIndex = _uiMessages.length - 1 - index;
                        return _buildChatBubble(_uiMessages[messageIndex]);
                      },
                    ),
            ),
            if (_currentSttError.isNotEmpty)
               Padding(padding: const EdgeInsets.all(8.0), child: Text(_currentSttError, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center,)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Icon(Icons.speed_rounded, size: 20, color: primaryColor),
                Expanded(
                  child: Slider(
                    value: _speechRate, min: 0.1, max: 1.0, divisions: 9,
                    label: _speechRate.toStringAsFixed(2), activeColor: primaryColor, inactiveColor: primaryColor.withOpacity(0.3),
                    onChanged: !_modelsReady ? null : (v) async { if(mounted) setState(() => _speechRate = v); await _tts.setSpeechRate(v); },
                  ),
                ),
                Text(_speechRate.toStringAsFixed(2), style: TextStyle(color: onSurfaceColor.withOpacity(0.7), fontSize: 12)),
              ]),
            ),
            if (!_modelsReady && _currentSttError.isEmpty) //Additional condition to not show if there's already an error
              const Padding(
                padding: EdgeInsets.all(8),
                child: Column(children: [LinearProgressIndicator(), SizedBox(height: 4), Text('Downloading language models… This may take a few moments.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))]),
              ),
            _buildInputRow(primaryColor, onSurfaceColor),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(Color primaryColor, Color onSurfaceColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withAlpha(230), 
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), spreadRadius: 0, blurRadius: 5, offset: Offset(0,-2))]),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _inputController,
            onSubmitted: (_) => _handleSubmittedText(),
            textInputAction: TextInputAction.send,
            style: TextStyle(color: onSurfaceColor),
            decoration: InputDecoration(hintText: 'Type or tap mic…', hintStyle: TextStyle(color: onSurfaceColor.withOpacity(0.5)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(25.0), borderSide: BorderSide.none), filled: true, fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.05), contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0)),
            enabled: _modelsReady,
          ),
        ),
        const SizedBox(width: 8),
        Material(color: Colors.transparent, child: IconButton(onPressed: !_modelsReady ? null : _handleSubmittedText, icon: Icon(Icons.send_rounded, color: primaryColor), tooltip: 'Send')),
        Material(color: Colors.transparent, child: IconButton(icon: Icon(_currentSttError.isNotEmpty ? Icons.mic_off_rounded : Icons.mic_rounded, color: _currentSttError.isNotEmpty ? Colors.redAccent : primaryColor), onPressed: !_modelsReady ? null : _startListening, tooltip: _currentSttError.isNotEmpty ? 'Stop listening' : 'Start listening')),
      ]),
    );
  }

  Widget _buildChatBubble(_ChatLineUi message) {
    final bool isUser = message.isUser;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? primaryColor : Colors.grey.shade200, 
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18), 
            topRight: const Radius.circular(18),
            bottomLeft: isUser ? const Radius.circular(18) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(18),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3, offset: const Offset(0, 1))],
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min, 
              crossAxisAlignment: CrossAxisAlignment.end, 
              children: [
                Flexible(child: Text(message.text, style: TextStyle(color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface))),
                if (!isUser) ...[
                  const SizedBox(width: 8), 
                  InkWell(
                    onTap: !_modelsReady ? null : () => _tts.speak(message.text), 
                    child: Icon(Icons.volume_up_rounded, size: 20, color: primaryColor.withOpacity(0.7)), 
                    borderRadius: BorderRadius.circular(10)
                  )
                ],
              ]
            ),
            // Add to flashcards button for translation pairs
            if (!isUser && message.originalText != null && message.originalText!.isNotEmpty) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _addToFlashcards(message.originalText!, message.text),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.library_add_rounded, 
                        size: 16, 
                        color: primaryColor
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add to Flashcards',
                        style: TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

//UI specific chat line
class _ChatLineUi {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? originalText;
  
  _ChatLineUi(this.text, {required this.isUser, required this.timestamp, this.originalText});
}