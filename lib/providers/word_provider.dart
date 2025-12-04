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

  // Selection Mode State
  bool _isSelectionMode = false;
  bool get isSelectionMode => _isSelectionMode;

  final Set<Word> _selectedWords = {};
  Set<Word> get selectedWords => _selectedWords;

  // Grouping State
  final Set<String> _collapsedGroups = {};
  Set<String> get collapsedGroups => _collapsedGroups;

  bool get allSelected =>
      _words.isNotEmpty && _selectedWords.length == _words.length;

  void toggleSelectAll() {
    if (allSelected) {
      _selectedWords.clear();
    } else {
      _selectedWords.addAll(_words);
    }
    notifyListeners();
  }

  void toggleWordSelection(Word word) {
    if (_selectedWords.contains(word)) {
      _selectedWords.remove(word);
    } else {
      _selectedWords.add(word);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedWords.addAll(_words);
    notifyListeners();
  }

  void clearSelection() {
    _selectedWords.clear();
    notifyListeners();
  }

  Future<void> deleteSelectedWords() async {
    for (var word in _selectedWords) {
      // Find index in repository (assuming repository handles by object or we need index)
      // Since repository uses index, we need to find it.
      // Ideally repository should support delete by object or ID.
      // For now, let's find index in the current list.
      final index = _words.indexOf(word);
      if (index != -1) {
        await _repository.deleteWord(index);
      }
    }
    _selectedWords.clear();
    _isSelectionMode = false;
    _loadWords();
  }

  // Grouping Methods
  Future<void> createGroup(String groupName) async {
    for (var word in _selectedWords) {
      word.group = groupName;
      await word.save(); // HiveObject save
    }
    _selectedWords.clear();
    _isSelectionMode = false;
    _loadWords();
  }

  Future<void> renameGroup(String oldName, String newName) async {
    final wordsInGroup = _words.where((w) => w.group == oldName);
    for (var word in wordsInGroup) {
      word.group = newName;
      await word.save();
    }
    _loadWords();
  }

  Future<void> removeWordFromGroup(Word word) async {
    word.group = null;
    await word.save();
    _loadWords();
  }

  Future<void> deleteGroup(String groupName) async {
    final wordsInGroup = _words.where((w) => w.group == groupName).toList();
    for (var word in wordsInGroup) {
      await word.delete(); // HiveObject delete
    }
    _loadWords();
  }

  void toggleGroupSelection(String? groupName) {
    final wordsInGroup = _words.where((w) => w.group == groupName).toList();
    final allSelected = wordsInGroup.every((w) => _selectedWords.contains(w));

    if (allSelected) {
      _selectedWords.removeAll(wordsInGroup);
    } else {
      _selectedWords.addAll(wordsInGroup);
    }
    notifyListeners();
  }

  void toggleGroupExpansion(String groupName) {
    if (_collapsedGroups.contains(groupName)) {
      _collapsedGroups.remove(groupName);
    } else {
      _collapsedGroups.add(groupName);
    }
    notifyListeners();
  }

  // Helper to get words by group
  Map<String?, List<Word>> get wordsByGroup {
    final Map<String?, List<Word>> grouped = {};
    for (var word in _words) {
      if (!grouped.containsKey(word.group)) {
        grouped[word.group] = [];
      }
      grouped[word.group]!.add(word);
    }
    return grouped;
  }

  Future<void> deleteWord(int index) async {
    await _repository.deleteWord(index);
    _loadWords();
  }
}
