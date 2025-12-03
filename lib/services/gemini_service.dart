import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/word.dart';

class GeminiService {
  static const String _apiKey = 'AIzaSyA-IWqJ9cqm5H63CFzf3u2k0jK0eFJjdZM';
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
  }

  Future<Word> fetchWordData(String word) async {
    final prompt =
        '''
      Explain the word "$word" in the following JSON format:
      {
        "word": "$word",
        "ipa": "IPA transcription",
        "meaning_vi": "Vietnamese meaning",
        "example_en": "Example sentence in English",
        "example_vi": "Example sentence translated to Vietnamese"
      }
      Ensure the response is valid JSON.
    ''';

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);

    if (response.text == null) {
      throw Exception('No response from Gemini');
    }

    try {
      final decoded = jsonDecode(response.text!);
      Map<String, dynamic> jsonMap;

      if (decoded is List) {
        if (decoded.isNotEmpty) {
          jsonMap = decoded.first as Map<String, dynamic>;
        } else {
          throw Exception('Gemini returned an empty list.');
        }
      } else if (decoded is Map) {
        jsonMap = decoded as Map<String, dynamic>;
      } else {
        throw Exception('Unexpected JSON format: ${decoded.runtimeType}');
      }

      return Word.fromJson(jsonMap);
    } catch (e) {
      throw Exception(
        'Failed to parse Gemini response: $e\nRaw response: ${response.text}',
      );
    }
  }
}
