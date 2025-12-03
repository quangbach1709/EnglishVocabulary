import 'package:hive_flutter/hive_flutter.dart';
import '../models/word.dart';

class WordRepository {
  final Box<Word> _box = Hive.box<Word>('words');

  List<Word> getWords() {
    return _box.values.toList();
  }

  Future<void> addWord(Word word) async {
    await _box.add(word);
  }

  Future<void> deleteWord(int index) async {
    await _box.deleteAt(index);
  }

  Future<void> updateWord(int index, Word word) async {
    await _box.putAt(index, word);
  }
}
