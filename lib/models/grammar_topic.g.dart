// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grammar_topic.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GrammarFormulaAdapter extends TypeAdapter<GrammarFormula> {
  @override
  final int typeId = 2;

  @override
  GrammarFormula read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GrammarFormula(
      type: fields[0] as String,
      structure: fields[1] as String,
      example: fields[2] as String,
      explanation: fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, GrammarFormula obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.structure)
      ..writeByte(2)
      ..write(obj.example)
      ..writeByte(3)
      ..write(obj.explanation);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GrammarFormulaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GrammarUsageAdapter extends TypeAdapter<GrammarUsage> {
  @override
  final int typeId = 3;

  @override
  GrammarUsage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GrammarUsage(
      context: fields[0] as String,
      detail: fields[1] as String,
    );
  }

  @override
  void write(BinaryWriter writer, GrammarUsage obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.context)
      ..writeByte(1)
      ..write(obj.detail);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GrammarUsageAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GrammarTopicAdapter extends TypeAdapter<GrammarTopic> {
  @override
  final int typeId = 1;

  @override
  GrammarTopic read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GrammarTopic(
      id: fields[0] as String,
      topicEn: fields[1] as String,
      topicVi: fields[2] as String,
      definition: fields[3] as String,
      formulas: (fields[4] as List).cast<GrammarFormula>(),
      usages: (fields[5] as List).cast<GrammarUsage>(),
      signs: (fields[6] as List).cast<String>(),
      tipsForBeginners: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, GrammarTopic obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.topicEn)
      ..writeByte(2)
      ..write(obj.topicVi)
      ..writeByte(3)
      ..write(obj.definition)
      ..writeByte(4)
      ..write(obj.formulas)
      ..writeByte(5)
      ..write(obj.usages)
      ..writeByte(6)
      ..write(obj.signs)
      ..writeByte(7)
      ..write(obj.tipsForBeginners);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GrammarTopicAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
