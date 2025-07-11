// lib/services/ai_chat_service.dart
// ** FINAL VERSION with your preferred detailed prompt **

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config/api_keys.dart';
import 'xp_event_tracker.dart';

class AiChatService {
  final GenerativeModel _model;
  ChatSession? _chatSession;

  AiChatService()
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash-latest',
          apiKey: geminiApiKey,
        );

  static const String _systemPrompt = '''
            You are **Lingo**, a friendly, encouraging, and expert Spanish-language tutor.

            TASKS
            Before we start, read what the user says. 
            If they're not asking for a translation, respond helpfully but stay focused on translation or language learning.
            
            1. **If a user asks for a translation**  
              • ALWAYS reply in the format: The translation of "WORD" in Spanish is TRANSLATION.
              • Do NOT use bold, extra formatting, or add example sentences.
              • Do NOT add any extra explanation or text before or after the translation sentence.

            2. **If a user writes in Spanish**  
              • Check their grammar.  
              • If correct   praise them.  
              • If incorrect   show the corrected sentence in **bold** and give a very brief explanation.

            3. **After every translation in task 1**, append an invisible JSON payload
              surrounded by \u200B … \u200C **exactly** like this (do *not* mention it to the user):

            \u200B{"tool":"create_flashcard","args":{"front":"<original english text>","back":"<the spanish translation>"}}\u200C

              • Replace <original english text> with the original English text from the user's request.
              • Replace <the spanish translation> with the translation you provided.
              • Keep the payload on **a single line with NO line-breaks or extra spaces before/after**.

            STYLE  
            • Be concise.  
            • End every reply with an engaging question to keep the conversation going (except for translation requests, which should only use the required format).
    ''';

  void startChat({List<Content>? history}) {
    _chatSession = _model.startChat(history: history);
  }

  Future<void> ensureSystemPrompt() async {
    if (_chatSession != null) {
      debugPrint('[AI] Ensuring system prompt is sent to existing session');
      await _chatSession!.sendMessage(Content.text(_systemPrompt));
    }
  }

  Future<String> sendMessage(String text, {bool useSystemPrompt = true}) async {
    if (useSystemPrompt) {
      if (_chatSession == null) {
        debugPrint('[AI] Starting new chat session');
        startChat();
        // Send system prompt as first message
        await _chatSession!.sendMessage(Content.text(_systemPrompt));
      }
    debugPrint('[AI] sendMessage called with text: "$text"');
    debugPrint('[AI] Using API key: ' + geminiApiKey.substring(0, 8) + '...');
    // Award XP for sending a chat message
    final xpTracker = XPEventTracker();
    xpTracker.addXP(XPEventTracker.chatMessage, 'Chat message sent');
    try {
      debugPrint('[AI] Sending message to Gemini API...');
      final response = await _chatSession!.sendMessage(Content.text(text))
          .timeout(const Duration(seconds: 30), onTimeout: () {
        debugPrint('[AI] Gemini API response timed out after 30 seconds');
        throw TimeoutException('AI response timed out after 30 seconds');
      });
      debugPrint('[AI] Gemini API response received');
      final aiResponse = response.text;
      debugPrint('[AI] Gemini API response text: ${aiResponse ?? "<null>"}');
      if (aiResponse == null || aiResponse.isEmpty) {
        debugPrint('[AI] Empty or null response from Gemini API');
        return "I'm sorry, I couldn't process that. Could you try rephrasing?";
      }
      return aiResponse;
    } on TimeoutException {
      debugPrint('[AI] Gemini API response timed out (caught in catch)');
      return 'Sorry, I\'m taking too long to respond. Please try again.';
    } on SocketException catch (e) {
      debugPrint('[AI] Network error: $e');
      return 'Sorry, I can\'t connect to the internet. Please check your connection and try again.';
    } catch (e, s) {
      debugPrint('[AI] Error sending message to Gemini API: $e');
      debugPrint('[AI] Stack trace: $s');
      return "Sorry, something went wrong. Please try again later.";
      }
    } else {
      // Send message directly, no system prompt, no chat session
      debugPrint('[AI] sendMessage (no system prompt) called with text: "$text"');
      final response = await _model.generateContent([Content.text(text)]);
      final aiResponse = response.text;
      debugPrint('[AI] Gemini API response text: ${aiResponse ?? "<null>"}');
      if (aiResponse == null || aiResponse.isEmpty) {
        debugPrint('[AI] Empty or null response from Gemini API');
        return "I'm sorry, I couldn't process that. Could you try rephrasing?";
      }
      return aiResponse;
    }
  }
}