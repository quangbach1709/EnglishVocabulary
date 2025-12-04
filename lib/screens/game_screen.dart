import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word.dart';

class GameScreen extends StatefulWidget {
  final List<Word> words;

  const GameScreen({super.key, required this.words});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Word _targetWord;
  late List<String> _options;
  late bool _isEnglishQuestion;
  bool? _isCorrect;
  bool _showDetails = false;
  final FlutterTts flutterTts = FlutterTts();
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initTts();
    _nextQuestion();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
  }

  void _nextQuestion() {
    setState(() {
      _showDetails = false;
      _isCorrect = null;

      // Select target word
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
          _targetWord.meaningVi,
          ...distractors.map((w) => w.meaningVi),
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
      correct = selectedOption == _targetWord.meaningVi;
    } else {
      correct = selectedOption == _targetWord.word;
    }

    setState(() {
      _isCorrect = correct;
      if (correct) {
        _showDetails = true;
        _speak();
      }
    });
  }

  Future<void> _speak() async {
    await flutterTts.speak(_targetWord.word);
  }

  @override
  void dispose() {
    flutterTts.stop();
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
      appBar: AppBar(title: const Text('Game Mode')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEnglishQuestion
                  ? 'Choose the meaning for:'
                  : 'Choose the English word for:',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              _isEnglishQuestion ? _targetWord.word : _targetWord.meaningVi,
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
                        ? _targetWord.meaningVi
                        : _targetWord.word)) {
                  buttonColor = Colors.green; // Correct answer
                } else if (_isCorrect == false &&
                    option == _targetWord.meaningVi) {
                  // Highlight correct answer if wrong one was picked (optional logic, simplified here)
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
              ..._targetWord.examplesEn.asMap().entries.map((entry) {
                final index = entry.key;
                final exEn = entry.value;
                final exVi = _targetWord.examplesVi.length > index
                    ? _targetWord.examplesVi[index]
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
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Next Question'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
