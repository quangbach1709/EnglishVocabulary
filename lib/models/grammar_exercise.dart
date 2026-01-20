class GrammarExercise {
  final String topicSource;
  final List<String> parts; // [part1, part2] -> part1 + blank + part2
  final String correctAnswer;
  final String hint;

  GrammarExercise({
    required this.topicSource,
    required this.parts,
    required this.correctAnswer,
    required this.hint,
  });

  factory GrammarExercise.fromJson(Map<String, dynamic> json) {
    return GrammarExercise(
      topicSource: json['topic_source'] ?? '',
      parts:
          (json['parts'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      correctAnswer: json['correct_answer'] ?? '',
      hint: json['hint'] ?? '',
    );
  }
}
