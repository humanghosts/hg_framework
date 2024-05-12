part of '../orm.dart';

/// 拼sql工具
extension SqlStringBufferEx on StringBuffer {
  StringBuffer writeEndSpace(dynamic value) {
    if (null == value) return this;
    return writeNonNull(value).writeNonNull(" ");
  }

  StringBuffer writeNonNull(dynamic value) {
    if (null == value) return this;
    write(value);
    return this;
  }
}

/// 拼sql工具
extension _SqlListEx<E extends _Sqlable> on List<E> {
  /// copy from [join]
  String sqlJoin([String separator = " "]) {
    Iterator<E> iterator = this.iterator;
    if (!iterator.moveNext()) return "";
    var first = iterator.current.sql;
    if (!iterator.moveNext()) return first;
    var buffer = StringBuffer(first);
    if (separator.isEmpty) {
      do {
        buffer.write(iterator.current.sql);
      } while (iterator.moveNext());
    } else {
      do {
        buffer
          ..write(separator)
          ..write(iterator.current.sql);
      } while (iterator.moveNext());
    }
    return buffer.toString();
  }
}

/// 字符串的扩展，用于创建表
extension CreateStringEx on String {
  CreateScheme get createScheme => CreateScheme(this);

  Column get column => Column(name: this, type: ColumnType.NULL);
}

/// 字符串扩展 用于创建查询语句
extension QueryStringEx on String {
  QueryField get field => QueryField(this);

  From get from => From(this);

  QueryOrder get orderBy => desc;

  QueryOrder get asc => QueryOrderAsc(this);

  QueryOrder get desc => QueryOrderDesc(this);

  Condition isNull() => ConditionItemIsNull(this);

  Condition notNull() => ConditionItemNotNull(this);

  Condition equals(dynamic value) => ConditionItemEquals(this, value);

  Condition notEquals(dynamic value) => ConditionItemNotEquals(this, value);

  Condition inList(List<dynamic> value) => ConditionItemIn(this, value);
}

/// 字符串扩展，用于创建更新语句
extension UpdateStringEx on String {
  UpdateField update(dynamic value) => UpdateField(this, value);
}

/// 字段扩展 用于创建表语句 调用字符串的扩展
extension CreateFieldEx on Field {
  Column get column => name.column..type = columnType;

  ColumnType get columnType {
    return switch (this) {
      BooleanField<bool?>() => ColumnType.INTEGER,
      DateTimeField<DateTime?>() => ColumnType.INTEGER,
      StringField<String?>() => ColumnType.TEXT,
      ModelField<Model?>() => ColumnType.TEXT,
      BooleanListField<bool>() => ColumnType.TEXT,
      DateTimeListField<DateTime>() => ColumnType.TEXT,
      StringListField<String>() => ColumnType.TEXT,
      ModelListField<Model>() => ColumnType.TEXT,
      IntegerField<int?>() => ColumnType.INTEGER,
      FloatField<double?>() => ColumnType.REAL,
      IntegerListField<int>() => ColumnType.TEXT,
      FloatListField<double>() => ColumnType.TEXT,
    };
  }
}

/// 字段扩展 用于查询，调用字段名称的字符串扩展
extension QueryFieldEx on Field {
  QueryField get field => name.field;

  QueryOrder get orderBy => desc;

  QueryOrder get asc => name.asc;

  QueryOrder get desc => name.desc;

  Condition isNull() => name.isNull();

  Condition notNull() => name.notNull();

  Condition equals(dynamic value) => name.equals(value);

  Condition notEquals(dynamic value) => name.notEquals(value);

  Condition inList(List<dynamic> value) => name.inList(value);
}

/// 字段扩展 用于更新，调用字段名称的字符串扩展
extension UpdateFieldEx on Field {
  UpdateField update(dynamic value) => name.update(value);
}
