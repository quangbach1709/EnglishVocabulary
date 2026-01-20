import 'package:hive/hive.dart';

part 'word.g.dart';

@HiveType(typeId: 0)
class Word extends HiveObject {
  @HiveField(0)
  final String word;

  @HiveField(1)
  final String ipa;

  @HiveField(2)
  final String meaningVi;

  @HiveField(3)
  final List<String> examplesEn;

  @HiveField(4)
  final List<String> examplesVi;

  @HiveField(5)
  String? group;

  // SRS (Spaced Repetition System) Fields
  @HiveField(6)
  DateTime? nextReviewDate;

  @HiveField(7, defaultValue: 0)
  int interval;

  @HiveField(8, defaultValue: 2.5)
  double easeFactor;

  @HiveField(9, defaultValue: 0)
  int status; // 0: New/Forgot (Red), 1: Hard (Orange), 2: Good (Yellow), 3: Easy (Light Green)

  Word({
    required this.word,
    required this.ipa,
    required this.meaningVi,
    required this.examplesEn,
    required this.examplesVi,
    this.group,
    this.nextReviewDate,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.status = 0,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      word: json['word'] ?? '',
      ipa: json['ipa'] ?? '',
      meaningVi: json['meaning_vi'] ?? '',
      examplesEn:
          (json['examples_en'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      examplesVi:
          (json['examples_vi'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      group: json['group'],
      nextReviewDate: json['next_review_date'] != null
          ? DateTime.parse(json['next_review_date'])
          : null,
      interval: json['interval'] ?? 0,
      easeFactor: (json['ease_factor'] ?? 2.5).toDouble(),
      status: json['status'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'ipa': ipa,
      'meaning_vi': meaningVi,
      'examples_en': examplesEn,
      'examples_vi': examplesVi,
      'group': group,
      'next_review_date': nextReviewDate?.toIso8601String(),
      'interval': interval,
      'ease_factor': easeFactor,
      'status': status,
    };
  }
}
