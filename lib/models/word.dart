import 'package:cloud_firestore/cloud_firestore.dart';

class Word {
  final String word;
  final String ipa;
  final String meaningVi;
  final List<String> examplesEn;
  final List<String> examplesVi;
  String? group;

  // SRS (Spaced Repetition System) Fields
  DateTime? nextReviewDate;
  int interval;
  double easeFactor;
  int
  status; // 0: New/Forgot (Red), 1: Hard (Orange), 2: Good (Yellow), 3: Easy (Light Green)

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

  /// Converts the Word object to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'ipa': ipa,
      'meaning_vi': meaningVi,
      'examples_en': examplesEn,
      'examples_vi': examplesVi,
      'group': group,
      'next_review_date': nextReviewDate != null
          ? Timestamp.fromDate(nextReviewDate!)
          : null,
      'interval': interval,
      'ease_factor': easeFactor,
      'status': status,
    };
  }

  /// Creates a Word object from a Firestore Map
  factory Word.fromMap(Map<String, dynamic> map) {
    return Word(
      word: map['word'] ?? '',
      ipa: map['ipa'] ?? '',
      meaningVi: map['meaning_vi'] ?? '',
      examplesEn:
          (map['examples_en'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      examplesVi:
          (map['examples_vi'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      group: map['group'],
      nextReviewDate: map['next_review_date'] != null
          ? (map['next_review_date'] as Timestamp).toDate()
          : null,
      interval: map['interval'] ?? 0,
      easeFactor: (map['ease_factor'] ?? 2.5).toDouble(),
      status: map['status'] ?? 0,
    );
  }

  /// Creates a Word object from JSON (for Gemini API response)
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

  /// Converts the Word object to JSON
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

  /// Returns the lowercase English word (used as Document ID)
  String get english => word.toLowerCase();

  /// Creates a copy of the Word with updated fields
  Word copyWith({
    String? word,
    String? ipa,
    String? meaningVi,
    List<String>? examplesEn,
    List<String>? examplesVi,
    String? group,
    DateTime? nextReviewDate,
    int? interval,
    double? easeFactor,
    int? status,
  }) {
    return Word(
      word: word ?? this.word,
      ipa: ipa ?? this.ipa,
      meaningVi: meaningVi ?? this.meaningVi,
      examplesEn: examplesEn ?? this.examplesEn,
      examplesVi: examplesVi ?? this.examplesVi,
      group: group ?? this.group,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      interval: interval ?? this.interval,
      easeFactor: easeFactor ?? this.easeFactor,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Word && other.english == english;
  }

  @override
  int get hashCode => english.hashCode;
}
