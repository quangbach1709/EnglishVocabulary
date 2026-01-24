import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/word.dart';
import '../models/grammar_topic.dart';

/// Singleton service for Firestore operations on vocabulary and grammar data
class FirestoreService {
  // Singleton pattern
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection paths
  static const String _vocabularyPath = 'users/test_user/vocabulary';
  static const String _grammarPath = 'users/test_user/grammar_topics';

  /// Reference to the vocabulary collection
  CollectionReference<Map<String, dynamic>> get _vocabularyCollection =>
      _firestore.collection(_vocabularyPath);

  /// Reference to the grammar collection
  CollectionReference<Map<String, dynamic>> get _grammarCollection =>
      _firestore.collection(_grammarPath);

  // ============================================
  // Vocabulary Methods
  // ============================================

  /// Adds a new word to Firestore
  /// Uses word.english (lowercase) as the Document ID to prevent duplicates
  Future<void> addWord(Word word) async {
    try {
      await _vocabularyCollection.doc(word.english).set(word.toMap());
    } catch (e) {
      throw FirestoreException('Failed to add word: $e');
    }
  }

  /// Deletes a word from Firestore by its English word (Document ID)
  Future<void> deleteWord(String englishWord) async {
    try {
      await _vocabularyCollection.doc(englishWord.toLowerCase()).delete();
    } catch (e) {
      throw FirestoreException('Failed to delete word: $e');
    }
  }

  /// Fetches all words from the vocabulary collection
  Future<List<Word>> getAllWords() async {
    try {
      final querySnapshot = await _vocabularyCollection.get();
      return querySnapshot.docs.map((doc) => Word.fromMap(doc.data())).toList();
    } catch (e) {
      throw FirestoreException('Failed to fetch words: $e');
    }
  }

  /// Updates the status and nextReviewDate for a specific word
  Future<void> updateWordStatus(
    String englishWord,
    int status,
    DateTime nextReview,
  ) async {
    try {
      await _vocabularyCollection.doc(englishWord.toLowerCase()).update({
        'status': status,
        'next_review_date': Timestamp.fromDate(nextReview),
      });
    } catch (e) {
      throw FirestoreException('Failed to update word status: $e');
    }
  }

  /// Mark word as 'Forgot' (Reset SRS)
  Future<void> markWordAsForgot(Word word) async {
    try {
      final updatedWord = word.copyWith(
        status: 0, // Red / Forgot
        interval: 0, // Reset interval
        nextReviewDate: DateTime.now(), // Review immediately
        easeFactor: (word.easeFactor - 0.2).clamp(
          1.3,
          2.5,
        ), // Reduce ease factor slightly
      );
      await updateWord(updatedWord);
    } catch (e) {
      throw FirestoreException('Failed to mark word as forgot: $e');
    }
  }

  /// Updates a word completely
  Future<void> updateWord(Word word) async {
    try {
      await _vocabularyCollection.doc(word.english).update(word.toMap());
    } catch (e) {
      throw FirestoreException('Failed to update word: $e');
    }
  }

  /// Gets a single word by its English word (Document ID)
  Future<Word?> getWord(String englishWord) async {
    try {
      final docSnapshot = await _vocabularyCollection
          .doc(englishWord.toLowerCase())
          .get();
      if (docSnapshot.exists && docSnapshot.data() != null) {
        return Word.fromMap(docSnapshot.data()!);
      }
      return null;
    } catch (e) {
      throw FirestoreException('Failed to get word: $e');
    }
  }

  /// Checks if a word exists in Firestore
  Future<bool> wordExists(String englishWord) async {
    try {
      final docSnapshot = await _vocabularyCollection
          .doc(englishWord.toLowerCase())
          .get();
      return docSnapshot.exists;
    } catch (e) {
      throw FirestoreException('Failed to check word existence: $e');
    }
  }

  /// Gets a stream of all words (for real-time updates)
  Stream<List<Word>> wordsStream() {
    return _vocabularyCollection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Word.fromMap(doc.data())).toList(),
    );
  }

  /// Batch add multiple words
  Future<void> addWords(List<Word> words) async {
    try {
      final batch = _firestore.batch();
      for (final word in words) {
        batch.set(_vocabularyCollection.doc(word.english), word.toMap());
      }
      await batch.commit();
    } catch (e) {
      throw FirestoreException('Failed to add words: $e');
    }
  }

  /// Deletes all words in the collection
  Future<void> deleteAllWords() async {
    try {
      final querySnapshot = await _vocabularyCollection.get();
      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      throw FirestoreException('Failed to delete all words: $e');
    }
  }

  // ============================================
  // Grammar Methods
  // ============================================

  /// Saves a grammar topic to Firestore (Create or Update)
  /// Uses topic.id (UUID) as the Document ID to ensure uniqueness
  Future<void> saveGrammarTopic(GrammarTopic topic) async {
    try {
      // Use set to create or overwrite. merge: true is optional if we always send full object
      await _grammarCollection
          .doc(topic.id)
          .set(topic.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw FirestoreException('Failed to save grammar topic: $e');
    }
  }

  /// Fetches all grammar topics
  Future<List<GrammarTopic>> getAllGrammarTopics() async {
    try {
      final querySnapshot = await _grammarCollection.get();
      return querySnapshot.docs
          .map((doc) => GrammarTopic.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw FirestoreException('Failed to fetch grammar topics: $e');
    }
  }

  /// Deletes a grammar topic by ID
  Future<void> deleteGrammarTopic(String topicId) async {
    try {
      await _grammarCollection.doc(topicId).delete();
    } catch (e) {
      throw FirestoreException('Failed to delete grammar topic: $e');
    }
  }
}

/// Custom exception for Firestore operations
class FirestoreException implements Exception {
  final String message;
  FirestoreException(this.message);

  @override
  String toString() => 'FirestoreException: $message';
}
