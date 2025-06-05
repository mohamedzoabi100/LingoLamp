import 'package:flutter/foundation.dart';

class Logger {
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('🔍 DEBUG: $message');
    }
  }

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ INFO: $message');
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ WARNING: $message');
    }
  }

  static void error(String message) {
    if (kDebugMode) {
      debugPrint('❌ ERROR: $message');
    }
  }

  static void success(String message) {
    if (kDebugMode) {
      debugPrint('✅ SUCCESS: $message');
    }
  }
} 