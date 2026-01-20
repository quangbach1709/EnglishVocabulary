import 'package:flutter/material.dart';
import '../models/grammar_exercise.dart';

class GrammarPracticeScreen extends StatefulWidget {
  final List<GrammarExercise> exercises;

  const GrammarPracticeScreen({super.key, required this.exercises});

  @override
  State<GrammarPracticeScreen> createState() => _GrammarPracticeScreenState();
}

class _GrammarPracticeScreenState extends State<GrammarPracticeScreen> {
  int _currentIndex = 0;
  int _score = 0;
  bool _isChecked = false;
  bool _isCorrect = false;
  bool _showHint = false;
  final TextEditingController _controller = TextEditingController();

  GrammarExercise get currentExercise => widget.exercises[_currentIndex];

  void _checkAnswer() {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _isChecked = true;
      _isCorrect =
          _controller.text.trim().toLowerCase() ==
          currentExercise.correctAnswer.toLowerCase();
      if (_isCorrect) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex < widget.exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _isChecked = false;
        _isCorrect = false;
        _showHint = false;
        _controller.clear();
      });
    } else {
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Practice Complete!'),
        content: Text(
          'You scored $_score / ${widget.exercises.length}\n\n${_getFeedbackMessage()}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to Detail Screen
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  String _getFeedbackMessage() {
    double percentage = _score / widget.exercises.length;
    if (percentage == 1.0) return 'Perfect! You mastered this topic.';
    if (percentage >= 0.8) return 'Great job! Keep practicing.';
    if (percentage >= 0.5) return 'Good effort. Review the rules again.';
    return 'Don\'t give up! Read the theory and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Practice ${_currentIndex + 1}/${widget.exercises.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Bar
            LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.exercises.length,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 24),

            // Question Section
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Text(
                      "Grammar Challenge",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (currentExercise.parts.isNotEmpty)
                          Text(
                            currentExercise.parts[0],
                            style: const TextStyle(fontSize: 18),
                          ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            controller: _controller,
                            enabled: !_isChecked,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              color: _isChecked
                                  ? (_isCorrect ? Colors.green : Colors.red)
                                  : Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 4,
                              ),
                            ),
                            onSubmitted: (_) => _checkAnswer(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (currentExercise.parts.length > 1)
                          Text(
                            currentExercise.parts[1],
                            style: const TextStyle(fontSize: 18),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Feedback & Hint
            if (_isChecked)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isCorrect
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isCorrect ? Colors.green : Colors.red,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _isCorrect ? 'Correct!' : 'Incorrect',
                      style: TextStyle(
                        color: _isCorrect ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (!_isCorrect) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Correct answer: ${currentExercise.correctAnswer}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              )
            else if (_showHint)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lightbulb, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      // Avoid overflow
                      child: Text(
                        'Hint: ${currentExercise.hint}',
                        style: const TextStyle(color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              )
            else
              TextButton.icon(
                onPressed: () => setState(() => _showHint = true),
                icon: const Icon(Icons.help_outline),
                label: const Text('Show Hint'),
              ),

            const Spacer(),

            // Action Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isChecked ? _nextQuestion : _checkAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isChecked
                      ? (_isCorrect ? Colors.green : Colors.blue)
                      : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  _isChecked
                      ? (_currentIndex == widget.exercises.length - 1
                            ? 'Finish'
                            : 'Next')
                      : 'Check Answer',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
