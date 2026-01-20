import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flip_card/flip_card.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';

class FlashcardScreen extends StatefulWidget {
  final List<Word> words;

  const FlashcardScreen({super.key, required this.words});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late List<Word> _reviewWords;
  int _currentIndex = 0;
  final FlutterTts flutterTts = FlutterTts();
  GlobalKey<FlipCardState> cardKey = GlobalKey<FlipCardState>();
  bool _isCardFlipped = false;

  @override
  void initState() {
    super.initState();
    _reviewWords = List.from(widget.words)..shuffle();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
  }

  Future<void> _speak() async {
    await flutterTts.speak(_reviewWords[_currentIndex].word);
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
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reviewWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Flashcard Review')),
        body: const Center(child: Text('No words to review!')),
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
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentIndex + 1) / _reviewWords.length,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
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

  Widget _buildCardFront() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue, Colors.blueAccent],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.translate, size: 48, color: Colors.white70),
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

  Widget _buildCardBack() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.green, Colors.teal],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lightbulb_outline,
                  size: 40,
                  color: Colors.white70,
                ),
                const SizedBox(height: 16),
                Text(
                  currentWord.meaningVi,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (currentWord.examplesEn.isNotEmpty) ...[
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
