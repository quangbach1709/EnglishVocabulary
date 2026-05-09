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
  
  // List of controllers for multiple blanks
  List<TextEditingController> _controllers = [];

  GrammarExercise get currentExercise => widget.exercises[_currentIndex];

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    // Clean up old controllers
    for (var controller in _controllers) {
      controller.dispose();
    }
    
    // Each blank is between two parts. N parts means N-1 blanks.
    int blankCount = currentExercise.parts.length - 1;
    if (blankCount < 1) blankCount = 1; // Fallback for safety

    _controllers = List.generate(blankCount, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _checkAnswer() {
    bool allFilled = true;
    for (var controller in _controllers) {
      if (controller.text.trim().isEmpty) {
        allFilled = false;
        break;
      }
    }
    if (!allFilled) return;

    bool allCorrect = true;
    for (int i = 0; i < _controllers.length; i++) {
      String userAnswer = _controllers[i].text.trim().toLowerCase();
      String correctAnswer = "";
      if (i < currentExercise.correctAnswers.length) {
        correctAnswer = currentExercise.correctAnswers[i].toLowerCase();
      }

      if (userAnswer != correctAnswer) {
        allCorrect = false;
        break;
      }
    }

    setState(() {
      _isChecked = true;
      _isCorrect = allCorrect;
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
        _initControllers();
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
                      spacing: 8,
                      runSpacing: 12,
                      children: _buildQuestionWidgets(),
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
                        textAlign: TextAlign.center,
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

  List<Widget> _buildQuestionWidgets() {
    List<Widget> widgets = [];
    
    for (int i = 0; i < currentExercise.parts.length; i++) {
      widgets.add(
        Text(
          currentExercise.parts[i],
          style: const TextStyle(fontSize: 18),
        ),
      );

      if (i < currentExercise.parts.length - 1) {
        int controllerIndex = i;
        if (controllerIndex < _controllers.length) {
          widgets.add(
            SizedBox(
              width: 120,
              child: TextField(
                controller: _controllers[controllerIndex],
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
          );
        }
      }
    }
    
    return widgets;
  }
}
