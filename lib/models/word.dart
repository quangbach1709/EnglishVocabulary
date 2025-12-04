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

  Word({
    required this.word,
    required this.ipa,
    required this.meaningVi,
    required this.examplesEn,
    required this.examplesVi,
    this.group,
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
    };
  }
}
