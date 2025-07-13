import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:audioplayers/audioplayers.dart';

class CloudTtsService with WidgetsBindingObserver {
  static final CloudTtsService _instance = CloudTtsService._internal();
  factory CloudTtsService() => _instance;
  CloudTtsService._internal() {
    // Register for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
  }

  static const _scopes = [
    'https://www.googleapis.com/auth/cloud-platform',
  ];
  static const _jsonAssetPath = 'assets/TTS.json'; // Update if your file is named differently

  AccessCredentials? _credentials;
  DateTime? _credentialsExpiry;
  AudioPlayer? _currentPlayer;
  bool _isPlaying = false;

  // Global TTS manager - ensures only one TTS instance is active at a time
  static CloudTtsService? _activeInstance;
  static final Set<CloudTtsService> _allInstances = {};

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Stop TTS when app is paused, minimized, or closed
        print('[CloudTTS] 🛑 App lifecycle changed to $state - stopping TTS');
        stop();
        break;
      case AppLifecycleState.resumed:
        // App resumed - no action needed
        break;
      case AppLifecycleState.inactive:
        // App is inactive (e.g., receiving a call) - stop TTS
        print('[CloudTTS] 🛑 App became inactive - stopping TTS');
        stop();
        break;
    }
  }

  Future<AccessCredentials> _getCredentials() async {
    if (_credentials != null && _credentialsExpiry != null && DateTime.now().isBefore(_credentialsExpiry!)) {
      return _credentials!;
    }
    try {
      final jsonStr = await rootBundle.loadString(_jsonAssetPath);
      final jsonMap = json.decode(jsonStr);
      final accountCredentials = ServiceAccountCredentials.fromJson(jsonMap);
      final client = http.Client();
      final creds = await obtainAccessCredentialsViaServiceAccount(
        accountCredentials,
        _scopes,
        client,
      );
      _credentials = creds;
      _credentialsExpiry = creds.accessToken.expiry;
      client.close();
      return creds;
    } catch (e) {
      print('[CloudTTS] ERROR: Failed to load credentials: $e');
      rethrow;
    }
  }

  Future<void> speak({
    required String text,
    required String languageCode,
    String? voiceName,
    double pitch = 0.0,
    double speakingRate = 1.0,
  }) async {
    try {
      // Stop any other active TTS instances first
      await _stopAllOtherInstances();
      
      // Stop any currently playing audio
      await _stopCurrentAudio();
      
      // Set this as the active instance
      _activeInstance = this;
      
      print('[CloudTTS] 🚀 Starting Cloud TTS request...');
      print('[CloudTTS] 📝 Text: "$text"');
      print('[CloudTTS] 🌍 Language: $languageCode');
      print('[CloudTTS] 🎤 Voice: $voiceName');
      
      final creds = await _getCredentials();
      print('[CloudTTS] ✅ Credentials loaded successfully');
      
      final url = Uri.parse('https://texttospeech.googleapis.com/v1/text:synthesize');
      final headers = {
        'Authorization': 'Bearer ${creds.accessToken.data}',
        'Content-Type': 'application/json',
      };
      final body = jsonEncode({
        'input': {'text': text},
        'voice': {
          'languageCode': languageCode,
          if (voiceName != null) 'name': voiceName,
        },
        'audioConfig': {
          'audioEncoding': 'MP3',
          'pitch': pitch,
          'speakingRate': speakingRate,
        },
      });
      
      print('[CloudTTS] 🌐 Sending request to Google Cloud TTS API...');
      final response = await http.post(url, headers: headers, body: body);
      
      if (response.statusCode != 200) {
        print('[CloudTTS] ❌ API call failed: ${response.statusCode} ${response.body}');
        return;
      }
      
      print('[CloudTTS] ✅ Received response from Google Cloud TTS API');
      final responseJson = jsonDecode(response.body);
      final audioContent = responseJson['audioContent'];
      if (audioContent == null) {
        print('[CloudTTS] ❌ No audio content in response');
        return;
      }
      
      print('[CloudTTS] 🔊 Playing Cloud TTS audio...');
      final audioBytes = base64Decode(audioContent);
      await _playAudio(audioBytes);
      print('[CloudTTS] ✅ Cloud TTS audio played successfully!');
      
    } catch (e) {
      print('[CloudTTS] ❌ ERROR: $e');
      _isPlaying = false;
      if (_activeInstance == this) {
        _activeInstance = null;
      }
    }
  }

  Future<void> _stopAllOtherInstances() async {
    for (final instance in _allInstances) {
      if (instance != this && instance._isPlaying) {
        await instance.stop();
      }
    }
  }

  Future<void> _stopCurrentAudio() async {
    if (_currentPlayer != null && _isPlaying) {
      try {
        await _currentPlayer!.stop();
        await _currentPlayer!.dispose();
        print('[CloudTTS] 🛑 Stopped previous audio');
      } catch (e) {
        print('[CloudTTS] ERROR stopping audio: $e');
      }
      _currentPlayer = null;
      _isPlaying = false;
    }
  }

  Future<void> _playAudio(Uint8List audioBytes) async {
    try {
      // Create new player instance
      _currentPlayer = AudioPlayer();
      _isPlaying = true;
      
      // Set up completion handler
      _currentPlayer!.onPlayerComplete.listen((_) {
        print('[CloudTTS] ✅ Audio playback completed');
        _isPlaying = false;
        if (_activeInstance == this) {
          _activeInstance = null;
        }
      });
      
      await _currentPlayer!.play(BytesSource(audioBytes));
    } catch (e) {
      print('[CloudTTS] ERROR playing audio: $e');
      _isPlaying = false;
      if (_activeInstance == this) {
        _activeInstance = null;
      }
    }
  }

  Future<void> stop() async {
    await _stopCurrentAudio();
    if (_activeInstance == this) {
      _activeInstance = null;
    }
  }

  bool get isPlaying => _isPlaying;

  // Register this instance for global management
  void register() {
    _allInstances.add(this);
  }

  // Unregister this instance
  void unregister() {
    _allInstances.remove(this);
    if (_activeInstance == this) {
      _activeInstance = null;
    }
  }

  // Cleanup method to be called when the app is shutting down
  void dispose() {
    stop();
    WidgetsBinding.instance.removeObserver(this);
  }
} 