import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:audioplayers/audioplayers.dart';

class CloudTtsService {
  static final CloudTtsService _instance = CloudTtsService._internal();
  factory CloudTtsService() => _instance;
  CloudTtsService._internal();

  static const _scopes = [
    'https://www.googleapis.com/auth/cloud-platform',
  ];
  static const _jsonAssetPath = 'assets/TTS.json'; // Update if your file is named differently

  AccessCredentials? _credentials;
  DateTime? _credentialsExpiry;

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
    }
  }

  Future<void> _playAudio(Uint8List audioBytes) async {
    try {
      final player = AudioPlayer();
      await player.play(BytesSource(audioBytes));
    } catch (e) {
      print('[CloudTTS] ERROR playing audio: $e');
    }
  }
} 