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
      final newWords = await _geminiService.fetchWords(inputWord);
      for (var word in newWords) {
        await _repository.addWord(word);
      }
      _loadWords();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateWord(int index, Word updatedWord) async {
    await _repository.updateWord(index, updatedWord);
    _loadWords();
  }

  Future<Word> refreshWordData(String wordText) async {
    final words = await _geminiService.fetchWords(wordText);
    if (words.isNotEmpty) {
      return words.first;
    }
    throw Exception('No data found for $wordText');
  }

  Future<Word> addExamples(Word originalWord) async {
    final examples = await _geminiService.fetchMoreExamples(originalWord.word);

    final newExamplesEn = List<String>.from(originalWord.examplesEn)
      ..addAll(examples['examples_en']!);
    final newExamplesVi = List<String>.from(originalWord.examplesVi)
      ..addAll(examples['examples_vi']!);

    final newWord = Word(
      word: originalWord.word,
      ipa: originalWord.ipa,
      meaningVi: originalWord.meaningVi,
      examplesEn: newExamplesEn,
      examplesVi: newExamplesVi,
    );
    return newWord;
  }

  Future<void> deleteWord(int index) async {
    await _repository.deleteWord(index);
    _loadWords();
  }
}
