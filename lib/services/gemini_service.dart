import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/word.dart';

class GeminiService {
  GenerativeModel get _model {
    final settingsBox = Hive.box('settings');
    final apiKey = settingsBox.get('apiKey', defaultValue: '') as String;
    final modelName =
        settingsBox.get('modelName', defaultValue: 'gemini-2.0-flash')
            as String;

    // Fallback to .env if Hive key is empty
    String? effectiveApiKey = apiKey;
    if (effectiveApiKey.isEmpty) {
      try {
        effectiveApiKey = dotenv.env['API_KEY'];
      } catch (_) {
        // dotenv not initialized, ignore
      }
    }

    if (effectiveApiKey == null || effectiveApiKey.isEmpty) {
      throw Exception(
        'API Key not found. Please configure it in Settings or .env file.',
      );
    }

    return GenerativeModel(
      model: modelName.isNotEmpty ? modelName : 'gemini-2.0-flash',
      apiKey: effectiveApiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
  }

  GeminiService();

  Future<List<Word>> fetchWords(String input) async {
    final prompt =
        '''
      Explain the following words: "$input".
      If the input is a list (comma separated), explain ALL of them.
      Return a JSON LIST of objects. Each object must follow this format:
      {
        "word": "The Word",
        "ipa": "IPA transcription",
        "meaning_vi": "Vietnamese meaning",
        "examples_en": ["Example sentence 1 in English", "Example sentence 2 in English"],
        "examples_vi": ["Vietnamese translation 1", "Vietnamese translation 2"]
      }
      Ensure "examples_en" and "examples_vi" are ARRAYS of strings.
      Ensure the response is a valid JSON LIST, even if there is only one word.
    ''';

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);

    if (response.text == null) {
      throw Exception('No response from Gemini');
    }

    try {
      final decoded = jsonDecode(response.text!);
      List<Word> words = [];

      if (decoded is List) {
        for (var item in decoded) {
          if (item is Map<String, dynamic>) {
            words.add(Word.fromJson(item));
          }
        }
      } else if (decoded is Map<String, dynamic>) {
        // Fallback if it returns a single object
        words.add(Word.fromJson(decoded));
      } else {
        throw Exception('Unexpected JSON format: ${decoded.runtimeType}');
      }

      if (words.isEmpty) {
        throw Exception('No words parsed from response.');
      }
      return words;
    } catch (e) {
      throw Exception(
        'Failed to parse Gemini response: $e\nRaw response: ${response.text}',
      );
    }
  }

  Future<Map<String, List<String>>> fetchMoreExamples(String word) async {
    final prompt =
        '''
      Generate 2 more examples for the word "$word".
      Return a JSON object with this format:
      {
        "examples_en": ["New example 1", "New example 2"],
        "examples_vi": ["Translation 1", "Translation 2"]
      }
    ''';

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);

    if (response.text == null) {
      throw Exception('No response from Gemini');
    }

    try {
      final decoded = jsonDecode(response.text!);
      if (decoded is Map<String, dynamic>) {
        return {
          'examples_en':
              (decoded['examples_en'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
          'examples_vi':
              (decoded['examples_vi'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [],
        };
      } else {
        throw Exception('Unexpected JSON format for examples');
      }
    } catch (e) {
      throw Exception('Failed to parse examples: $e');
    }
  }
}
