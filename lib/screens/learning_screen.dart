import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/word.dart';

class LearningScreen extends StatefulWidget {
  final Word word;

  const LearningScreen({super.key, required this.word});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  final TextEditingController _controller = TextEditingController();
  final FlutterTts flutterTts = FlutterTts();
  bool? _isCorrect;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await flutterTts.setLanguage("en-US");
  }

  Future<void> _speak() async {
    await flutterTts.speak(widget.word.word);
  }

  void _checkAnswer() {
    setState(() {
      if (_controller.text.trim().toLowerCase() ==
          widget.word.word.toLowerCase()) {
        _isCorrect = true;
        _showDetails = true;
        _speak();
      } else {
        _isCorrect = false;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learning Mode')),
      body: Padding(
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
              widget.word.meaningVi,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Type English word',
                border: const OutlineInputBorder(),
                errorText: _isCorrect == false ? 'Incorrect, try again!' : null,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _checkAnswer, child: const Text('Check')),
            const SizedBox(height: 30),
            if (_showDetails) ...[
              const Divider(),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.word.word,
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
                widget.word.ipa,
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 20),
              const Text(
                'Example:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(widget.word.exampleEn),
              Text(
                widget.word.exampleVi,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
