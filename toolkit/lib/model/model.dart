/// 模型
abstract class Model {
  /// 主键
  late final Field<String?> key;

  /// 删除标识
  late final Field<bool> deleteFlag;

  /// 创建时间
  late final Field<DateTime> createTime;

  /// 更新时间
  late final Field<DateTime> updateTime;

  /// 模型属性
  late final Fields fields;

  Model({String? id}) {
    fields = Fields(this);
    key = fields.string(name: 'key', value: id)..isPrimary = true;
    deleteFlag = fields.boolean(name: "deleteFlag", value: false);
    // 当前时间
    DateTime now = DateTime.now();
    createTime = fields.datetime(name: "createTime", value: now.copyWith());
    updateTime = fields.datetime(name: "createTime", value: now.copyWith());
  }

  /// 设置值
  Model set(String key, dynamic value) {
    fields.get(key)?.value = value;
    return this;
  }

  /// 获取值
  T? get<T>(String key) => fields.get(key)?.value as T?;

  /// 审计属性
  List<Field> get auditFields => [createTime, updateTime];

  /// 删除字段
  List<Field> get deleteFields => [deleteFlag];
}

/// 属性
sealed class Field<T> {
  /// 属性的值
  T value;

  /// 属性名称
  String name;

  /// 属性集合
  Fields fields;

  /// 是否是主键
  bool isPrimary;

  Field(
    this.fields, {
    required this.value,
    required this.name,
    this.isPrimary = false,
  }) {
    fields._map[name] = this;
  }

  /// 字段类型
  Type get type => T;

  /// 是否是审计字段
  bool get isAuditField => fields.parent.auditFields.contains(this);

  /// 是否是删除字段
  bool get isDeleteField => fields.parent.deleteFields.contains(this);
}

/// 列表类型
sealed class ListField<T> extends Field<List<T>> {
  ListField(super.fields, {required super.name, required super.value});
}

/// 布尔类型的值
class BooleanField<T extends bool?> extends Field<T> {
  BooleanField(super.fields, {required super.value, required super.name});
}

class BooleanListField<T extends bool> extends ListField<T> {
  BooleanListField(super.fields, {required super.name, required super.value});
}

/// 时间类型
class DateTimeField<T extends DateTime?> extends Field<T> {
  DateTimeField(super.fields, {required super.value, required super.name});
}

class DateTimeListField<T extends DateTime> extends ListField<T> {
  DateTimeListField(super.fields, {required super.name, required super.value});
}

/// 数字类型属性
sealed class NumberField<T extends num?> extends Field<T> {
  NumberField(super.fields, {required super.value, required super.name});
}

sealed class NumberListField<T extends num> extends ListField<T> {
  NumberListField(super.fields, {required super.name, required super.value});
}

/// 整型
class IntegerField<T extends int?> extends NumberField<T> {
  IntegerField(super.fields, {required super.value, required super.name});
}

class IntegerListField<T extends int> extends NumberListField<T> {
  IntegerListField(super.fields, {required super.name, required super.value});
}

/// 浮点型
class FloatField<T extends double?> extends NumberField<T> {
  FloatField(super.fields, {required super.value, required super.name});
}

class FloatListField<T extends double> extends NumberListField<T> {
  FloatListField(super.fields, {required super.name, required super.value});
}

/// 字符串类型属性
class StringField<T extends String?> extends Field<T> {
  StringField(super.fields, {required super.value, required super.name});
}

class StringListField<T extends String> extends ListField<T> {
  StringListField(super.fields, {required super.name, required super.value});
}

/// 模型
class ModelField<T extends Model?> extends Field<T> {
  ModelField(super.fields, {required super.value, required super.name});
}

class ModelListField<T extends Model> extends ListField<T> {
  ModelListField(super.fields, {required super.name, required super.value});
}

/// 属性集合
class Fields {
  /// 名称:属性 映射
  final Map<String, Field> _map = {};

  /// 模型
  final Model _model;

  /// 构造方法
  Fields(Model model) : _model = model;

  /// 获取模型
  Model get parent => _model;

  /// 通过名称获取某个属性
  Field? get(String? name) => _map[name];

  /// 获取所有属性
  List<Field> get list => List.unmodifiable(_map.values);

  /// 以map形式获取所有属性
  Map<String, Field> get map => Map.unmodifiable(_map);

  /// 整型字段
  IntegerField<T> integer<T extends int?>({required String name, required T value}) {
    IntegerField<T> attribute = IntegerField<T>(this, value: value, name: name);
    _map[name] = attribute;
    return attribute;
  }

  /// 整型列表
  IntegerListField<T> integerList<T extends int>({required String name, List<T>? value}) {
    IntegerListField<T> attribute = IntegerListField<T>(this, value: value ?? [], name: name);
    _map[name] = attribute;
    return attribute;
  }

  /// 浮点型字段
  FloatField<T> float<T extends double?>({required String name, required T value}) {
    FloatField<T> attribute = FloatField<T>(this, value: value, name: name);
    _map[name] = attribute;
    return attribute;
  }

  /// 浮点型列表
  FloatListField<T> floatList<T extends double>({required String name, List<T>? value}) {
    FloatListField<T> attribute = FloatListField<T>(this, value: value ?? [], name: name);
    _map[name] = attribute;
    return attribute;
  }

  /// 字符串字段
  StringField<T> string<T extends String?>({required String name, required T value}) {
    StringField<T> attribute = StringField<T>(this, value: value, name: name);
    _map[name] = attribute;
    return attribute;
  }

  /// 字符串列表
  StringListField<T> stringList<T extends String>({required String name, List<T>? value}) {
    StringListField<T> attribute = StringListField<T>(this, value: value ?? [], name: name);
    _map[name] = attribute;
    return attribute;
  }

  /// 布尔字段
  BooleanField<T> boolean<T extends bool?>({required String name, required T value}) {
    BooleanField<T> attribute = BooleanField<T>(this, value: value, name: name);
    _map[name] = attribute;
    return attribute;
  }

  /// 布尔列表
  BooleanListField<T> booleanList<T extends bool>({required String name, List<T>? value}) {
    BooleanListField<T> attribute = BooleanListField<T>(this, value: value ?? [], name: name);
    _map[name] = attribute;
    return attribute;
  }

  /// 日期时间字段
  DateTimeField<T> datetime<T extends DateTime?>({required String name, required T value}) {
    DateTimeField<T> attribute = DateTimeField<T>(this, value: value, name: name);
    _map[name] = attribute;
    return attribute;
  }

  /// 日期时间列表
  DateTimeListField<T> datetimeList<T extends DateTime>({required String name, List<T>? value}) {
    DateTimeListField<T> attribute = DateTimeListField<T>(this, value: value ?? [], name: name);
    _map[name] = attribute;
    return attribute;
  }

  /// 模型字段
  ModelField<T> model<T extends Model?>({required String name, required T value}) {
    ModelField<T> attribute = ModelField<T>(this, value: value, name: name);
    _map[name] = attribute;
    return attribute;
  }

  /// 日期时间列表
  ModelListField<T> modelList<T extends Model>({required String name, List<T>? value}) {
    ModelListField<T> attribute = ModelListField<T>(this, value: value ?? [], name: name);
    _map[name] = attribute;
    return attribute;
  }
}
