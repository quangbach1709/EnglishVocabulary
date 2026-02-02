import 'package:flutter_tts/flutter_tts.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Global Text-to-Speech service with configurable settings.
/// Uses Hive for persistence.
class TtsService {
  // Singleton instance
  static final TtsService instance = TtsService._internal();
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  late Box _settingsBox;

  // Current settings
  double _speechRate = 0.5;
  String _language = 'en-US';

  // Getters
  double get speechRate => _speechRate;
  String get language => _language;

  /// Available English accents
  static const List<Map<String, String>> availableAccents = [
    {'code': 'en-US', 'name': 'Mỹ (US)'},
    {'code': 'en-GB', 'name': 'Anh (UK)'},
    {'code': 'en-AU', 'name': 'Úc (AU)'},
    {'code': 'en-IE', 'name': 'Ireland (IE)'},
  ];

  /// Initialize the service - call this at app startup
  Future<void> init() async {
    _settingsBox = Hive.box('settings');
    _speechRate = _settingsBox.get('tts_speechRate', defaultValue: 0.5);
    _language = _settingsBox.get('tts_language', defaultValue: 'en-US');
  }

  /// Speak text with current settings
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _flutterTts.setLanguage(_language);
    await _flutterTts.setSpeechRate(_speechRate);
    await _flutterTts.speak(text);
  }

  /// Stop any ongoing speech
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  /// Update speech rate and persist
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.1, 1.0);
    await _settingsBox.put('tts_speechRate', _speechRate);
  }

  /// Update language/accent and persist
  Future<void> setLanguage(String lang) async {
    _language = lang;
    await _settingsBox.put('tts_language', _language);
  }
}
