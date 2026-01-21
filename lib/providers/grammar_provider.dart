import 'package:flutter/material.dart';
import '../models/grammar_topic.dart';
import '../models/grammar_exercise.dart';
import '../services/gemini_service.dart';
import '../services/firestore_service.dart';

class GrammarProvider with ChangeNotifier {
  final GeminiService _geminiService = GeminiService();
  final FirestoreService _firestoreService = FirestoreService();

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

  Future<void> _loadTopics() async {
    _isLoading = true;
    // Don't notify here to avoid build errors during init, or use scheduleMicrotask
    // But for simplicity, we just set loading.
    // If we are in build, notifyListeners might throw.
    // Let's safe guard it or just fetch.
    try {
      _topics = await _firestoreService.getAllGrammarTopics();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTopic(String input) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final topic = await _geminiService.fetchGrammarTopic(input);
      await _firestoreService.saveGrammarTopic(topic);
      _topics.add(topic);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTopic(GrammarTopic topic) async {
    await _firestoreService.deleteGrammarTopic(topic.id);
    _topics.removeWhere((t) => t.id == topic.id);
    notifyListeners();
  }

  Future<void> refreshTopics() async {
    await _loadTopics();
  }
}
