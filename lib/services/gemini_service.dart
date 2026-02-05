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
Act as a Dictionary API.
Task: Generate vocabulary data for: "$input"
If multiple words (comma separated), return ALL.

Return JSON LIST:
[
  {
    "word": "example",
    "pos": ["noun", "verb"],
    "verbs": [
      {"id": 0, "type": "Past tense", "text": "..."},
      {"id": 1, "type": "Past participle", "text": "..."},
      {"id": 2, "type": "Present participle", "text": "..."}
    ],
    "pronunciation": [
      {"pos": "noun", "lang": "us", "url": "", "pron": "/ɪɡˈzæm.pəl/"},
      {"pos": "noun", "lang": "uk", "url": "", "pron": "/ɪɡˈzɑːm.pəl/"}
    ],
    "definition": [
      {
        "id": 0,
        "pos": "noun",
        "text": "English definition (academic)",
        "shortTranslation": "Nghĩa ngắn, hay dùng (1-3 từ, VD: lớp học)",
        "translation": "Nghĩa học thuật đầy đủ (VD: Một nhóm học sinh được dạy cùng nhau)",
        "example": [{"id": 0, "text": "Eng sentence.", "translation": "Câu tiếng Việt."}]
      }
    ]
  }
]

Rules:
- 1 example per definition (concise)
- Natural Vietnamese translations
- shortTranslation: 1-3 từ đơn giản, hay dùng, dễ nhớ (VD: "học", "sách", "lớp học", "giáo viên")
- translation: Nghĩa đầy đủ, chi tiết hơn (cho mục đích tham khảo, học thuật)
- Verbs: include Past/Past Participle/Present Participle
- Nouns: include Plural in verbs array if applicable
- IDs start from 0
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

  Future<List<Map<String, String>>> fetchMoreExamples(
    String word, {
    String? context,
  }) async {
    final contextInfo = context != null ? ' in the context of "$context"' : '';
    final prompt =
        '''
Generate 2 example sentences for "$word"$contextInfo.
Return JSON array:
[
  {"text": "English sentence.", "translation": "Câu tiếng Việt."},
  {"text": "English sentence.", "translation": "Câu tiếng Việt."}
]
Rules: Natural, practical examples. Vietnamese must be fluent.
''';

    final content = [Content.text(prompt)];
    final response = await _model.generateContent(content);

    if (response.text == null) {
      throw Exception('No response from Gemini');
    }

    try {
      final decoded = jsonDecode(response.text!);
      if (decoded is List) {
        return decoded
            .map(
              (e) => {
                'text': (e['text'] ?? '').toString(),
                'translation': (e['translation'] ?? '').toString(),
              },
            )
            .toList();
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
