import 'dart:async';
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

  StreamSubscription<List<Word>>? _wordsSubscription;

  WordProvider() {
    _subscribeToWords();
  }

  /// Subscribes to real-time Firestore updates.
  /// Any change from any device (web, Android, etc.) will automatically
  /// push a new snapshot and update _words without requiring a manual reload.
  void _subscribeToWords() {
    _isLoading = true;
    // Don't call notifyListeners() here — we're still in the constructor.

    _wordsSubscription = _repository.wordsStream().listen(
      (words) {
        _words = words;
        _error = null;
        _isLoading = false;
        notifyListeners();
      },
      onError: (Object e) {
        _error = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  /// Re-subscribes to the stream (e.g. after a sign-in / sign-out cycle).
  void resubscribe() {
    _wordsSubscription?.cancel();
    _subscribeToWords();
  }

  /// Manual refresh — cancels and re-creates the stream subscription.
  Future<void> loadWords() async {
    resubscribe();
  }

  @override
  void dispose() {
    _wordsSubscription?.cancel();
    super.dispose();
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
      // Stream will automatically push the update — no manual loadWords() needed.
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds words in bulk from a formatted text string
  Future<void> addWordsBulk(String bulkText) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final List<Word> parsedWords = _parseBulkText(bulkText);
      if (parsedWords.isEmpty) {
        throw Exception(
          'Không tìm thấy từ nào để thêm. Hãy kiểm tra định dạng.\nĐịnh dạng đúng: Từ [Loại từ] /Phát âm/ Nghĩa',
        );
      }

      await _repository.addWords(parsedWords);
      // Stream will automatically push the update.
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds word pairs (synonym/antonym) in bulk from a formatted text string
  /// Format: "Empty (trống) -> Bare (trống trơn)"
  Future<void> addWordPairsBulk(
    String bulkText, {
    bool isSynonym = true,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final List<Word> parsedWords = _parseWordPairsText(
        bulkText,
        isSynonym: isSynonym,
      );
      if (parsedWords.isEmpty) {
        throw Exception(
          'Không tìm thấy cặp từ nào để thêm. Hãy kiểm tra định dạng.\n'
          'Định dạng đúng: Word1 (nghĩa1) -> Word2 (nghĩa2)',
        );
      }

      await _repository.addWords(parsedWords);
      // Stream will automatically push the update.
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Parses word pairs text in the format: "Empty (trống) -> Bare (trống trơn)"
  /// Returns a list of Word objects with synonym or antonym fields populated.
  List<Word> _parseWordPairsText(String text, {bool isSynonym = true}) {
    final List<Word> words = [];

    // Normalize line-endings
    final normalizedText = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalizedText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // Regex to parse: "Word (meaning) -> RelatedWord (relatedMeaning)"
    // Captures: 1=Word, 2=meaning, 3=RelatedWord, 4=relatedMeaning
    final pairRegex = RegExp(
      r'^([a-zA-Z][a-zA-Z\s\-]*?)\s*\(([^)]+)\)\s*->\s*([a-zA-Z][a-zA-Z\s\-]*?)\s*\(([^)]+)\)$',
      caseSensitive: false,
    );

    for (final line in lines) {
      final match = pairRegex.firstMatch(line);
      if (match != null) {
        final word = match.group(1)!.trim();
        final meaningVi = match.group(2)!.trim();
        final relatedWord = match.group(3)!.trim();
        final relatedMeaningVi = match.group(4)!.trim();

        if (word.isNotEmpty && relatedWord.isNotEmpty) {
          words.add(
            Word(
              word: word,
              meaningVi: meaningVi,
              synonym: isSynonym ? relatedWord : null,
              synonymMeaningVi: isSynonym ? relatedMeaningVi : null,
              antonym: isSynonym ? null : relatedWord,
              antonymMeaningVi: isSynonym ? null : relatedMeaningVi,
              status: 0,
              nextReviewDate: DateTime.now(),
            ),
          );
        }
      }
    }

    return words;
  }

  /// Parses bulk text with flexible formats:
  /// 1. Word POS /IPA/ Meaning  (all on one line, space-separated)
  /// 2. Word POS/IPA/ Meaning  (POS directly attached to IPA)
  /// 3. Word \n POS \n /IPA/ Meaning  (multi-line per entry)
  ///
  /// Supports formats like:
  /// - "limited adj./'limitid/ hạn chế"
  /// - "link v.,n./liɳk/ liên kết"
  /// - "list n.,v./list/ danh sách; liệt kê"
  List<Word> _parseBulkText(String text) {
    final List<Word> words = [];

    // Normalize line-endings
    final normalizedText = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Try line-by-line parsing first (most common format)
    final lines = normalizedText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (var line in lines) {
      final parsed = _parseSingleLine(line);
      if (parsed != null) {
        words.add(parsed);
      }
    }

    // If line-by-line didn't work, try the original multi-entry approach
    if (words.isEmpty) {
      final entryStart = RegExp(
        r'(?:^|(?<=\s))([a-zA-Z][a-zA-Z0-9\s\-]*?)\s+'
        r'((?:(?:n|v|adj|adv|prep)\.?,?\s*)+)'
        r'(/[^/]+/(?:\s*or\s*/[^/]+/)*)',
        caseSensitive: false,
      );

      final allMatches = entryStart.allMatches(normalizedText).toList();

      for (int i = 0; i < allMatches.length; i++) {
        final m = allMatches[i];

        final wordRaw = m.group(1)!.trim();
        final posStr = m.group(2)!.trim();
        final ipa = m.group(3)!.trim();

        final meaningStart = m.end;
        final meaningEnd = (i + 1 < allMatches.length)
            ? allMatches[i + 1].start
            : normalizedText.length;

        final meaning = normalizedText
            .substring(meaningStart, meaningEnd)
            .trim();

        if (wordRaw.isNotEmpty && ipa.isNotEmpty) {
          words.add(
            Word(
              word: wordRaw,
              pos: _parsePos(posStr),
              ipa: ipa,
              meaningVi: meaning,
              status: 0,
              nextReviewDate: DateTime.now(),
            ),
          );
        }
      }
    }

    return words;
  }

  /// Parses a single line in format: "word POS/IPA/ meaning"
  /// Handles formats like:
  /// - "limited adj./'limitid/ hạn chế"
  /// - "link v.,n./liɳk/ liên kết"
  /// - "list n., v. /list/ danh sách"
  Word? _parseSingleLine(String line) {
    // Find the IPA block (anything between / /)
    final ipaMatch = RegExp(r'/[^/]+/').firstMatch(line);
    if (ipaMatch == null) return null;

    final ipa = ipaMatch.group(0)!;
    final ipaStart = ipaMatch.start;
    final ipaEnd = ipaMatch.end;

    final beforeIpa = line.substring(0, ipaStart).trim();
    final afterIpa = line.substring(ipaEnd).trim();

    if (beforeIpa.isEmpty) return null;

    // Parse the part before IPA to extract word and POS
    // Format: "word POS" where POS can be "adj.", "v.,n.", "n., v.", etc.
    // POS is typically at the end, right before IPA

    // Regex to match POS patterns at the end of beforeIpa
    // Matches: "adj.", "v.,n.", "n., v.", "v., n.", "adj.,adv.", etc.
    final posPattern = RegExp(
      r'^(.*?)\s+((?:(?:n|v|adj|adv|prep|conj|pron|det|interj)\.?,?\s*)+)$',
      caseSensitive: false,
    );

    String wordPart = '';
    String posPart = '';

    final posMatch = posPattern.firstMatch(beforeIpa);
    if (posMatch != null) {
      wordPart = posMatch.group(1)!.trim();
      posPart = posMatch.group(2)!.trim();
    } else {
      // No POS found, the whole beforeIpa is the word
      wordPart = beforeIpa;
    }

    if (wordPart.isEmpty) return null;

    return Word(
      word: wordPart,
      pos: _parsePos(posPart),
      ipa: ipa,
      meaningVi: afterIpa,
      status: 0,
      nextReviewDate: DateTime.now(),
    );
  }

  /// Helper to parse POS string into a list of normalized POS names
  List<String> _parsePos(String posStr) {
    final List<String> posList = [];
    final cleanPos = posStr
        .replaceAll(',', ' ')
        .replaceAll('.', ' ')
        .toLowerCase();
    final parts = cleanPos
        .split(' ')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty);

    for (var p in parts) {
      if (p == 'n')
        posList.add('noun');
      else if (p == 'v')
        posList.add('verb');
      else if (p == 'adj')
        posList.add('adjective');
      else if (p == 'adv')
        posList.add('adverb');
      else if (p == 'prep')
        posList.add('preposition');
      else if (p.length > 1)
        posList.add(p); // Add other POS if it's a word
    }
    return posList.toSet().toList();
  }

  /// Updates a word in Firestore
  Future<void> updateWord(Word updatedWord) async {
    try {
      await _repository.updateWord(updatedWord);
      // Stream will automatically push the update.
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
    final examples = await _geminiService.fetchMoreExamples(
      originalWord.word,
      context: context,
    );

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

  /// Deletes all selected words using batch operation
  Future<void> deleteSelectedWords() async {
    if (_selectedWords.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      final List<String> wordIds = _selectedWords
          .map((w) => w.english)
          .toList();
      await _repository.deleteWords(wordIds);

      _selectedWords.clear();
      _isSelectionMode = false;
      // Stream will automatically push the update.
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============================================
  // Grouping State
  // ============================================
  final Set<String> _collapsedGroups = {};
  Set<String> get collapsedGroups => _collapsedGroups;

  // ============================================
  // Search and Filter State
  // ============================================
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  final Set<String> _selectedPosFilters = {};
  Set<String> get selectedPosFilters => _selectedPosFilters;

  /// All unique POS values across all words
  List<String> get availablePosFilters {
    final Set<String> allPos = {};
    for (var word in _words) {
      allPos.addAll(word.pos);
    }
    return allPos.toList()..sort();
  }

  /// Update search query
  void setSearchQuery(String query) {
    _searchQuery = query.toLowerCase().trim();
    notifyListeners();
  }

  /// Clear search query
  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  /// Toggle a POS filter
  void togglePosFilter(String pos) {
    if (_selectedPosFilters.contains(pos)) {
      _selectedPosFilters.remove(pos);
    } else {
      _selectedPosFilters.add(pos);
    }
    notifyListeners();
  }

  /// Clear all POS filters
  void clearPosFilters() {
    _selectedPosFilters.clear();
    notifyListeners();
  }

  /// Clear all filters (search + POS)
  void clearAllFilters() {
    _searchQuery = '';
    _selectedPosFilters.clear();
    notifyListeners();
  }

  /// Check if any filter is active
  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty || _selectedPosFilters.isNotEmpty;

  /// Get filtered words based on search query and POS filters
  List<Word> get filteredWords {
    if (!hasActiveFilters) return _words;

    return _words.where((word) {
      // Check search query (word or meaning)
      if (_searchQuery.isNotEmpty) {
        final matchesWord = word.word.toLowerCase().contains(_searchQuery);
        final matchesMeaning =
            word.meaningVi.toLowerCase().contains(_searchQuery) ||
            word.primaryMeaning.toLowerCase().contains(_searchQuery) ||
            word.primaryShortMeaning.toLowerCase().contains(_searchQuery) ||
            word.allMeaningsVi.toLowerCase().contains(_searchQuery);

        if (!matchesWord && !matchesMeaning) {
          return false;
        }
      }

      // Check POS filters
      if (_selectedPosFilters.isNotEmpty) {
        final hasMatchingPos = word.pos.any(
          (pos) => _selectedPosFilters.contains(pos),
        );
        if (!hasMatchingPos) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Get filtered words grouped by group name
  Map<String?, List<Word>> get filteredWordsByGroup {
    final words = filteredWords;
    final Map<String?, List<Word>> grouped = {};
    for (var word in words) {
      if (!grouped.containsKey(word.group)) {
        grouped[word.group] = [];
      }
      grouped[word.group]!.add(word);
    }
    return grouped;
  }

  /// Creates a group for selected words
  Future<void> createGroup(String groupName) async {
    for (var word in _selectedWords) {
      final updatedWord = word.copyWith(group: groupName);
      await _repository.updateWord(updatedWord);
    }
    _selectedWords.clear();
    _isSelectionMode = false;
    notifyListeners();
  }

  /// Renames a group
  Future<void> renameGroup(String oldName, String newName) async {
    final wordsInGroup = _words.where((w) => w.group == oldName);
    for (var word in wordsInGroup) {
      final updatedWord = word.copyWith(group: newName);
      await _repository.updateWord(updatedWord);
    }
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
  }

  /// Adds a single word to an existing group
  Future<void> addWordToGroup(Word word, String groupName) async {
    final updatedWord = word.copyWith(group: groupName);
    await _repository.updateWord(updatedWord);
  }

  /// Moves all selected words to an existing group
  Future<void> moveSelectedWordsToGroup(String groupName) async {
    if (_selectedWords.isEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      for (var word in _selectedWords) {
        final updatedWord = word.copyWith(group: groupName);
        await _repository.updateWord(updatedWord);
      }
      _selectedWords.clear();
      _isSelectionMode = false;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    // Stream will automatically push the update.
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
    // Stream will automatically push the update.
  }

  /// Returns words that are due for review (nextReviewDate <= now or null)
  /// Skips words that are already mastered (status >= 3)
  List<Word> getWordsForReview() {
    final now = DateTime.now();
    return _words.where((word) {
      final isDue =
          word.nextReviewDate == null ||
          word.nextReviewDate!.isBefore(now) ||
          word.nextReviewDate!.isAtSameMomentAs(now);
      final isNotMastered = (word.status ?? 0) < 3;
      return isDue && isNotMastered;
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
