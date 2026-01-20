import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'grammar_topic.g.dart';

@HiveType(typeId: 2)
class GrammarFormula extends HiveObject {
  @HiveField(0)
  final String type;

  @HiveField(1)
  final String structure;

  @HiveField(2)
  final String example;

  @HiveField(3)
  final String explanation;

  GrammarFormula({
    required this.type,
    required this.structure,
    required this.example,
    required this.explanation,
  });

  factory GrammarFormula.fromJson(Map<String, dynamic> json) {
    return GrammarFormula(
      type: json['type'] ?? '',
      structure: json['structure'] ?? '',
      example: json['example'] ?? '',
      explanation: json['explanation'] ?? '',
    );
  }
}

@HiveType(typeId: 3)
class GrammarUsage extends HiveObject {
  @HiveField(0)
  final String context;

  @HiveField(1)
  final String detail;

  GrammarUsage({required this.context, required this.detail});

  factory GrammarUsage.fromJson(Map<String, dynamic> json) {
    return GrammarUsage(
      context: json['context'] ?? '',
      detail: json['detail'] ?? '',
    );
  }
}

@HiveType(typeId: 1)
class GrammarTopic extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String topicEn;

  @HiveField(2)
  final String topicVi;

  @HiveField(3)
  final String definition;

  @HiveField(4)
  final List<GrammarFormula> formulas;

  @HiveField(5)
  final List<GrammarUsage> usages;

  @HiveField(6)
  final List<String> signs;

  @HiveField(7)
  final String tipsForBeginners;

  GrammarTopic({
    required this.id,
    required this.topicEn,
    required this.topicVi,
    required this.definition,
    required this.formulas,
    required this.usages,
    required this.signs,
    required this.tipsForBeginners,
  });

  factory GrammarTopic.fromJson(Map<String, dynamic> json) {
    return GrammarTopic(
      id: json['id'] ?? const Uuid().v4(), // Generate ID if null
      topicEn: json['topic_en'] ?? '',
      topicVi: json['topic_vi'] ?? '',
      definition: json['definition'] ?? '',
      formulas:
          (json['formulas'] as List<dynamic>?)
              ?.map((e) => GrammarFormula.fromJson(e))
              .toList() ??
          [],
      usages:
          (json['usages'] as List<dynamic>?)
              ?.map((e) => GrammarUsage.fromJson(e))
              .toList() ??
          [],
      signs:
          (json['signs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tipsForBeginners: json['tips_for_beginners'] ?? '',
    );
  }
}
