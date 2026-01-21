import 'package:uuid/uuid.dart';

class GrammarFormula {
  final String type;
  final String structure;
  final String example;
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

  factory GrammarFormula.fromMap(Map<String, dynamic> map) {
    return GrammarFormula(
      type: map['type'] ?? '',
      structure: map['structure'] ?? '',
      example: map['example'] ?? '',
      explanation: map['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'structure': structure,
      'example': example,
      'explanation': explanation,
    };
  }
}

class GrammarUsage {
  final String context;
  final String detail;

  GrammarUsage({required this.context, required this.detail});

  factory GrammarUsage.fromJson(Map<String, dynamic> json) {
    return GrammarUsage(
      context: json['context'] ?? '',
      detail: json['detail'] ?? '',
    );
  }

  factory GrammarUsage.fromMap(Map<String, dynamic> map) {
    return GrammarUsage(
      context: map['context'] ?? '',
      detail: map['detail'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'context': context, 'detail': detail};
  }
}

class GrammarTopic {
  final String id;
  final String topicEn;
  final String topicVi;
  final String definition;
  final List<GrammarFormula> formulas;
  final List<GrammarUsage> usages;
  final List<String> signs;
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
      id: json['id'] ?? const Uuid().v4(),
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

  factory GrammarTopic.fromMap(Map<String, dynamic> map) {
    return GrammarTopic(
      id: map['id'] ?? const Uuid().v4(),
      topicEn: map['topic_en'] ?? '',
      topicVi: map['topic_vi'] ?? '',
      definition: map['definition'] ?? '',
      formulas:
          (map['formulas'] as List<dynamic>?)
              ?.map((e) => GrammarFormula.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      usages:
          (map['usages'] as List<dynamic>?)
              ?.map((e) => GrammarUsage.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      signs:
          (map['signs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      tipsForBeginners: map['tips_for_beginners'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'topic_en': topicEn,
      'topic_vi': topicVi,
      'definition': definition,
      'formulas': formulas.map((e) => e.toMap()).toList(),
      'usages': usages.map((e) => e.toMap()).toList(),
      'signs': signs,
      'tips_for_beginners': tipsForBeginners,
    };
  }

  GrammarTopic copyWith({
    String? id,
    String? topicEn,
    String? topicVi,
    String? definition,
    List<GrammarFormula>? formulas,
    List<GrammarUsage>? usages,
    List<String>? signs,
    String? tipsForBeginners,
  }) {
    return GrammarTopic(
      id: id ?? this.id,
      topicEn: topicEn ?? this.topicEn,
      topicVi: topicVi ?? this.topicVi,
      definition: definition ?? this.definition,
      formulas: formulas ?? this.formulas,
      usages: usages ?? this.usages,
      signs: signs ?? this.signs,
      tipsForBeginners: tipsForBeginners ?? this.tipsForBeginners,
    );
  }
}
