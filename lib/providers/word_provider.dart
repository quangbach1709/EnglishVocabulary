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
    loadWords();
  }

  /// Loads all words from Firestore
  Future<void> loadWords() async {
    _isLoading = true;
    notifyListeners();

    try {
      _words = await _repository.getWords();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds words using Gemini AI and saves to Firestore
  Future<void> addWord(String inputWord) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newWords = await _geminiService.fetchWords(inputWord);
      for (var word in newWords) {
        await _repository.addWord(word);
      }
      await loadWords();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates a word in Firestore
  Future<void> updateWord(Word updatedWord) async {
    try {
      await _repository.updateWord(updatedWord);
      await loadWords();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Refreshes word data from Gemini
  Future<Word> refreshWordData(String wordText) async {
    final words = await _geminiService.fetchWords(wordText);
    if (words.isNotEmpty) {
      return words.first;
    }
    throw Exception('No data found for $wordText');
  }

  /// Adds more examples to a word (legacy support)
  Future<Word> addExamples(Word originalWord, {String? context}) async {
    final examples = await _geminiService.fetchMoreExamples(originalWord.word, context: context);

    final newExamplesEn = List<String>.from(originalWord.examplesEn);
    final newExamplesVi = List<String>.from(originalWord.examplesVi);
    
    for (var ex in examples) {
      newExamplesEn.add(ex['text'] ?? '');
      newExamplesVi.add(ex['translation'] ?? '');
    }

    return originalWord.copyWith(
      examplesEn: newExamplesEn,
      examplesVi: newExamplesVi,
    );
  }

  // ============================================
  // Selection Mode State
  // ============================================
  bool _isSelectionMode = false;
  bool get isSelectionMode => _isSelectionMode;

  final Set<Word> _selectedWords = {};
  Set<Word> get selectedWords => _selectedWords;

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

  /// Deletes all selected words
  Future<void> deleteSelectedWords() async {
    for (var word in _selectedWords) {
      await _repository.deleteWord(word.english);
    }
    _selectedWords.clear();
    _isSelectionMode = false;
    await loadWords();
  }

  // ============================================
  // Grouping State
  // ============================================
  final Set<String> _collapsedGroups = {};
  Set<String> get collapsedGroups => _collapsedGroups;

  /// Creates a group for selected words
  Future<void> createGroup(String groupName) async {
    for (var word in _selectedWords) {
      final updatedWord = word.copyWith(group: groupName);
      await _repository.updateWord(updatedWord);
    }
    _selectedWords.clear();
    _isSelectionMode = false;
    await loadWords();
  }

  /// Renames a group
  Future<void> renameGroup(String oldName, String newName) async {
    final wordsInGroup = _words.where((w) => w.group == oldName);
    for (var word in wordsInGroup) {
      final updatedWord = word.copyWith(group: newName);
      await _repository.updateWord(updatedWord);
    }
    await loadWords();
  }

  /// Removes a word from its group
  Future<void> removeWordFromGroup(Word word) async {
    final updatedWord = Word(
      word: word.word,
      ipa: word.ipa,
      meaningVi: word.meaningVi,
      examplesEn: word.examplesEn,
      examplesVi: word.examplesVi,
      group: null, // Remove group
      nextReviewDate: word.nextReviewDate,
      interval: word.interval,
      easeFactor: word.easeFactor,
      status: word.status,
    );
    await _repository.updateWord(updatedWord);
    await loadWords();
  }

  /// Adds a single word to an existing group
  Future<void> addWordToGroup(Word word, String groupName) async {
    final updatedWord = word.copyWith(group: groupName);
    await _repository.updateWord(updatedWord);
    await loadWords();
  }

  /// Gets list of all existing group names (non-null)
  List<String> get existingGroups {
    return _words.map((w) => w.group).whereType<String>().toSet().toList()
      ..sort();
  }

  /// Deletes all words in a group
  Future<void> deleteGroup(String groupName) async {
    final wordsInGroup = _words.where((w) => w.group == groupName).toList();
    for (var word in wordsInGroup) {
      await _repository.deleteWord(word.english);
    }
    await loadWords();
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

  /// Helper to get words by group
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

  /// Deletes a single word
  Future<void> deleteWord(Word word) async {
    await _repository.deleteWord(word.english);
    await loadWords();
  }

  // ============================================
  // SRS (Spaced Repetition System) Methods
  // ============================================

  /// Updates word's SRS data based on user rating (SM-2 simplified algorithm)
  /// quality: 0 = Again, 1 = Hard, 2 = Good, 3 = Easy
  Future<void> updateWordSRS(Word word, int quality) async {
    final now = DateTime.now();
    int newInterval;
    int newStatus;
    double newEaseFactor = word.easeFactor;

    switch (quality) {
      case 0: // Again - completely forgot
        newInterval = 0;
        newStatus = 0; // Red
        newEaseFactor = (word.easeFactor - 0.2).clamp(1.3, 2.5);
        break;
      case 1: // Hard - difficult to remember
        newInterval = word.interval == 0 ? 1 : (word.interval * 1.2).round();
        newStatus = 1; // Orange
        newEaseFactor = (word.easeFactor - 0.15).clamp(1.3, 2.5);
        break;
      case 2: // Good - remembered with effort
        newInterval = word.interval == 0
            ? 1
            : (word.interval * word.easeFactor).round();
        newStatus = 2; // Yellow
        break;
      case 3: // Easy - remembered effortlessly
        newInterval = word.interval == 0 ? 4 : (word.interval * 4).round();
        newStatus = 3; // Light Green
        newEaseFactor = (word.easeFactor + 0.15).clamp(1.3, 2.5);
        break;
      default:
        newInterval = word.interval;
        newStatus = word.status;
    }

    // Calculate next review date
    final nextReview = now.add(Duration(days: newInterval));

    // Create updated word
    final updatedWord = word.copyWith(
      interval: newInterval,
      status: newStatus,
      easeFactor: newEaseFactor,
      nextReviewDate: nextReview,
    );

    await _repository.updateWord(updatedWord);
    await loadWords();
  }

  /// Returns words that are due for review (nextReviewDate <= now or null)
  List<Word> getWordsForReview() {
    final now = DateTime.now();
    return _words.where((word) {
      return word.nextReviewDate == null ||
          word.nextReviewDate!.isBefore(now) ||
          word.nextReviewDate!.isAtSameMomentAs(now);
    }).toList();
  }

  /// Get status color for a word
  static Color getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.red.shade100; // New/Forgot
      case 1:
        return Colors.orange.shade100; // Hard
      case 2:
        return Colors.yellow.shade100; // Good
      case 3:
        return Colors.lightGreen.shade100; // Easy
      default:
        return Colors.transparent;
    }
  }
}
