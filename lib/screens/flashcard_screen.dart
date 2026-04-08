import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../services/tts_service.dart';

/// Flashcard study mode
enum FlashcardMode { meaning, synonym, antonym }

class FlashcardScreen extends StatefulWidget {
  final List<Word> words;
  final FlashcardMode initialMode;

  const FlashcardScreen({
    super.key,
    required this.words,
    this.initialMode = FlashcardMode.meaning,
  });

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late List<Word> _reviewWords;
  late FlashcardMode _currentMode;
  int _currentIndex = 0;
  GlobalKey<FlipCardState> cardKey = GlobalKey<FlipCardState>();
  bool _isCardFlipped = false;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _filterAndShuffleWords();
  }

  /// Filters words based on the current mode and shuffles them
  void _filterAndShuffleWords() {
    List<Word> filtered;
    switch (_currentMode) {
      case FlashcardMode.meaning:
        // All words are valid for meaning mode
        filtered = List.from(widget.words);
        break;
      case FlashcardMode.synonym:
        // Only words with non-empty synonyms
        filtered = widget.words
            .where((w) => w.synonym != null && w.synonym!.isNotEmpty)
            .toList();
        break;
      case FlashcardMode.antonym:
        // Only words with non-empty antonyms
        filtered = widget.words
            .where((w) => w.antonym != null && w.antonym!.isNotEmpty)
            .toList();
        break;
    }
    _reviewWords = filtered..shuffle();
    _currentIndex = 0;
    _isCardFlipped = false;
    cardKey = GlobalKey<FlipCardState>();
  }

  /// Changes the flashcard mode and re-filters the word list
  void _changeMode(FlashcardMode newMode) {
    if (newMode != _currentMode) {
      setState(() {
        _currentMode = newMode;
        _filterAndShuffleWords();
      });
    }
  }

  /// Gets the back card content based on the current mode
  String _getBackContent(Word word) {
    switch (_currentMode) {
      case FlashcardMode.meaning:
        return word.primaryShortMeaning;
      case FlashcardMode.synonym:
        final synonym = word.synonym ?? '';
        final synonymMeaning = word.synonymMeaningVi ?? '';
        return synonymMeaning.isNotEmpty
            ? '$synonym\n($synonymMeaning)'
            : synonym;
      case FlashcardMode.antonym:
        final antonym = word.antonym ?? '';
        final antonymMeaning = word.antonymMeaningVi ?? '';
        return antonymMeaning.isNotEmpty
            ? '$antonym\n($antonymMeaning)'
            : antonym;
    }
  }

  /// Gets the mode label for display
  String _getModeLabel(FlashcardMode mode) {
    switch (mode) {
      case FlashcardMode.meaning:
        return 'Nghĩa';
      case FlashcardMode.synonym:
        return 'Đồng nghĩa';
      case FlashcardMode.antonym:
        return 'Trái nghĩa';
    }
  }

  Future<void> _speak() async {
    await TtsService.instance.speak(_reviewWords[_currentIndex].word);
  }

  Word get currentWord => _reviewWords[_currentIndex];

  void _nextCard() {
    if (_currentIndex < _reviewWords.length - 1) {
      setState(() {
        _currentIndex++;
        _isCardFlipped = false;
        cardKey = GlobalKey<FlipCardState>();
      });
    } else {
      // Review complete
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Review Complete!'),
        content: Text('You reviewed ${_reviewWords.length} words.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to home
            },
            child: const Text('Done'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _reviewWords.shuffle();
                _isCardFlipped = false;
                cardKey = GlobalKey<FlipCardState>();
              });
            },
            child: const Text('Review Again'),
          ),
        ],
      ),
    );
  }

  void _rateWord(int quality) {
    final provider = Provider.of<WordProvider>(context, listen: false);
    provider.updateWordSRS(currentWord, quality);
    _nextCard();
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reviewWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcard Review')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _currentMode == FlashcardMode.synonym
                    ? Icons.compare_arrows
                    : _currentMode == FlashcardMode.antonym
                    ? Icons.swap_horiz
                    : Icons.translate,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                _getEmptyMessage(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              _buildModeSelector(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Flashcard (${_currentIndex + 1}/${_reviewWords.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: _speak,
            tooltip: 'Listen',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Mode selector
            _buildModeSelector(),
            const SizedBox(height: 12),

            // Progress indicator
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _reviewWords.length,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_getModeColor()),
            ),
            const SizedBox(height: 20),

            // Flashcard
            Expanded(
              child: FlipCard(
                key: cardKey,
                direction: FlipDirection.HORIZONTAL,
                onFlip: () {
                  setState(() {
                    _isCardFlipped = !_isCardFlipped;
                  });
                  if (!_isCardFlipped) {
                    _speak();
                  }
                },
                front: _buildCardFront(),
                back: _buildCardBack(),
              ),
            ),

            const SizedBox(height: 20),

            // Hint text
            Text(
              _isCardFlipped ? 'Rate your answer:' : 'Tap card to reveal',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 10),

            // SRS Rating Buttons (only show when flipped)
            if (_isCardFlipped) _buildRatingButtons(),
          ],
        ),
      ),
    );
  }

  String _getEmptyMessage() {
    switch (_currentMode) {
      case FlashcardMode.meaning:
        return 'No words to review!';
      case FlashcardMode.synonym:
        return 'Không có từ nào có đồng nghĩa.\nHãy thêm cặp từ đồng nghĩa trong mục "Thêm hàng loạt".';
      case FlashcardMode.antonym:
        return 'Không có từ nào có trái nghĩa.\nHãy thêm cặp từ trái nghĩa trong mục "Thêm hàng loạt".';
    }
  }

  Color _getModeColor() {
    switch (_currentMode) {
      case FlashcardMode.meaning:
        return Colors.blue;
      case FlashcardMode.synonym:
        return Colors.purple;
      case FlashcardMode.antonym:
        return Colors.orange;
    }
  }

  Widget _buildModeSelector() {
    return SegmentedButton<FlashcardMode>(
      segments: [
        ButtonSegment(
          value: FlashcardMode.meaning,
          label: Text(_getModeLabel(FlashcardMode.meaning)),
          icon: const Icon(Icons.translate, size: 18),
        ),
        ButtonSegment(
          value: FlashcardMode.synonym,
          label: Text(_getModeLabel(FlashcardMode.synonym)),
          icon: const Icon(Icons.compare_arrows, size: 18),
        ),
        ButtonSegment(
          value: FlashcardMode.antonym,
          label: Text(_getModeLabel(FlashcardMode.antonym)),
          icon: const Icon(Icons.swap_horiz, size: 18),
        ),
      ],
      selected: {_currentMode},
      onSelectionChanged: (Set<FlashcardMode> newSelection) {
        _changeMode(newSelection.first);
      },
    );
  }

  Widget _buildCardFront() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getFrontGradientColors(),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_getFrontIcon(), size: 48, color: Colors.white70),
              const SizedBox(height: 20),
              Text(
                currentWord.word,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Show meaning hint in synonym/antonym mode
              if (_currentMode != FlashcardMode.meaning &&
                  currentWord.meaningVi.isNotEmpty)
                Text(
                  '(${currentWord.meaningVi})',
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              if (_currentMode == FlashcardMode.meaning &&
                  currentWord.ipa.isNotEmpty)
                Text(
                  currentWord.ipa,
                  style: const TextStyle(
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                    color: Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              IconButton(
                icon: const Icon(
                  Icons.volume_up,
                  size: 32,
                  color: Colors.white,
                ),
                onPressed: _speak,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _getFrontGradientColors() {
    switch (_currentMode) {
      case FlashcardMode.meaning:
        return [Colors.blue, Colors.blueAccent];
      case FlashcardMode.synonym:
        return [Colors.purple, Colors.purpleAccent];
      case FlashcardMode.antonym:
        return [Colors.orange, Colors.deepOrange];
    }
  }

  IconData _getFrontIcon() {
    switch (_currentMode) {
      case FlashcardMode.meaning:
        return Icons.translate;
      case FlashcardMode.synonym:
        return Icons.compare_arrows;
      case FlashcardMode.antonym:
        return Icons.swap_horiz;
    }
  }

  Widget _buildCardBack() {
    final backContent = _getBackContent(currentWord);
    final showExamples = _currentMode == FlashcardMode.meaning;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getBackGradientColors(),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getBackIcon(), size: 40, color: Colors.white70),
                const SizedBox(height: 16),
                Text(
                  backContent,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Show examples only in meaning mode
                if (showExamples && currentWord.examplesEn.isNotEmpty) ...[
                  const Divider(color: Colors.white38),
                  const SizedBox(height: 10),
                  const Text(
                    'Example:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentWord.examplesEn.first,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (currentWord.examplesVi.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        currentWord.examplesVi.first,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getBackGradientColors() {
    switch (_currentMode) {
      case FlashcardMode.meaning:
        return [Colors.green, Colors.teal];
      case FlashcardMode.synonym:
        return [Colors.deepPurple, Colors.purple];
      case FlashcardMode.antonym:
        return [Colors.red, Colors.deepOrange];
    }
  }

  IconData _getBackIcon() {
    switch (_currentMode) {
      case FlashcardMode.meaning:
        return Icons.lightbulb_outline;
      case FlashcardMode.synonym:
        return Icons.check_circle_outline;
      case FlashcardMode.antonym:
        return Icons.swap_horizontal_circle_outlined;
    }
  }

  Widget _buildRatingButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildRatingButton(
          label: 'Again',
          color: Colors.red,
          icon: Icons.replay,
          quality: 0,
        ),
        _buildRatingButton(
          label: 'Hard',
          color: Colors.orange,
          icon: Icons.sentiment_dissatisfied,
          quality: 1,
        ),
        _buildRatingButton(
          label: 'Good',
          color: Colors.amber,
          icon: Icons.sentiment_satisfied,
          quality: 2,
        ),
        _buildRatingButton(
          label: 'Easy',
          color: Colors.green,
          icon: Icons.sentiment_very_satisfied,
          quality: 3,
        ),
      ],
    );
  }

  Widget _buildRatingButton({
    required String label,
    required Color color,
    required IconData icon,
    required int quality,
  }) {
    return InkWell(
      onTap: () => _rateWord(quality),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
