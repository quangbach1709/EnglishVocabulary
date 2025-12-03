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
  final String exampleEn;

  @HiveField(4)
  final String exampleVi;

  Word({
    required this.word,
    required this.ipa,
    required this.meaningVi,
    required this.exampleEn,
    required this.exampleVi,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      word: json['word'] ?? '',
      ipa: json['ipa'] ?? '',
      meaningVi: json['meaning_vi'] ?? '',
      exampleEn: json['example_en'] ?? '',
      exampleVi: json['example_vi'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      'ipa': ipa,
      'meaning_vi': meaningVi,
      'example_en': exampleEn,
      'example_vi': exampleVi,
    };
  }
}
