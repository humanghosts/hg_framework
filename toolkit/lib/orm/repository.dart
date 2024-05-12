part of 'orm.dart';

/// 存储库
class Repository<T extends Model> {
  /// 存储库名字
  final String name;

  Repository._(this.name);

  factory Repository(String name) => instanceUtil.factory(name, () => Repository._(name));

  /// 构造一个新模型
  T get model => modelRegistry.getByType(T) as T;

  /// 构建表
  /// [ifNotExists] 为true表示表不存在才创建表
  void create({ifNotExists = true}) {
    CommonDatabase? database = dbUtil.database;
    if (null == database) return;
    CreateScheme createScheme = name.createScheme.ifNotExists(ifNotExists).columns(model.fields.list.map((e) {
          Column col = e.column;
          if (e.isPrimary) col.isPrimary = true;
          return col;
        }).toList());
    String sql = createScheme.sql;
    logUtil.debug(sql);
    database.execute(sql);
  }

  /// 插入数据
  void insert(T data, {Transaction? tx}) {
    CommonDatabase? database = dbUtil.database;
    if (null == database) return;
    InsertScheme insertScheme = InsertScheme().into(name).values(data.fields.list.map((field) => field.raw).toList());
    String sql = insertScheme.sql;
    logUtil.debug(sql);
    database.execute(sql);
  }

  /// 删除数据
  void deleteById(T data, {Transaction? tx, soft = true}) {
    CommonDatabase? database = dbUtil.database;
    if (null == database) return;

    void buildCondition(ConditionGroup group) {
      group.append(model.key.equals(data.key.value));
    }

    String sql;
    if (soft) {
      UpdateScheme updateScheme = UpdateScheme().update(model.deleteFlag.update(true)).from(name.from).where(buildCondition);
      sql = updateScheme.sql;
    } else {
      DeleteScheme deleteScheme = DeleteScheme().from(name.from).where(buildCondition);
      sql = deleteScheme.sql;
    }
    logUtil.debug(sql);
    database.execute(sql);
  }

  /// 删除数据 按照data的属性匹配 忽略空值和审计字段
  void delete(T data, {Transaction? tx, soft = true}) {
    CommonDatabase? database = dbUtil.database;
    if (null == database) return;

    void buildCondition(ConditionGroup group) {
      for (Field field in data.fields.list) {
        if (field.isAuditField || field.isDeleteField) continue;
        group.append(field.equals(field.value));
      }
    }

    String sql;
    if (soft) {
      UpdateScheme updateScheme = UpdateScheme().update(model.deleteFlag.update(true)).from(name.from).where(buildCondition);
      sql = updateScheme.sql;
    } else {
      DeleteScheme deleteScheme = DeleteScheme().from(name.from).where(buildCondition);
      sql = deleteScheme.sql;
    }
    logUtil.debug(sql);
    database.execute(sql);
  }

  /// 查询
  /// [id] id
  /// [tx] 事务
  T? findById(String id, {Transaction? tx, clear = true}) {
    T model = this.model;
    QueryScheme scheme = QueryScheme().selectAll().from(name.from).where((group) {
      group.append(model.key.equals(id));
    });
    return find(scheme, tx: tx, clear: clear)?.firstOrNull;
  }

  /// 查询
  /// [id] id
  /// [tx] 事务
  T? findByIdList(List<String> idList, {Transaction? tx, clear = true}) {
    T model = this.model;
    QueryScheme scheme = QueryScheme().selectAll().from(name.from).where((group) {
      group.append(model.key.inList(idList));
    });
    return find(scheme, tx: tx, clear: clear)?.firstOrNull;
  }

  List<T>? findAll({Transaction? tx, clear = true}) {
    QueryScheme scheme = QueryScheme().selectAll().from(name.from);
    return find(scheme, tx: tx, clear: clear);
  }

  /// 通过查询方案查询数据
  /// [scheme] 查询方案
  /// [tx] 事务
  List<T>? find(QueryScheme scheme, {Transaction? tx, clear = true}) {
    CommonDatabase? database = dbUtil.database;
    if (null == database) return null;
    String sql = scheme.preparedSql;
    List<dynamic> parameters = scheme.parameters;
    // 使用方法返回日志信息，防止不能输出日志的时候可以空耗性能
    logUtil.debug(() => [sql, parameters.map((e) => '${e.toString()}(${e.runtimeType})').toList()]);
    CommonPreparedStatement stmt = database.prepare(sql);
    // 结果集
    ResultSet resultSet = stmt.select(parameters);
    // 处理关联查询的数据
    Map<Type, Set<String>> subModelIdList = {};
    // 处理结果集
    List<T> resultModel = resultSet.map((row) {
      T t;
      T tempT = model;
      String id = row[tempT.key.name];
      if (_ModelCache.has(id)) {
        t = _ModelCache.get(id) as T;
      } else {
        t = tempT;
        _ModelCache.put(t);
      }
      // 按列处理单行数据
      row.forEach((key, value) {
        if (null == value) return;
        Field? field = t.fields.get(key);
        if (null == field) return;
        // 数据库数据转换为模型数据
        field.fromRaw(value);
        Type type = field.type;
        // 关联模型获取
        if (field is ModelField) {
          Set<String> idList = subModelIdList.putIfAbsent(type, () => {});
          String? subId = field.value?.key.value;
          if (null == subId) return;
          if (_ModelCache.has(subId)) return;
          idList.add(subId);
        }
        if (field is ModelListField) {
          Set<String> idList = subModelIdList.putIfAbsent(type, () => {});
          for (Model sub in field.value) {
            String? subId = sub.key.value;
            if (null == subId) continue;
            if (_ModelCache.has(subId)) continue;
            idList.add(subId);
          }
        }
      });
      return t;
    }).toList();
    // 关联查询
    subModelIdList.forEach((key, value) {
      Repository? repository = repoRegistry.getByType(key)?.call();
      repository?.findByIdList(value.toList(), clear: false);
    });
    // 清空查询缓存
    if (clear) _ModelCache.clear();
    return resultModel;
  }
}

/// 数据缓存，用于处理模型循环引用
class _ModelCache {
  static final Map<String, Model> _cache = {};

  /// 清空缓存
  static void clear() => _cache.clear();

  /// 放置缓存
  static void put(Model model) {
    String? id = model.key.value;
    if (id == null) return;
    _cache[id] = model;
  }

  /// 缓存是否存在
  static bool has(String id) => _cache.containsKey(id);

  /// 获取缓存
  static Model? get<T extends Model>(String id) => _cache[id];
}

extension _ListFieldEx on ListField {}

extension _FieldEx on Field {
  dynamic get raw {
    if (null == value) return null;
    return switch (this) {
      BooleanField() => value ? 1 : 0,
      DateTimeField() => (value as DateTime).millisecondsSinceEpoch,
      StringField() => value,
      ModelField() => (value as Model).key.raw,
      IntegerField() => value,
      FloatField() => value,
      BooleanListField() => _encode((e) => e ? 1 : 0),
      DateTimeListField() => _encode((e) => (e as DateTime).millisecondsSinceEpoch),
      StringListField() => _encode((e) => e),
      ModelListField() => _encode((e) => (e as Model).key.raw),
      IntegerListField() => _encode((e) => e),
      FloatListField() => _encode((e) => e),
    };
  }

  String _encode(dynamic Function(dynamic e) action) => jsonEncode((value as List).map(action).toList());

  dynamic _decode(dynamic value, dynamic Function(dynamic e) action) => (jsonDecode(value) as List).map(action).toList();

  void fromRaw(dynamic value) {
    if (value == null) {
      this.value = null;
      return;
    }
    switch (this) {
      case BooleanField():
        this.value = value == 0 ? false : true;
        break;
      case DateTimeField():
        this.value = DateTime.fromMillisecondsSinceEpoch(value);
        break;
      case ModelField():
        Model? model = modelRegistry.getByType(type)?.call();
        model?.key.value = value;
        this.value = model;
        break;
      case StringField():
      case IntegerField():
      case FloatField():
        this.value = value;
        break;
      case BooleanListField():
        this.value = _decode(value, (e) => e == 0 ? false : true);
        break;
      case DateTimeListField():
        this.value = _decode(value, (e) => DateTime.fromMillisecondsSinceEpoch(e));
        break;
      case ModelListField():
        this.value = _decode(value, (e) {
          Model? model = modelRegistry.getByType(type)?.call();
          model?.key.value = e;
          return model;
        });
        break;
      case StringListField():
      case IntegerListField():
      case FloatListField():
        this.value = _decode(value, (e) => e);
    }
  }
}
