class GrammarExercise {
  final String topicSource;
  final List<String> parts; // [part1, part2, part3] -> part1 + blank1 + part2 + blank2 + part3
  final List<String> correctAnswers; // Multiple answers for multiple blanks
  final String hint;

  GrammarExercise({
    required this.topicSource,
    required this.parts,
    required this.correctAnswers,
    required this.hint,
  });

  String get correctAnswer => correctAnswers.join(', ');

  factory GrammarExercise.fromJson(Map<String, dynamic> json) {
    // Handle both single string and list for correct_answer(s)
    List<String> answers = [];
    if (json['correct_answers'] is List) {
      answers = (json['correct_answers'] as List).map((e) => e.toString()).toList();
    } else if (json['correct_answer'] != null) {
      answers = [json['correct_answer'].toString()];
    }

    return GrammarExercise(
      topicSource: json['topic_source'] ?? '',
      parts:
          (json['parts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      correctAnswers: answers,
      hint: json['hint'] ?? '',
    );
  }
}
