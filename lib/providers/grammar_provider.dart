import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/grammar_topic.dart';
import '../models/grammar_exercise.dart';
import '../services/gemini_service.dart';

class GrammarProvider with ChangeNotifier {
  final GeminiService _geminiService = GeminiService();
  List<GrammarTopic> _topics = [];
  bool _isLoading = false;
  String? _error;

  List<GrammarTopic> get topics => _topics;
  bool get isLoading => _isLoading;
  String? get error => _error;

  GrammarProvider() {
    _loadTopics();
  }

  Future<List<GrammarExercise>> generateExercises(
    List<GrammarTopic> topics,
    int quantity,
  ) async {
    final topicNames = topics.map((t) => t.topicEn).toList();
    return _geminiService.fetchGrammarPractice(topicNames, quantity);
  }

  void _loadTopics() {
    final box = Hive.box<GrammarTopic>('grammar');
    _topics = box.values.toList();
    notifyListeners();
  }

  Future<void> addTopic(String input) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final topic = await _geminiService.fetchGrammarTopic(input);
      final box = Hive.box<GrammarTopic>('grammar');
      await box.add(topic);
      _topics.add(topic);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTopic(GrammarTopic topic) async {
    await topic.delete(); // HiveObject delete
    _topics.remove(topic);
    notifyListeners();
  }
}
