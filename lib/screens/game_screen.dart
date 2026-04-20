import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../providers/word_provider.dart';
import '../services/tts_service.dart';

class GameScreen extends StatefulWidget {
  final List<Word> words;
  final bool isDailySession;

  const GameScreen({
    super.key,
    required this.words,
    this.isDailySession = false,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Word _targetWord;
  late List<String> _options;
  late bool _isEnglishQuestion;
  bool? _isCorrect;
  bool _showDetails = false;
  bool _firstAttempt = true;
  final Random _random = Random();

  int _questionsAnswered = 0;
  final int _totalQuestions = 10; // Or widget.words.length

  @override
  void initState() {
    super.initState();
    _nextQuestion();
  }

  void _nextQuestion() {
    if (widget.isDailySession && _questionsAnswered >= widget.words.length) {
      _showCompletionDialog();
      return;
    }

    setState(() {
      _showDetails = false;
      _isCorrect = null;
      _firstAttempt = true;

      // Select target word
      // In daily session, we could cycle through all words.
      // For now, keep it random but track count.
      _targetWord = widget.words[_random.nextInt(widget.words.length)];

      // Decide question type (50/50 chance)
      _isEnglishQuestion = _random.nextBool();

      // Select distractors
      final otherWords = List<Word>.from(widget.words)..remove(_targetWord);
      otherWords.shuffle();
      final distractors = otherWords.take(3).toList();

      // Prepare options
      if (_isEnglishQuestion) {
        // Question: English -> Options: Vietnamese
        _options = [
          _targetWord.primaryShortMeaning,
          ...distractors.map((w) => w.primaryShortMeaning),
        ];
      } else {
        // Question: Vietnamese -> Options: English
        _options = [_targetWord.word, ...distractors.map((w) => w.word)];
      }
      _options.shuffle();
    });
  }

  void _checkAnswer(String selectedOption) {
    if (_showDetails) return; // Prevent multiple clicks

    bool correct;
    if (_isEnglishQuestion) {
      correct = selectedOption == _targetWord.primaryShortMeaning;
    } else {
      correct = selectedOption == _targetWord.word;
    }

    if (_firstAttempt) {
      final provider = Provider.of<WordProvider>(context, listen: false);
      if (correct) {
        provider.updateWordSRS(_targetWord, 2); // Good
      } else {
        provider.updateWordSRS(_targetWord, 0); // Again
      }
      _firstAttempt = false;
      _questionsAnswered++;
    }

    setState(() {
      _isCorrect = correct;
      if (correct) {
        _showDetails = true;
        _speak();
      }
    });
  }

  Future<void> _onSkipPressed() async {
    if (_showDetails) return;

    // 1. Reveal Answer
    setState(() {
      _showDetails = true;
      _isCorrect = false;
    });
    _speak();

    // 2. Update SRS (Forgot)
    final provider = Provider.of<WordProvider>(context, listen: false);
    await provider.updateWordSRS(_targetWord, 0);
    _questionsAnswered++;

    // 3. Auto-advance after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _nextQuestion();
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          widget.isDailySession
              ? '🎉 Daily Mission Completed! 🎉'
              : '🎉 Game Complete!',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isDailySession)
              const Icon(Icons.stars, color: Colors.yellow, size: 64),
            const SizedBox(height: 16),
            Text(
              'Bạn đã hoàn thành bài tập trắc nghiệm với ${widget.words.length} từ.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Back to home
            },
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  }

  Future<void> _speak() async {
    await TtsService.instance.speak(_targetWord.word);
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.length < 4) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game Mode')),
        body: const Center(child: Text('You need at least 4 words to play!')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isDailySession
              ? 'Daily Quiz (${min(_questionsAnswered + 1, widget.words.length)}/${widget.words.length})'
              : 'Game Mode',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.isDailySession)
              LinearProgressIndicator(
                value: _questionsAnswered / widget.words.length,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            const SizedBox(height: 20),
            Text(
              _isEnglishQuestion
                  ? 'Choose the meaning for:'
                  : 'Choose the English word for:',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              _isEnglishQuestion
                  ? _targetWord.word
                  : _targetWord.primaryShortMeaning,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ..._options.map((option) {
              Color? buttonColor;
              if (_showDetails) {
                if (option ==
                    (_isEnglishQuestion
                        ? _targetWord.primaryShortMeaning
                        : _targetWord.word)) {
                  buttonColor = Colors.green; // Correct answer
                } else if (_isCorrect == false &&
                    option == _targetWord.primaryShortMeaning) {
                  // Highlight correct answer if wrong one was picked
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: ElevatedButton(
                  onPressed: () => _checkAnswer(option),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(option, style: const TextStyle(fontSize: 18)),
                ),
              );
            }),
            const SizedBox(height: 20),
            if (!_showDetails)
              TextButton(
                onPressed: _onSkipPressed,
                child: const Text('Bỏ qua (Skip)'),
              ),
            if (_isCorrect == false)
              const Text(
                'Incorrect! Try again.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            if (_showDetails) ...[
              const Divider(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _targetWord.word,
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
                _targetWord.ipa,
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 20),
              const Text(
                'Examples:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ..._targetWord.allExamples.map((example) {
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
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  _questionsAnswered >= widget.words.length
                      ? 'Finish'
                      : 'Next Question',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
