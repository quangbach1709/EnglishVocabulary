import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word.dart';

class ReviewScreen extends StatefulWidget {
  final List<Word> words;

  const ReviewScreen({super.key, required this.words});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late List<Word> _reviewList;
  int _currentIndex = 0;
  final TextEditingController _controller = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  bool? _isCorrect;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _reviewList = List.from(widget.words)..shuffle(); // Randomize order
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
  }

  Future<void> _speak() async {
    await flutterTts.speak(_reviewList[_currentIndex].word);
  }

  void _checkAnswer() {
    setState(() {
      if (_controller.text.trim().toLowerCase() ==
          _reviewList[_currentIndex].word.toLowerCase()) {
        _isCorrect = true;
        _showDetails = true;
        _speak();
      } else {
        _isCorrect = false;
      }
    });
  }

  void _nextWord() {
    setState(() {
      if (_currentIndex < _reviewList.length - 1) {
        _currentIndex++;
        _controller.clear();
        _isCorrect = null;
        _showDetails = false;
      } else {
        // Finished
        _showFinishDialog();
      }
    });
  }

  void _showFinishDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Review Complete!'),
        content: const Text('You have reviewed all words.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to Home
            },
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reviewList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Mode')),
        body: const Center(child: Text('No words to review.')),
      );
    }

    final currentWord = _reviewList[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Review (${_currentIndex + 1}/${_reviewList.length})'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Translate this to English:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              currentWord.meaningVi,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              enabled: !_showDetails, // Disable input after correct answer
              decoration: InputDecoration(
                labelText: 'Type English word',
                border: const OutlineInputBorder(),
                errorText: _isCorrect == false ? 'Incorrect, try again!' : null,
              ),
              onSubmitted: (_) => _checkAnswer(),
            ),
            const SizedBox(height: 20),
            if (!_showDetails)
              ElevatedButton(
                onPressed: _checkAnswer,
                child: const Text('Check'),
              )
            else ...[
              const Divider(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentWord.word,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: _speak,
                  ),
                ],
              ),
              Text(
                currentWord.ipa,
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 20),
              const SizedBox(height: 20),
              const Text(
                'Examples:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...currentWord.examplesEn.asMap().entries.map((entry) {
                final index = entry.key;
                final exEn = entry.value;
                final exVi = currentWord.examplesVi.length > index
                    ? currentWord.examplesVi[index]
                    : '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('- $exEn'),
                      Text(
                        '  $exVi',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _nextWord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  _currentIndex < _reviewList.length - 1
                      ? 'Next Word'
                      : 'Finish Review',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
