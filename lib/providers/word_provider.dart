import 'package:flutter/material.dart';
import '../models/word.dart';
import '../repositories/word_repository.dart';
import '../services/gemini_service.dart';

class WordProvider with ChangeNotifier {
  final WordRepository _repository = WordRepository();
  final GeminiService _geminiService = GeminiService();

  List<Word> _words = [];
  List<Word> get words => _words;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  WordProvider() {
    _loadWords();
  }

  void _loadWords() {
    _words = _repository.getWords();
    notifyListeners();
  }

  Future<void> addWord(String inputWord) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if word already exists (optional, but good for UX)
      // For now, just fetch.

      final word = await _geminiService.fetchWordData(inputWord);
      await _repository.addWord(word);
      _words.add(word); // Or reload from repo
      _loadWords(); // Refresh list
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteWord(int index) async {
    await _repository.deleteWord(index);
    _loadWords();
  }
}
