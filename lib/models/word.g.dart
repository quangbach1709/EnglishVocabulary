// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WordAdapter extends TypeAdapter<Word> {
  @override
  final int typeId = 0;

  @override
  Word read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Word(
      word: fields[0] as String,
      ipa: fields[1] as String,
      meaningVi: fields[2] as String,
      examplesEn: (fields[3] as List).cast<String>(),
      examplesVi: (fields[4] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, Word obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.word)
      ..writeByte(1)
      ..write(obj.ipa)
      ..writeByte(2)
      ..write(obj.meaningVi)
      ..writeByte(3)
      ..write(obj.examplesEn)
      ..writeByte(4)
      ..write(obj.examplesVi);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
