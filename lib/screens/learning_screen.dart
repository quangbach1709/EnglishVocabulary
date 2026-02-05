import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word.dart';
import '../services/firestore_service.dart';

class LearningScreen extends StatefulWidget {
  final Word? word; // For single word learning
  final List<Word>? words; // For review mode

  const LearningScreen({super.key, this.word, this.words});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final TextEditingController _controller = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();

  late List<Word> _sessionWords;
  int _currentIndex = 0;

  bool? _isCorrect;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _initData();
    _initTts();
  }

  void _initData() {
    if (widget.words != null && widget.words!.isNotEmpty) {
      _sessionWords = List.from(widget.words!);
      _sessionWords.shuffle(); // Randomize order as requested
    } else if (widget.word != null) {
      _sessionWords = [widget.word!];
    } else {
      _sessionWords = [];
    }
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
  }

  Word get currentWord => _sessionWords[_currentIndex];

  Future<void> _speak() async {
    await flutterTts.speak(currentWord.word);
  }

  void _checkAnswer() {
    if (_showDetails) return; // Prevent double check

    setState(() {
      if (_controller.text.trim().toLowerCase() ==
          currentWord.word.toLowerCase()) {
        _handleCorrectAnswer();
      } else {
        _isCorrect = false;
        _speak(); // Optional: speak on wrong answer too
      }
    });
  }

  void _handleCorrectAnswer() {
    _isCorrect = true;
    _showDetails = true;
    _speak();
  }

  Future<void> _onSkipPressed() async {
    if (_showDetails) return;

    // 1. Reveal Answer
    setState(() {
      _controller.text = currentWord.word;
      _isCorrect = false;
      _showDetails = true;
    });
    _speak();

    // 2. Update SRS (Forgot)
    await FirestoreService().markWordAsForgot(currentWord);

    // 3. Auto-advance after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        if (_currentIndex < _sessionWords.length - 1) {
          _nextWord();
        } else {
          _showCompletionDialog();
        }
      }
    });
  }

  void _nextWord() {
    if (_currentIndex < _sessionWords.length - 1) {
      setState(() {
        _currentIndex++;
        _resetState();
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _resetState() {
    _controller.clear();
    _isCorrect = null;
    _showDetails = false;
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🎉 Session Complete!'),
        content: Text('You practiced ${_sessionWords.length} words.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Back to home
            },
            child: const Text('Back to Home'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentIndex = 0;
                _resetState();
                // Optional: shuffle again for review
                // _sessionWords.shuffle();
              });
            },
            child: const Text('Practice Again'),
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
    if (_sessionWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Learning Mode')),
        body: const Center(child: Text('No words to learn!')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Spelling (${_currentIndex + 1}/${_sessionWords.length})'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Bar
              if (_sessionWords.length > 1)
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / _sessionWords.length,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              const SizedBox(height: 20),

              Text(
                'Translate this to English:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              Text(
                currentWord.primaryShortMeaning,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                onSubmitted: (_) => _checkAnswer(),
                decoration: InputDecoration(
                  labelText: 'Type English word',
                  border: const OutlineInputBorder(),
                  errorText: _isCorrect == false
                      ? 'Incorrect, try again!'
                      : null,
                  suffixIcon: _isCorrect == true
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _showDetails
                    ? (_sessionWords.length > 1 &&
                              _currentIndex < _sessionWords.length - 1
                          ? _nextWord
                          : _showCompletionDialog)
                    : _checkAnswer,
                child: Text(_showDetails ? 'Next' : 'Check'),
              ),
              if (!_showDetails) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _onSkipPressed,
                  child: const Text('Bỏ qua (Skip)'),
                ),
              ],
              const SizedBox(height: 30),
              if (_showDetails) ...[
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
                ...currentWord.allExamples.map((example) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('- ${example.text}'),
                        Text(
                          '  ${example.translation}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
