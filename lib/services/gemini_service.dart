import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/word.dart';
import '../models/grammar_topic.dart';
import '../models/grammar_exercise.dart';

class GeminiService {
  // ... existing code ...

  Future<List<GrammarExercise>> fetchGrammarPractice(
    List<String> topics,
    int quantityPerTopic,
  ) async {
    final topicStr = topics.join(', ');
    final totalCount = topics.length * quantityPerTopic;

    final prompt =
        '''
Act as an English Exam Generator.
I need practice exercises for the following Grammar Topics: $topicStr.

Configuration:
- Quantity: Strictly generate exactly $quantityPerTopic exercises FOR EACH TOPIC listed above. (Total exercises = $totalCount).
- Format: Fill-in-the-blank sentences.
- Output: JSON only.

Rules for "parts":
1. DO NOT reveal the grammar topic name in the sentence.
2. If the question requires conjugating a verb, place the base verb in parentheses as the start of the second part.
   - Bad: parts: ["When I", "you tomorrow."]
   - Good: parts: ["When I", "(see) you tomorrow."]
   - Good: parts: ["She", "(not/go) to school yesterday."]

JSON Schema:
{
  "exercises": [
    {
      "topic_source": "Name of the topic this question belongs to",
      "parts": ["Part before blank", "Part after blank"], 
      "correct_answer": "answer",
      "hint": "Hint in Vietnamese (e.g., V-ed form of 'go')"
    }
  ]
}
''';

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);

    if (response.text == null) {
      throw Exception('No response from Gemini');
    }

    try {
      final decoded = jsonDecode(response.text!);
      if (decoded is Map<String, dynamic> && decoded['exercises'] is List) {
        final exercises = (decoded['exercises'] as List)
            .map((e) => GrammarExercise.fromJson(e))
            .toList();

        // Client-side shuffle
        exercises.shuffle();

        return exercises;
      } else {
        throw Exception('Unexpected JSON format: ${decoded.runtimeType}');
      }
    } catch (e) {
      throw Exception(
        'Failed to parse Gemini response: $e\nRaw response: ${response.text}',
      );
    }
  }

  GenerativeModel get _model {
    final settingsBox = Hive.box('settings');
    final apiKey = settingsBox.get('apiKey', defaultValue: '') as String;
    final modelName =
        settingsBox.get('modelName', defaultValue: 'gemini-1.5-flash')
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
      model: modelName.isNotEmpty ? modelName : 'gemini-1.5-flash',
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

  Future<GrammarTopic> fetchGrammarTopic(String topicInput) async {
    final prompt =
        '''
Act as an expert English Teacher explaining grammar to a beginner student who has limited English knowledge.
Input Topic: "$topicInput"

Task: Explain this topic in Vietnamese. Return valid JSON only.

JSON Schema & Data Mapping Rules:
{
  "topic_en": "Standard English Name",
  "topic_vi": "Vietnamese Name",
  "definition": "Simple definition in Vietnamese.",
  "formulas": [
    {
      "type": "Name of structure (e.g., Khẳng định, Câu hỏi, or Mệnh đề If)",
      "structure": "The formula string",
      "example": "English example sentence",
      "explanation": "Brief explanation of components"
    }
  ],
  "usages": [
    { "context": "When to use", "detail": "Detailed explanation" }
  ],
  "signs": [
    "List of recognition words or signs (optional)"
  ],
  "tips_for_beginners": "Crucial mistakes to avoid or memory hacks."
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
        return GrammarTopic.fromJson(decoded);
      } else {
        throw Exception('Unexpected JSON format: ${decoded.runtimeType}');
      }
    } catch (e) {
      throw Exception(
        'Failed to parse Gemini response: $e\nRaw response: ${response.text}',
      );
    }
  }
}
