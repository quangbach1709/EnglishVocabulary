import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================
// Sub-models for rich vocabulary data
// ============================================

/// Verb form/Inflection (e.g., past tense, plural)
class VerbForm {
  final int id;
  final String type; // "Past tense", "Past participle", "Plural", etc.
  final String text;

  VerbForm({required this.id, required this.type, required this.text});

  factory VerbForm.fromJson(Map<String, dynamic> json) {
    return VerbForm(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      text: json['text'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'text': text};
}

/// Pronunciation info with audio URL
class Pronunciation {
  final String pos; // Part of speech this pronunciation is for
  final String lang; // "us" or "uk"
  final String url; // Audio URL
  final String pron; // IPA transcription

  Pronunciation({
    required this.pos,
    required this.lang,
    required this.url,
    required this.pron,
  });

  factory Pronunciation.fromJson(Map<String, dynamic> json) {
    return Pronunciation(
      pos: json['pos'] ?? '',
      lang: json['lang'] ?? 'us',
      url: json['url'] ?? '',
      pron: json['pron'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'pos': pos,
    'lang': lang,
    'url': url,
    'pron': pron,
  };
}

/// Example sentence with translation
class ExampleSentence {
  final int id;
  final String text; // English sentence
  final String translation; // Vietnamese translation

  ExampleSentence({
    required this.id,
    required this.text,
    required this.translation,
  });

  factory ExampleSentence.fromJson(Map<String, dynamic> json) {
    return ExampleSentence(
      id: json['id'] ?? 0,
      text: json['text'] ?? '',
      translation: json['translation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'translation': translation,
  };
}

/// Definition with examples
class Definition {
  final int id;
  final String pos; // Part of speech (verb, noun, adj, etc.)
  final String text; // English definition
  final String translation; // Vietnamese meaning
  final List<ExampleSentence> examples;

  Definition({
    required this.id,
    required this.pos,
    required this.text,
    required this.translation,
    required this.examples,
  });

  factory Definition.fromJson(Map<String, dynamic> json) {
    return Definition(
      id: json['id'] ?? 0,
      pos: json['pos'] ?? '',
      text: json['text'] ?? '',
      translation: json['translation'] ?? '',
      examples: (json['example'] as List<dynamic>?)
              ?.map((e) => ExampleSentence.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pos': pos,
    'text': text,
    'translation': translation,
    'example': examples.map((e) => e.toJson()).toList(),
  };
}

// ============================================
// Main Word Model
// ============================================

class Word {
  final String word;
  
  // New rich data fields
  final List<String> pos; // Parts of speech: ["verb", "noun"]
  final List<VerbForm> verbs; // Verb forms/inflections
  final List<Pronunciation> pronunciations; // Multiple pronunciations
  final List<Definition> definitions; // Definitions with examples
  
  // Legacy fields (for backward compatibility)
  final String ipa; // Primary IPA (computed from pronunciations or legacy)
  final String meaningVi; // Primary Vietnamese meaning (computed from definitions or legacy)
  final List<String> examplesEn; // Legacy examples
  final List<String> examplesVi; // Legacy examples
  
  String? group;

  // SRS (Spaced Repetition System) Fields
  DateTime? nextReviewDate;
  int interval;
  double easeFactor;
  int status; // 0: New/Forgot (Red), 1: Hard (Orange), 2: Good (Yellow), 3: Easy (Light Green)

  Word({
    required this.word,
    this.pos = const [],
    this.verbs = const [],
    this.pronunciations = const [],
    this.definitions = const [],
    this.ipa = '',
    this.meaningVi = '',
    this.examplesEn = const [],
    this.examplesVi = const [],
    this.group,
    this.nextReviewDate,
    this.interval = 0,
    this.easeFactor = 2.5,
    this.status = 0,
  });

  /// Get primary IPA (prefer US pronunciation)
  String get primaryIpa {
    if (pronunciations.isNotEmpty) {
      final usPron = pronunciations.firstWhere(
        (p) => p.lang == 'us',
        orElse: () => pronunciations.first,
      );
      return usPron.pron;
    }
    return ipa;
  }

  /// Get primary meaning in Vietnamese
  String get primaryMeaning {
    if (definitions.isNotEmpty) {
      return definitions.first.translation;
    }
    return meaningVi;
  }

  /// Get all Vietnamese meanings as a combined string
  String get allMeaningsVi {
    if (definitions.isNotEmpty) {
      return definitions.map((d) => '(${d.pos}) ${d.translation}').join('; ');
    }
    return meaningVi;
  }

  /// Get all examples (combining new and legacy)
  List<ExampleSentence> get allExamples {
    final List<ExampleSentence> result = [];
    
    // Add examples from definitions
    for (var def in definitions) {
      result.addAll(def.examples);
    }
    
    // Add legacy examples if no definition examples
    if (result.isEmpty && examplesEn.isNotEmpty) {
      for (int i = 0; i < examplesEn.length; i++) {
        result.add(ExampleSentence(
          id: i,
          text: examplesEn[i],
          translation: i < examplesVi.length ? examplesVi[i] : '',
        ));
      }
    }
    
    return result;
  }

  /// Converts the Word object to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'pos': pos,
      'verbs': verbs.map((v) => v.toJson()).toList(),
      'pronunciations': pronunciations.map((p) => p.toJson()).toList(),
      'definitions': definitions.map((d) => d.toJson()).toList(),
      'ipa': ipa.isNotEmpty ? ipa : primaryIpa,
      'meaning_vi': meaningVi.isNotEmpty ? meaningVi : primaryMeaning,
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
      pos: (map['pos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      verbs: (map['verbs'] as List<dynamic>?)
              ?.map((e) => VerbForm.fromJson(e))
              .toList() ?? [],
      pronunciations: (map['pronunciations'] as List<dynamic>?)
              ?.map((e) => Pronunciation.fromJson(e))
              .toList() ?? [],
      definitions: (map['definitions'] as List<dynamic>?)
              ?.map((e) => Definition.fromJson(e))
              .toList() ?? [],
      ipa: map['ipa'] ?? '',
      meaningVi: map['meaning_vi'] ?? '',
      examplesEn: (map['examples_en'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
      examplesVi: (map['examples_vi'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
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
    // Handle new rich format
    final posList = (json['pos'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
    final verbsList = (json['verbs'] as List<dynamic>?)
            ?.map((e) => VerbForm.fromJson(e))
            .toList() ?? [];
    final pronunciationsList = (json['pronunciation'] as List<dynamic>?)
            ?.map((e) => Pronunciation.fromJson(e))
            .toList() ?? [];
    final definitionsList = (json['definition'] as List<dynamic>?)
            ?.map((e) => Definition.fromJson(e))
            .toList() ?? [];
    
    // Extract legacy format fields for backward compatibility
    String legacyIpa = json['ipa'] ?? '';
    String legacyMeaningVi = json['meaning_vi'] ?? '';
    List<String> legacyExamplesEn = (json['examples_en'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
    List<String> legacyExamplesVi = (json['examples_vi'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [];
    
    // If using new format, extract primary values for legacy fields
    if (pronunciationsList.isNotEmpty && legacyIpa.isEmpty) {
      final usPron = pronunciationsList.firstWhere(
        (p) => p.lang == 'us',
        orElse: () => pronunciationsList.first,
      );
      legacyIpa = usPron.pron;
    }
    
    if (definitionsList.isNotEmpty && legacyMeaningVi.isEmpty) {
      legacyMeaningVi = definitionsList.first.translation;
    }

    return Word(
      word: json['word'] ?? '',
      pos: posList,
      verbs: verbsList,
      pronunciations: pronunciationsList,
      definitions: definitionsList,
      ipa: legacyIpa,
      meaningVi: legacyMeaningVi,
      examplesEn: legacyExamplesEn,
      examplesVi: legacyExamplesVi,
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
      'pos': pos,
      'verbs': verbs.map((v) => v.toJson()).toList(),
      'pronunciation': pronunciations.map((p) => p.toJson()).toList(),
      'definition': definitions.map((d) => d.toJson()).toList(),
      'ipa': ipa.isNotEmpty ? ipa : primaryIpa,
      'meaning_vi': meaningVi.isNotEmpty ? meaningVi : primaryMeaning,
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
    List<String>? pos,
    List<VerbForm>? verbs,
    List<Pronunciation>? pronunciations,
    List<Definition>? definitions,
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
      pos: pos ?? this.pos,
      verbs: verbs ?? this.verbs,
      pronunciations: pronunciations ?? this.pronunciations,
      definitions: definitions ?? this.definitions,
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
