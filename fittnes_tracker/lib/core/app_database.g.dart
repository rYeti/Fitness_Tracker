// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FoodItemTable extends FoodItem
    with TableInfo<$FoodItemTable, FoodItemData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodItemTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _caloriesMeta = const VerificationMeta(
    'calories',
  );
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
    'calories',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinMeta = const VerificationMeta(
    'protein',
  );
  @override
  late final GeneratedColumn<int> protein = GeneratedColumn<int>(
    'protein',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbsMeta = const VerificationMeta('carbs');
  @override
  late final GeneratedColumn<int> carbs = GeneratedColumn<int>(
    'carbs',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fatMeta = const VerificationMeta('fat');
  @override
  late final GeneratedColumn<int> fat = GeneratedColumn<int>(
    'fat',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _grammMeta = const VerificationMeta('gramm');
  @override
  late final GeneratedColumn<int> gramm = GeneratedColumn<int>(
    'gramm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _hiddenFromRecentMeta = const VerificationMeta(
    'hiddenFromRecent',
  );
  @override
  late final GeneratedColumn<bool> hiddenFromRecent = GeneratedColumn<bool>(
    'hidden_from_recent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hidden_from_recent" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _extendedNutrientsJsonMeta =
      const VerificationMeta('extendedNutrientsJson');
  @override
  late final GeneratedColumn<String> extendedNutrientsJson =
      GeneratedColumn<String>(
        'extended_nutrients_json',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _openFoodFactsIdMeta = const VerificationMeta(
    'openFoodFactsId',
  );
  @override
  late final GeneratedColumn<String> openFoodFactsId = GeneratedColumn<String>(
    'open_food_facts_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    calories,
    protein,
    carbs,
    fat,
    gramm,
    hiddenFromRecent,
    extendedNutrientsJson,
    syncStatus,
    serverId,
    openFoodFactsId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_item';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodItemData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('calories')) {
      context.handle(
        _caloriesMeta,
        calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta),
      );
    } else if (isInserting) {
      context.missing(_caloriesMeta);
    }
    if (data.containsKey('protein')) {
      context.handle(
        _proteinMeta,
        protein.isAcceptableOrUnknown(data['protein']!, _proteinMeta),
      );
    } else if (isInserting) {
      context.missing(_proteinMeta);
    }
    if (data.containsKey('carbs')) {
      context.handle(
        _carbsMeta,
        carbs.isAcceptableOrUnknown(data['carbs']!, _carbsMeta),
      );
    } else if (isInserting) {
      context.missing(_carbsMeta);
    }
    if (data.containsKey('fat')) {
      context.handle(
        _fatMeta,
        fat.isAcceptableOrUnknown(data['fat']!, _fatMeta),
      );
    } else if (isInserting) {
      context.missing(_fatMeta);
    }
    if (data.containsKey('gramm')) {
      context.handle(
        _grammMeta,
        gramm.isAcceptableOrUnknown(data['gramm']!, _grammMeta),
      );
    }
    if (data.containsKey('hidden_from_recent')) {
      context.handle(
        _hiddenFromRecentMeta,
        hiddenFromRecent.isAcceptableOrUnknown(
          data['hidden_from_recent']!,
          _hiddenFromRecentMeta,
        ),
      );
    }
    if (data.containsKey('extended_nutrients_json')) {
      context.handle(
        _extendedNutrientsJsonMeta,
        extendedNutrientsJson.isAcceptableOrUnknown(
          data['extended_nutrients_json']!,
          _extendedNutrientsJsonMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('open_food_facts_id')) {
      context.handle(
        _openFoodFactsIdMeta,
        openFoodFactsId.isAcceptableOrUnknown(
          data['open_food_facts_id']!,
          _openFoodFactsIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodItemData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodItemData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      calories:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}calories'],
          )!,
      protein:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}protein'],
          )!,
      carbs:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}carbs'],
          )!,
      fat:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}fat'],
          )!,
      gramm:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}gramm'],
          )!,
      hiddenFromRecent:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}hidden_from_recent'],
          )!,
      extendedNutrientsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extended_nutrients_json'],
      ),
      syncStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sync_status'],
          )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      openFoodFactsId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}open_food_facts_id'],
      ),
    );
  }

  @override
  $FoodItemTable createAlias(String alias) {
    return $FoodItemTable(attachedDatabase, alias);
  }
}

class FoodItemData extends DataClass implements Insertable<FoodItemData> {
  final int id;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int gramm;
  final bool hiddenFromRecent;

  /// JSON-encoded [ExtendedNutrients]. Null for custom foods and any entry
  /// added before this column was introduced.
  final String? extendedNutrientsJson;

  /// Maps to [FoodItemSyncStatus] by index.
  final int syncStatus;

  /// UUID assigned by the remote API after first successful sync.
  final String? serverId;

  /// OpenFoodFacts product code (barcode) — stored when a food is added from
  /// the online database so serving sizes can be re-fetched on edit.
  final String? openFoodFactsId;
  const FoodItemData({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.gramm,
    required this.hiddenFromRecent,
    this.extendedNutrientsJson,
    required this.syncStatus,
    this.serverId,
    this.openFoodFactsId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['calories'] = Variable<int>(calories);
    map['protein'] = Variable<int>(protein);
    map['carbs'] = Variable<int>(carbs);
    map['fat'] = Variable<int>(fat);
    map['gramm'] = Variable<int>(gramm);
    map['hidden_from_recent'] = Variable<bool>(hiddenFromRecent);
    if (!nullToAbsent || extendedNutrientsJson != null) {
      map['extended_nutrients_json'] = Variable<String>(extendedNutrientsJson);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    if (!nullToAbsent || openFoodFactsId != null) {
      map['open_food_facts_id'] = Variable<String>(openFoodFactsId);
    }
    return map;
  }

  FoodItemCompanion toCompanion(bool nullToAbsent) {
    return FoodItemCompanion(
      id: Value(id),
      name: Value(name),
      calories: Value(calories),
      protein: Value(protein),
      carbs: Value(carbs),
      fat: Value(fat),
      gramm: Value(gramm),
      hiddenFromRecent: Value(hiddenFromRecent),
      extendedNutrientsJson:
          extendedNutrientsJson == null && nullToAbsent
              ? const Value.absent()
              : Value(extendedNutrientsJson),
      syncStatus: Value(syncStatus),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
      openFoodFactsId:
          openFoodFactsId == null && nullToAbsent
              ? const Value.absent()
              : Value(openFoodFactsId),
    );
  }

  factory FoodItemData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodItemData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      calories: serializer.fromJson<int>(json['calories']),
      protein: serializer.fromJson<int>(json['protein']),
      carbs: serializer.fromJson<int>(json['carbs']),
      fat: serializer.fromJson<int>(json['fat']),
      gramm: serializer.fromJson<int>(json['gramm']),
      hiddenFromRecent: serializer.fromJson<bool>(json['hiddenFromRecent']),
      extendedNutrientsJson: serializer.fromJson<String?>(
        json['extendedNutrientsJson'],
      ),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      openFoodFactsId: serializer.fromJson<String?>(json['openFoodFactsId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'calories': serializer.toJson<int>(calories),
      'protein': serializer.toJson<int>(protein),
      'carbs': serializer.toJson<int>(carbs),
      'fat': serializer.toJson<int>(fat),
      'gramm': serializer.toJson<int>(gramm),
      'hiddenFromRecent': serializer.toJson<bool>(hiddenFromRecent),
      'extendedNutrientsJson': serializer.toJson<String?>(
        extendedNutrientsJson,
      ),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'serverId': serializer.toJson<String?>(serverId),
      'openFoodFactsId': serializer.toJson<String?>(openFoodFactsId),
    };
  }

  FoodItemData copyWith({
    int? id,
    String? name,
    int? calories,
    int? protein,
    int? carbs,
    int? fat,
    int? gramm,
    bool? hiddenFromRecent,
    Value<String?> extendedNutrientsJson = const Value.absent(),
    int? syncStatus,
    Value<String?> serverId = const Value.absent(),
    Value<String?> openFoodFactsId = const Value.absent(),
  }) => FoodItemData(
    id: id ?? this.id,
    name: name ?? this.name,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    gramm: gramm ?? this.gramm,
    hiddenFromRecent: hiddenFromRecent ?? this.hiddenFromRecent,
    extendedNutrientsJson:
        extendedNutrientsJson.present
            ? extendedNutrientsJson.value
            : this.extendedNutrientsJson,
    syncStatus: syncStatus ?? this.syncStatus,
    serverId: serverId.present ? serverId.value : this.serverId,
    openFoodFactsId:
        openFoodFactsId.present ? openFoodFactsId.value : this.openFoodFactsId,
  );
  FoodItemData copyWithCompanion(FoodItemCompanion data) {
    return FoodItemData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      calories: data.calories.present ? data.calories.value : this.calories,
      protein: data.protein.present ? data.protein.value : this.protein,
      carbs: data.carbs.present ? data.carbs.value : this.carbs,
      fat: data.fat.present ? data.fat.value : this.fat,
      gramm: data.gramm.present ? data.gramm.value : this.gramm,
      hiddenFromRecent:
          data.hiddenFromRecent.present
              ? data.hiddenFromRecent.value
              : this.hiddenFromRecent,
      extendedNutrientsJson:
          data.extendedNutrientsJson.present
              ? data.extendedNutrientsJson.value
              : this.extendedNutrientsJson,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      openFoodFactsId:
          data.openFoodFactsId.present
              ? data.openFoodFactsId.value
              : this.openFoodFactsId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodItemData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fat: $fat, ')
          ..write('gramm: $gramm, ')
          ..write('hiddenFromRecent: $hiddenFromRecent, ')
          ..write('extendedNutrientsJson: $extendedNutrientsJson, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverId: $serverId, ')
          ..write('openFoodFactsId: $openFoodFactsId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    calories,
    protein,
    carbs,
    fat,
    gramm,
    hiddenFromRecent,
    extendedNutrientsJson,
    syncStatus,
    serverId,
    openFoodFactsId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodItemData &&
          other.id == this.id &&
          other.name == this.name &&
          other.calories == this.calories &&
          other.protein == this.protein &&
          other.carbs == this.carbs &&
          other.fat == this.fat &&
          other.gramm == this.gramm &&
          other.hiddenFromRecent == this.hiddenFromRecent &&
          other.extendedNutrientsJson == this.extendedNutrientsJson &&
          other.syncStatus == this.syncStatus &&
          other.serverId == this.serverId &&
          other.openFoodFactsId == this.openFoodFactsId);
}

class FoodItemCompanion extends UpdateCompanion<FoodItemData> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> calories;
  final Value<int> protein;
  final Value<int> carbs;
  final Value<int> fat;
  final Value<int> gramm;
  final Value<bool> hiddenFromRecent;
  final Value<String?> extendedNutrientsJson;
  final Value<int> syncStatus;
  final Value<String?> serverId;
  final Value<String?> openFoodFactsId;
  const FoodItemCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.calories = const Value.absent(),
    this.protein = const Value.absent(),
    this.carbs = const Value.absent(),
    this.fat = const Value.absent(),
    this.gramm = const Value.absent(),
    this.hiddenFromRecent = const Value.absent(),
    this.extendedNutrientsJson = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverId = const Value.absent(),
    this.openFoodFactsId = const Value.absent(),
  });
  FoodItemCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    this.gramm = const Value.absent(),
    this.hiddenFromRecent = const Value.absent(),
    this.extendedNutrientsJson = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverId = const Value.absent(),
    this.openFoodFactsId = const Value.absent(),
  }) : name = Value(name),
       calories = Value(calories),
       protein = Value(protein),
       carbs = Value(carbs),
       fat = Value(fat);
  static Insertable<FoodItemData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? calories,
    Expression<int>? protein,
    Expression<int>? carbs,
    Expression<int>? fat,
    Expression<int>? gramm,
    Expression<bool>? hiddenFromRecent,
    Expression<String>? extendedNutrientsJson,
    Expression<int>? syncStatus,
    Expression<String>? serverId,
    Expression<String>? openFoodFactsId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fat != null) 'fat': fat,
      if (gramm != null) 'gramm': gramm,
      if (hiddenFromRecent != null) 'hidden_from_recent': hiddenFromRecent,
      if (extendedNutrientsJson != null)
        'extended_nutrients_json': extendedNutrientsJson,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverId != null) 'server_id': serverId,
      if (openFoodFactsId != null) 'open_food_facts_id': openFoodFactsId,
    });
  }

  FoodItemCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? calories,
    Value<int>? protein,
    Value<int>? carbs,
    Value<int>? fat,
    Value<int>? gramm,
    Value<bool>? hiddenFromRecent,
    Value<String?>? extendedNutrientsJson,
    Value<int>? syncStatus,
    Value<String?>? serverId,
    Value<String?>? openFoodFactsId,
  }) {
    return FoodItemCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      gramm: gramm ?? this.gramm,
      hiddenFromRecent: hiddenFromRecent ?? this.hiddenFromRecent,
      extendedNutrientsJson:
          extendedNutrientsJson ?? this.extendedNutrientsJson,
      syncStatus: syncStatus ?? this.syncStatus,
      serverId: serverId ?? this.serverId,
      openFoodFactsId: openFoodFactsId ?? this.openFoodFactsId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    if (protein.present) {
      map['protein'] = Variable<int>(protein.value);
    }
    if (carbs.present) {
      map['carbs'] = Variable<int>(carbs.value);
    }
    if (fat.present) {
      map['fat'] = Variable<int>(fat.value);
    }
    if (gramm.present) {
      map['gramm'] = Variable<int>(gramm.value);
    }
    if (hiddenFromRecent.present) {
      map['hidden_from_recent'] = Variable<bool>(hiddenFromRecent.value);
    }
    if (extendedNutrientsJson.present) {
      map['extended_nutrients_json'] = Variable<String>(
        extendedNutrientsJson.value,
      );
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (openFoodFactsId.present) {
      map['open_food_facts_id'] = Variable<String>(openFoodFactsId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodItemCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fat: $fat, ')
          ..write('gramm: $gramm, ')
          ..write('hiddenFromRecent: $hiddenFromRecent, ')
          ..write('extendedNutrientsJson: $extendedNutrientsJson, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverId: $serverId, ')
          ..write('openFoodFactsId: $openFoodFactsId')
          ..write(')'))
        .toString();
  }
}

class $VerifiedFoodTableTable extends VerifiedFoodTable
    with TableInfo<$VerifiedFoodTableTable, VerifiedFoodTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VerifiedFoodTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameDeMeta = const VerificationMeta('nameDe');
  @override
  late final GeneratedColumn<String> nameDe = GeneratedColumn<String>(
    'name_de',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caloriesMeta = const VerificationMeta(
    'calories',
  );
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
    'calories',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinMeta = const VerificationMeta(
    'protein',
  );
  @override
  late final GeneratedColumn<double> protein = GeneratedColumn<double>(
    'protein',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbsMeta = const VerificationMeta('carbs');
  @override
  late final GeneratedColumn<double> carbs = GeneratedColumn<double>(
    'carbs',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fatMeta = const VerificationMeta('fat');
  @override
  late final GeneratedColumn<double> fat = GeneratedColumn<double>(
    'fat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceCodeMeta = const VerificationMeta(
    'sourceCode',
  );
  @override
  late final GeneratedColumn<String> sourceCode = GeneratedColumn<String>(
    'source_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    nameDe,
    calories,
    protein,
    carbs,
    fat,
    sourceCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'verified_food_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<VerifiedFoodTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_de')) {
      context.handle(
        _nameDeMeta,
        nameDe.isAcceptableOrUnknown(data['name_de']!, _nameDeMeta),
      );
    }
    if (data.containsKey('calories')) {
      context.handle(
        _caloriesMeta,
        calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta),
      );
    } else if (isInserting) {
      context.missing(_caloriesMeta);
    }
    if (data.containsKey('protein')) {
      context.handle(
        _proteinMeta,
        protein.isAcceptableOrUnknown(data['protein']!, _proteinMeta),
      );
    } else if (isInserting) {
      context.missing(_proteinMeta);
    }
    if (data.containsKey('carbs')) {
      context.handle(
        _carbsMeta,
        carbs.isAcceptableOrUnknown(data['carbs']!, _carbsMeta),
      );
    } else if (isInserting) {
      context.missing(_carbsMeta);
    }
    if (data.containsKey('fat')) {
      context.handle(
        _fatMeta,
        fat.isAcceptableOrUnknown(data['fat']!, _fatMeta),
      );
    } else if (isInserting) {
      context.missing(_fatMeta);
    }
    if (data.containsKey('source_code')) {
      context.handle(
        _sourceCodeMeta,
        sourceCode.isAcceptableOrUnknown(data['source_code']!, _sourceCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VerifiedFoodTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VerifiedFoodTableData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      nameDe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_de'],
      ),
      calories:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}calories'],
          )!,
      protein:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}protein'],
          )!,
      carbs:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}carbs'],
          )!,
      fat:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}fat'],
          )!,
      sourceCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_code'],
      ),
    );
  }

  @override
  $VerifiedFoodTableTable createAlias(String alias) {
    return $VerifiedFoodTableTable(attachedDatabase, alias);
  }
}

class VerifiedFoodTableData extends DataClass
    implements Insertable<VerifiedFoodTableData> {
  final int id;
  final String name;
  final String? nameDe;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;

  /// Source key, e.g. the BLS SBLS code — kept for attribution/versioning.
  final String? sourceCode;
  const VerifiedFoodTableData({
    required this.id,
    required this.name,
    this.nameDe,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.sourceCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || nameDe != null) {
      map['name_de'] = Variable<String>(nameDe);
    }
    map['calories'] = Variable<int>(calories);
    map['protein'] = Variable<double>(protein);
    map['carbs'] = Variable<double>(carbs);
    map['fat'] = Variable<double>(fat);
    if (!nullToAbsent || sourceCode != null) {
      map['source_code'] = Variable<String>(sourceCode);
    }
    return map;
  }

  VerifiedFoodTableCompanion toCompanion(bool nullToAbsent) {
    return VerifiedFoodTableCompanion(
      id: Value(id),
      name: Value(name),
      nameDe:
          nameDe == null && nullToAbsent ? const Value.absent() : Value(nameDe),
      calories: Value(calories),
      protein: Value(protein),
      carbs: Value(carbs),
      fat: Value(fat),
      sourceCode:
          sourceCode == null && nullToAbsent
              ? const Value.absent()
              : Value(sourceCode),
    );
  }

  factory VerifiedFoodTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VerifiedFoodTableData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      nameDe: serializer.fromJson<String?>(json['nameDe']),
      calories: serializer.fromJson<int>(json['calories']),
      protein: serializer.fromJson<double>(json['protein']),
      carbs: serializer.fromJson<double>(json['carbs']),
      fat: serializer.fromJson<double>(json['fat']),
      sourceCode: serializer.fromJson<String?>(json['sourceCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'nameDe': serializer.toJson<String?>(nameDe),
      'calories': serializer.toJson<int>(calories),
      'protein': serializer.toJson<double>(protein),
      'carbs': serializer.toJson<double>(carbs),
      'fat': serializer.toJson<double>(fat),
      'sourceCode': serializer.toJson<String?>(sourceCode),
    };
  }

  VerifiedFoodTableData copyWith({
    int? id,
    String? name,
    Value<String?> nameDe = const Value.absent(),
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    Value<String?> sourceCode = const Value.absent(),
  }) => VerifiedFoodTableData(
    id: id ?? this.id,
    name: name ?? this.name,
    nameDe: nameDe.present ? nameDe.value : this.nameDe,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fat: fat ?? this.fat,
    sourceCode: sourceCode.present ? sourceCode.value : this.sourceCode,
  );
  VerifiedFoodTableData copyWithCompanion(VerifiedFoodTableCompanion data) {
    return VerifiedFoodTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      nameDe: data.nameDe.present ? data.nameDe.value : this.nameDe,
      calories: data.calories.present ? data.calories.value : this.calories,
      protein: data.protein.present ? data.protein.value : this.protein,
      carbs: data.carbs.present ? data.carbs.value : this.carbs,
      fat: data.fat.present ? data.fat.value : this.fat,
      sourceCode:
          data.sourceCode.present ? data.sourceCode.value : this.sourceCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VerifiedFoodTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameDe: $nameDe, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fat: $fat, ')
          ..write('sourceCode: $sourceCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, nameDe, calories, protein, carbs, fat, sourceCode);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VerifiedFoodTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.nameDe == this.nameDe &&
          other.calories == this.calories &&
          other.protein == this.protein &&
          other.carbs == this.carbs &&
          other.fat == this.fat &&
          other.sourceCode == this.sourceCode);
}

class VerifiedFoodTableCompanion
    extends UpdateCompanion<VerifiedFoodTableData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> nameDe;
  final Value<int> calories;
  final Value<double> protein;
  final Value<double> carbs;
  final Value<double> fat;
  final Value<String?> sourceCode;
  const VerifiedFoodTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.nameDe = const Value.absent(),
    this.calories = const Value.absent(),
    this.protein = const Value.absent(),
    this.carbs = const Value.absent(),
    this.fat = const Value.absent(),
    this.sourceCode = const Value.absent(),
  });
  VerifiedFoodTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.nameDe = const Value.absent(),
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
    this.sourceCode = const Value.absent(),
  }) : name = Value(name),
       calories = Value(calories),
       protein = Value(protein),
       carbs = Value(carbs),
       fat = Value(fat);
  static Insertable<VerifiedFoodTableData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? nameDe,
    Expression<int>? calories,
    Expression<double>? protein,
    Expression<double>? carbs,
    Expression<double>? fat,
    Expression<String>? sourceCode,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (nameDe != null) 'name_de': nameDe,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fat != null) 'fat': fat,
      if (sourceCode != null) 'source_code': sourceCode,
    });
  }

  VerifiedFoodTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? nameDe,
    Value<int>? calories,
    Value<double>? protein,
    Value<double>? carbs,
    Value<double>? fat,
    Value<String?>? sourceCode,
  }) {
    return VerifiedFoodTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      nameDe: nameDe ?? this.nameDe,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      sourceCode: sourceCode ?? this.sourceCode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameDe.present) {
      map['name_de'] = Variable<String>(nameDe.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    if (protein.present) {
      map['protein'] = Variable<double>(protein.value);
    }
    if (carbs.present) {
      map['carbs'] = Variable<double>(carbs.value);
    }
    if (fat.present) {
      map['fat'] = Variable<double>(fat.value);
    }
    if (sourceCode.present) {
      map['source_code'] = Variable<String>(sourceCode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VerifiedFoodTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('nameDe: $nameDe, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fat: $fat, ')
          ..write('sourceCode: $sourceCode')
          ..write(')'))
        .toString();
  }
}

class $UserSettingsTable extends UserSettings
    with TableInfo<$UserSettingsTable, UserSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dailyCalorieGoalMeta = const VerificationMeta(
    'dailyCalorieGoal',
  );
  @override
  late final GeneratedColumn<int> dailyCalorieGoal = GeneratedColumn<int>(
    'daily_calorie_goal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2000),
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('light'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(30),
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<int> heightCm = GeneratedColumn<int>(
    'height_cm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(170),
  );
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
    'sex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('male'),
  );
  static const VerificationMeta _activityLevelMeta = const VerificationMeta(
    'activityLevel',
  );
  @override
  late final GeneratedColumn<int> activityLevel = GeneratedColumn<int>(
    'activity_level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _goalTypeMeta = const VerificationMeta(
    'goalType',
  );
  @override
  late final GeneratedColumn<int> goalType = GeneratedColumn<int>(
    'goal_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _startingWeightMeta = const VerificationMeta(
    'startingWeight',
  );
  @override
  late final GeneratedColumn<double> startingWeight = GeneratedColumn<double>(
    'starting_weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(80.0),
  );
  static const VerificationMeta _goalWeightMeta = const VerificationMeta(
    'goalWeight',
  );
  @override
  late final GeneratedColumn<double> goalWeight = GeneratedColumn<double>(
    'goal_weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(70.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    dailyCalorieGoal,
    themeMode,
    name,
    age,
    heightCm,
    sex,
    activityLevel,
    goalType,
    startingWeight,
    goalWeight,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('daily_calorie_goal')) {
      context.handle(
        _dailyCalorieGoalMeta,
        dailyCalorieGoal.isAcceptableOrUnknown(
          data['daily_calorie_goal']!,
          _dailyCalorieGoalMeta,
        ),
      );
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    }
    if (data.containsKey('sex')) {
      context.handle(
        _sexMeta,
        sex.isAcceptableOrUnknown(data['sex']!, _sexMeta),
      );
    }
    if (data.containsKey('activity_level')) {
      context.handle(
        _activityLevelMeta,
        activityLevel.isAcceptableOrUnknown(
          data['activity_level']!,
          _activityLevelMeta,
        ),
      );
    }
    if (data.containsKey('goal_type')) {
      context.handle(
        _goalTypeMeta,
        goalType.isAcceptableOrUnknown(data['goal_type']!, _goalTypeMeta),
      );
    }
    if (data.containsKey('starting_weight')) {
      context.handle(
        _startingWeightMeta,
        startingWeight.isAcceptableOrUnknown(
          data['starting_weight']!,
          _startingWeightMeta,
        ),
      );
    }
    if (data.containsKey('goal_weight')) {
      context.handle(
        _goalWeightMeta,
        goalWeight.isAcceptableOrUnknown(data['goal_weight']!, _goalWeightMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserSetting(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      dailyCalorieGoal:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}daily_calorie_goal'],
          )!,
      themeMode:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}theme_mode'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      age:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}age'],
          )!,
      heightCm:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}height_cm'],
          )!,
      sex:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}sex'],
          )!,
      activityLevel:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}activity_level'],
          )!,
      goalType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}goal_type'],
          )!,
      startingWeight:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}starting_weight'],
          )!,
      goalWeight:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}goal_weight'],
          )!,
    );
  }

  @override
  $UserSettingsTable createAlias(String alias) {
    return $UserSettingsTable(attachedDatabase, alias);
  }
}

class UserSetting extends DataClass implements Insertable<UserSetting> {
  final int id;
  final int dailyCalorieGoal;
  final String themeMode;
  final String name;
  final int age;
  final int heightCm;
  final String sex;
  final int activityLevel;
  final int goalType;
  final double startingWeight;
  final double goalWeight;
  const UserSetting({
    required this.id,
    required this.dailyCalorieGoal,
    required this.themeMode,
    required this.name,
    required this.age,
    required this.heightCm,
    required this.sex,
    required this.activityLevel,
    required this.goalType,
    required this.startingWeight,
    required this.goalWeight,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['daily_calorie_goal'] = Variable<int>(dailyCalorieGoal);
    map['theme_mode'] = Variable<String>(themeMode);
    map['name'] = Variable<String>(name);
    map['age'] = Variable<int>(age);
    map['height_cm'] = Variable<int>(heightCm);
    map['sex'] = Variable<String>(sex);
    map['activity_level'] = Variable<int>(activityLevel);
    map['goal_type'] = Variable<int>(goalType);
    map['starting_weight'] = Variable<double>(startingWeight);
    map['goal_weight'] = Variable<double>(goalWeight);
    return map;
  }

  UserSettingsCompanion toCompanion(bool nullToAbsent) {
    return UserSettingsCompanion(
      id: Value(id),
      dailyCalorieGoal: Value(dailyCalorieGoal),
      themeMode: Value(themeMode),
      name: Value(name),
      age: Value(age),
      heightCm: Value(heightCm),
      sex: Value(sex),
      activityLevel: Value(activityLevel),
      goalType: Value(goalType),
      startingWeight: Value(startingWeight),
      goalWeight: Value(goalWeight),
    );
  }

  factory UserSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserSetting(
      id: serializer.fromJson<int>(json['id']),
      dailyCalorieGoal: serializer.fromJson<int>(json['dailyCalorieGoal']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      name: serializer.fromJson<String>(json['name']),
      age: serializer.fromJson<int>(json['age']),
      heightCm: serializer.fromJson<int>(json['heightCm']),
      sex: serializer.fromJson<String>(json['sex']),
      activityLevel: serializer.fromJson<int>(json['activityLevel']),
      goalType: serializer.fromJson<int>(json['goalType']),
      startingWeight: serializer.fromJson<double>(json['startingWeight']),
      goalWeight: serializer.fromJson<double>(json['goalWeight']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dailyCalorieGoal': serializer.toJson<int>(dailyCalorieGoal),
      'themeMode': serializer.toJson<String>(themeMode),
      'name': serializer.toJson<String>(name),
      'age': serializer.toJson<int>(age),
      'heightCm': serializer.toJson<int>(heightCm),
      'sex': serializer.toJson<String>(sex),
      'activityLevel': serializer.toJson<int>(activityLevel),
      'goalType': serializer.toJson<int>(goalType),
      'startingWeight': serializer.toJson<double>(startingWeight),
      'goalWeight': serializer.toJson<double>(goalWeight),
    };
  }

  UserSetting copyWith({
    int? id,
    int? dailyCalorieGoal,
    String? themeMode,
    String? name,
    int? age,
    int? heightCm,
    String? sex,
    int? activityLevel,
    int? goalType,
    double? startingWeight,
    double? goalWeight,
  }) => UserSetting(
    id: id ?? this.id,
    dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
    themeMode: themeMode ?? this.themeMode,
    name: name ?? this.name,
    age: age ?? this.age,
    heightCm: heightCm ?? this.heightCm,
    sex: sex ?? this.sex,
    activityLevel: activityLevel ?? this.activityLevel,
    goalType: goalType ?? this.goalType,
    startingWeight: startingWeight ?? this.startingWeight,
    goalWeight: goalWeight ?? this.goalWeight,
  );
  UserSetting copyWithCompanion(UserSettingsCompanion data) {
    return UserSetting(
      id: data.id.present ? data.id.value : this.id,
      dailyCalorieGoal:
          data.dailyCalorieGoal.present
              ? data.dailyCalorieGoal.value
              : this.dailyCalorieGoal,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      name: data.name.present ? data.name.value : this.name,
      age: data.age.present ? data.age.value : this.age,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      sex: data.sex.present ? data.sex.value : this.sex,
      activityLevel:
          data.activityLevel.present
              ? data.activityLevel.value
              : this.activityLevel,
      goalType: data.goalType.present ? data.goalType.value : this.goalType,
      startingWeight:
          data.startingWeight.present
              ? data.startingWeight.value
              : this.startingWeight,
      goalWeight:
          data.goalWeight.present ? data.goalWeight.value : this.goalWeight,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserSetting(')
          ..write('id: $id, ')
          ..write('dailyCalorieGoal: $dailyCalorieGoal, ')
          ..write('themeMode: $themeMode, ')
          ..write('name: $name, ')
          ..write('age: $age, ')
          ..write('heightCm: $heightCm, ')
          ..write('sex: $sex, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('goalType: $goalType, ')
          ..write('startingWeight: $startingWeight, ')
          ..write('goalWeight: $goalWeight')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    dailyCalorieGoal,
    themeMode,
    name,
    age,
    heightCm,
    sex,
    activityLevel,
    goalType,
    startingWeight,
    goalWeight,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserSetting &&
          other.id == this.id &&
          other.dailyCalorieGoal == this.dailyCalorieGoal &&
          other.themeMode == this.themeMode &&
          other.name == this.name &&
          other.age == this.age &&
          other.heightCm == this.heightCm &&
          other.sex == this.sex &&
          other.activityLevel == this.activityLevel &&
          other.goalType == this.goalType &&
          other.startingWeight == this.startingWeight &&
          other.goalWeight == this.goalWeight);
}

class UserSettingsCompanion extends UpdateCompanion<UserSetting> {
  final Value<int> id;
  final Value<int> dailyCalorieGoal;
  final Value<String> themeMode;
  final Value<String> name;
  final Value<int> age;
  final Value<int> heightCm;
  final Value<String> sex;
  final Value<int> activityLevel;
  final Value<int> goalType;
  final Value<double> startingWeight;
  final Value<double> goalWeight;
  const UserSettingsCompanion({
    this.id = const Value.absent(),
    this.dailyCalorieGoal = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.name = const Value.absent(),
    this.age = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.sex = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.goalType = const Value.absent(),
    this.startingWeight = const Value.absent(),
    this.goalWeight = const Value.absent(),
  });
  UserSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.dailyCalorieGoal = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.name = const Value.absent(),
    this.age = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.sex = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.goalType = const Value.absent(),
    this.startingWeight = const Value.absent(),
    this.goalWeight = const Value.absent(),
  });
  static Insertable<UserSetting> custom({
    Expression<int>? id,
    Expression<int>? dailyCalorieGoal,
    Expression<String>? themeMode,
    Expression<String>? name,
    Expression<int>? age,
    Expression<int>? heightCm,
    Expression<String>? sex,
    Expression<int>? activityLevel,
    Expression<int>? goalType,
    Expression<double>? startingWeight,
    Expression<double>? goalWeight,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dailyCalorieGoal != null) 'daily_calorie_goal': dailyCalorieGoal,
      if (themeMode != null) 'theme_mode': themeMode,
      if (name != null) 'name': name,
      if (age != null) 'age': age,
      if (heightCm != null) 'height_cm': heightCm,
      if (sex != null) 'sex': sex,
      if (activityLevel != null) 'activity_level': activityLevel,
      if (goalType != null) 'goal_type': goalType,
      if (startingWeight != null) 'starting_weight': startingWeight,
      if (goalWeight != null) 'goal_weight': goalWeight,
    });
  }

  UserSettingsCompanion copyWith({
    Value<int>? id,
    Value<int>? dailyCalorieGoal,
    Value<String>? themeMode,
    Value<String>? name,
    Value<int>? age,
    Value<int>? heightCm,
    Value<String>? sex,
    Value<int>? activityLevel,
    Value<int>? goalType,
    Value<double>? startingWeight,
    Value<double>? goalWeight,
  }) {
    return UserSettingsCompanion(
      id: id ?? this.id,
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      themeMode: themeMode ?? this.themeMode,
      name: name ?? this.name,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      sex: sex ?? this.sex,
      activityLevel: activityLevel ?? this.activityLevel,
      goalType: goalType ?? this.goalType,
      startingWeight: startingWeight ?? this.startingWeight,
      goalWeight: goalWeight ?? this.goalWeight,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dailyCalorieGoal.present) {
      map['daily_calorie_goal'] = Variable<int>(dailyCalorieGoal.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<int>(heightCm.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(sex.value);
    }
    if (activityLevel.present) {
      map['activity_level'] = Variable<int>(activityLevel.value);
    }
    if (goalType.present) {
      map['goal_type'] = Variable<int>(goalType.value);
    }
    if (startingWeight.present) {
      map['starting_weight'] = Variable<double>(startingWeight.value);
    }
    if (goalWeight.present) {
      map['goal_weight'] = Variable<double>(goalWeight.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserSettingsCompanion(')
          ..write('id: $id, ')
          ..write('dailyCalorieGoal: $dailyCalorieGoal, ')
          ..write('themeMode: $themeMode, ')
          ..write('name: $name, ')
          ..write('age: $age, ')
          ..write('heightCm: $heightCm, ')
          ..write('sex: $sex, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('goalType: $goalType, ')
          ..write('startingWeight: $startingWeight, ')
          ..write('goalWeight: $goalWeight')
          ..write(')'))
        .toString();
  }
}

class $MealTableTable extends MealTable
    with TableInfo<$MealTableTable, MealTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodItemIdMeta = const VerificationMeta(
    'foodItemId',
  );
  @override
  late final GeneratedColumn<int> foodItemId = GeneratedColumn<int>(
    'food_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    category,
    foodItemId,
    syncStatus,
    serverId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('food_item_id')) {
      context.handle(
        _foodItemIdMeta,
        foodItemId.isAcceptableOrUnknown(
          data['food_item_id']!,
          _foodItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_foodItemIdMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealTableData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      date:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}date'],
          )!,
      category:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}category'],
          )!,
      foodItemId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}food_item_id'],
          )!,
      syncStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sync_status'],
          )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
    );
  }

  @override
  $MealTableTable createAlias(String alias) {
    return $MealTableTable(attachedDatabase, alias);
  }
}

class MealTableData extends DataClass implements Insertable<MealTableData> {
  final int id;
  final DateTime date;
  final String category;
  final int foodItemId;

  /// Maps to [MealSyncStatus] by index.
  final int syncStatus;

  /// UUID assigned by the remote API after first successful sync.
  final String? serverId;
  const MealTableData({
    required this.id,
    required this.date,
    required this.category,
    required this.foodItemId,
    required this.syncStatus,
    this.serverId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['category'] = Variable<String>(category);
    map['food_item_id'] = Variable<int>(foodItemId);
    map['sync_status'] = Variable<int>(syncStatus);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    return map;
  }

  MealTableCompanion toCompanion(bool nullToAbsent) {
    return MealTableCompanion(
      id: Value(id),
      date: Value(date),
      category: Value(category),
      foodItemId: Value(foodItemId),
      syncStatus: Value(syncStatus),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
    );
  }

  factory MealTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealTableData(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      category: serializer.fromJson<String>(json['category']),
      foodItemId: serializer.fromJson<int>(json['foodItemId']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      serverId: serializer.fromJson<String?>(json['serverId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'category': serializer.toJson<String>(category),
      'foodItemId': serializer.toJson<int>(foodItemId),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'serverId': serializer.toJson<String?>(serverId),
    };
  }

  MealTableData copyWith({
    int? id,
    DateTime? date,
    String? category,
    int? foodItemId,
    int? syncStatus,
    Value<String?> serverId = const Value.absent(),
  }) => MealTableData(
    id: id ?? this.id,
    date: date ?? this.date,
    category: category ?? this.category,
    foodItemId: foodItemId ?? this.foodItemId,
    syncStatus: syncStatus ?? this.syncStatus,
    serverId: serverId.present ? serverId.value : this.serverId,
  );
  MealTableData copyWithCompanion(MealTableCompanion data) {
    return MealTableData(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      category: data.category.present ? data.category.value : this.category,
      foodItemId:
          data.foodItemId.present ? data.foodItemId.value : this.foodItemId,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealTableData(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('category: $category, ')
          ..write('foodItemId: $foodItemId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, category, foodItemId, syncStatus, serverId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealTableData &&
          other.id == this.id &&
          other.date == this.date &&
          other.category == this.category &&
          other.foodItemId == this.foodItemId &&
          other.syncStatus == this.syncStatus &&
          other.serverId == this.serverId);
}

class MealTableCompanion extends UpdateCompanion<MealTableData> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> category;
  final Value<int> foodItemId;
  final Value<int> syncStatus;
  final Value<String?> serverId;
  const MealTableCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.category = const Value.absent(),
    this.foodItemId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverId = const Value.absent(),
  });
  MealTableCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required String category,
    required int foodItemId,
    this.syncStatus = const Value.absent(),
    this.serverId = const Value.absent(),
  }) : date = Value(date),
       category = Value(category),
       foodItemId = Value(foodItemId);
  static Insertable<MealTableData> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? category,
    Expression<int>? foodItemId,
    Expression<int>? syncStatus,
    Expression<String>? serverId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (category != null) 'category': category,
      if (foodItemId != null) 'food_item_id': foodItemId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverId != null) 'server_id': serverId,
    });
  }

  MealTableCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String>? category,
    Value<int>? foodItemId,
    Value<int>? syncStatus,
    Value<String?>? serverId,
  }) {
    return MealTableCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      category: category ?? this.category,
      foodItemId: foodItemId ?? this.foodItemId,
      syncStatus: syncStatus ?? this.syncStatus,
      serverId: serverId ?? this.serverId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (foodItemId.present) {
      map['food_item_id'] = Variable<int>(foodItemId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealTableCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('category: $category, ')
          ..write('foodItemId: $foodItemId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }
}

class $MealFoodTableTable extends MealFoodTable
    with TableInfo<$MealFoodTableTable, MealFoodTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealFoodTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mealIdMeta = const VerificationMeta('mealId');
  @override
  late final GeneratedColumn<int> mealId = GeneratedColumn<int>(
    'meal_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meal_table (id)',
    ),
  );
  static const VerificationMeta _foodEntryIdMeta = const VerificationMeta(
    'foodEntryId',
  );
  @override
  late final GeneratedColumn<int> foodEntryId = GeneratedColumn<int>(
    'food_entry_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES food_item (id)',
    ),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, mealId, foodEntryId, serverId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_food_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealFoodTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meal_id')) {
      context.handle(
        _mealIdMeta,
        mealId.isAcceptableOrUnknown(data['meal_id']!, _mealIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mealIdMeta);
    }
    if (data.containsKey('food_entry_id')) {
      context.handle(
        _foodEntryIdMeta,
        foodEntryId.isAcceptableOrUnknown(
          data['food_entry_id']!,
          _foodEntryIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_foodEntryIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealFoodTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealFoodTableData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      mealId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}meal_id'],
          )!,
      foodEntryId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}food_entry_id'],
          )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
    );
  }

  @override
  $MealFoodTableTable createAlias(String alias) {
    return $MealFoodTableTable(attachedDatabase, alias);
  }
}

class MealFoodTableData extends DataClass
    implements Insertable<MealFoodTableData> {
  final int id;
  final int mealId;
  final int foodEntryId;

  /// UUID of the MealFoodEntry on the server, used to delete specific entries.
  final String? serverId;
  const MealFoodTableData({
    required this.id,
    required this.mealId,
    required this.foodEntryId,
    this.serverId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meal_id'] = Variable<int>(mealId);
    map['food_entry_id'] = Variable<int>(foodEntryId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    return map;
  }

  MealFoodTableCompanion toCompanion(bool nullToAbsent) {
    return MealFoodTableCompanion(
      id: Value(id),
      mealId: Value(mealId),
      foodEntryId: Value(foodEntryId),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
    );
  }

  factory MealFoodTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealFoodTableData(
      id: serializer.fromJson<int>(json['id']),
      mealId: serializer.fromJson<int>(json['mealId']),
      foodEntryId: serializer.fromJson<int>(json['foodEntryId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mealId': serializer.toJson<int>(mealId),
      'foodEntryId': serializer.toJson<int>(foodEntryId),
      'serverId': serializer.toJson<String?>(serverId),
    };
  }

  MealFoodTableData copyWith({
    int? id,
    int? mealId,
    int? foodEntryId,
    Value<String?> serverId = const Value.absent(),
  }) => MealFoodTableData(
    id: id ?? this.id,
    mealId: mealId ?? this.mealId,
    foodEntryId: foodEntryId ?? this.foodEntryId,
    serverId: serverId.present ? serverId.value : this.serverId,
  );
  MealFoodTableData copyWithCompanion(MealFoodTableCompanion data) {
    return MealFoodTableData(
      id: data.id.present ? data.id.value : this.id,
      mealId: data.mealId.present ? data.mealId.value : this.mealId,
      foodEntryId:
          data.foodEntryId.present ? data.foodEntryId.value : this.foodEntryId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealFoodTableData(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('foodEntryId: $foodEntryId, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mealId, foodEntryId, serverId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealFoodTableData &&
          other.id == this.id &&
          other.mealId == this.mealId &&
          other.foodEntryId == this.foodEntryId &&
          other.serverId == this.serverId);
}

class MealFoodTableCompanion extends UpdateCompanion<MealFoodTableData> {
  final Value<int> id;
  final Value<int> mealId;
  final Value<int> foodEntryId;
  final Value<String?> serverId;
  const MealFoodTableCompanion({
    this.id = const Value.absent(),
    this.mealId = const Value.absent(),
    this.foodEntryId = const Value.absent(),
    this.serverId = const Value.absent(),
  });
  MealFoodTableCompanion.insert({
    this.id = const Value.absent(),
    required int mealId,
    required int foodEntryId,
    this.serverId = const Value.absent(),
  }) : mealId = Value(mealId),
       foodEntryId = Value(foodEntryId);
  static Insertable<MealFoodTableData> custom({
    Expression<int>? id,
    Expression<int>? mealId,
    Expression<int>? foodEntryId,
    Expression<String>? serverId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mealId != null) 'meal_id': mealId,
      if (foodEntryId != null) 'food_entry_id': foodEntryId,
      if (serverId != null) 'server_id': serverId,
    });
  }

  MealFoodTableCompanion copyWith({
    Value<int>? id,
    Value<int>? mealId,
    Value<int>? foodEntryId,
    Value<String?>? serverId,
  }) {
    return MealFoodTableCompanion(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      foodEntryId: foodEntryId ?? this.foodEntryId,
      serverId: serverId ?? this.serverId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mealId.present) {
      map['meal_id'] = Variable<int>(mealId.value);
    }
    if (foodEntryId.present) {
      map['food_entry_id'] = Variable<int>(foodEntryId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealFoodTableCompanion(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('foodEntryId: $foodEntryId, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }
}

class $SearchCacheTableTable extends SearchCacheTable
    with TableInfo<$SearchCacheTableTable, SearchCacheTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchCacheTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _queryMeta = const VerificationMeta('query');
  @override
  late final GeneratedColumn<String> query = GeneratedColumn<String>(
    'query',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tsMeta = const VerificationMeta('ts');
  @override
  late final GeneratedColumn<int> ts = GeneratedColumn<int>(
    'ts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [query, json, ts];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_cache_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchCacheTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('query')) {
      context.handle(
        _queryMeta,
        query.isAcceptableOrUnknown(data['query']!, _queryMeta),
      );
    } else if (isInserting) {
      context.missing(_queryMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('ts')) {
      context.handle(_tsMeta, ts.isAcceptableOrUnknown(data['ts']!, _tsMeta));
    } else if (isInserting) {
      context.missing(_tsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {query};
  @override
  SearchCacheTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchCacheTableData(
      query:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}query'],
          )!,
      json:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}json'],
          )!,
      ts:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}ts'],
          )!,
    );
  }

  @override
  $SearchCacheTableTable createAlias(String alias) {
    return $SearchCacheTableTable(attachedDatabase, alias);
  }
}

class SearchCacheTableData extends DataClass
    implements Insertable<SearchCacheTableData> {
  final String query;
  final String json;
  final int ts;
  const SearchCacheTableData({
    required this.query,
    required this.json,
    required this.ts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['query'] = Variable<String>(query);
    map['json'] = Variable<String>(json);
    map['ts'] = Variable<int>(ts);
    return map;
  }

  SearchCacheTableCompanion toCompanion(bool nullToAbsent) {
    return SearchCacheTableCompanion(
      query: Value(query),
      json: Value(json),
      ts: Value(ts),
    );
  }

  factory SearchCacheTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchCacheTableData(
      query: serializer.fromJson<String>(json['query']),
      json: serializer.fromJson<String>(json['json']),
      ts: serializer.fromJson<int>(json['ts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'query': serializer.toJson<String>(query),
      'json': serializer.toJson<String>(json),
      'ts': serializer.toJson<int>(ts),
    };
  }

  SearchCacheTableData copyWith({String? query, String? json, int? ts}) =>
      SearchCacheTableData(
        query: query ?? this.query,
        json: json ?? this.json,
        ts: ts ?? this.ts,
      );
  SearchCacheTableData copyWithCompanion(SearchCacheTableCompanion data) {
    return SearchCacheTableData(
      query: data.query.present ? data.query.value : this.query,
      json: data.json.present ? data.json.value : this.json,
      ts: data.ts.present ? data.ts.value : this.ts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchCacheTableData(')
          ..write('query: $query, ')
          ..write('json: $json, ')
          ..write('ts: $ts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(query, json, ts);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchCacheTableData &&
          other.query == this.query &&
          other.json == this.json &&
          other.ts == this.ts);
}

class SearchCacheTableCompanion extends UpdateCompanion<SearchCacheTableData> {
  final Value<String> query;
  final Value<String> json;
  final Value<int> ts;
  final Value<int> rowid;
  const SearchCacheTableCompanion({
    this.query = const Value.absent(),
    this.json = const Value.absent(),
    this.ts = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SearchCacheTableCompanion.insert({
    required String query,
    required String json,
    required int ts,
    this.rowid = const Value.absent(),
  }) : query = Value(query),
       json = Value(json),
       ts = Value(ts);
  static Insertable<SearchCacheTableData> custom({
    Expression<String>? query,
    Expression<String>? json,
    Expression<int>? ts,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (query != null) 'query': query,
      if (json != null) 'json': json,
      if (ts != null) 'ts': ts,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SearchCacheTableCompanion copyWith({
    Value<String>? query,
    Value<String>? json,
    Value<int>? ts,
    Value<int>? rowid,
  }) {
    return SearchCacheTableCompanion(
      query: query ?? this.query,
      json: json ?? this.json,
      ts: ts ?? this.ts,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (query.present) {
      map['query'] = Variable<String>(query.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (ts.present) {
      map['ts'] = Variable<int>(ts.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchCacheTableCompanion(')
          ..write('query: $query, ')
          ..write('json: $json, ')
          ..write('ts: $ts, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeightRecordTable extends WeightRecord
    with TableInfo<$WeightRecordTable, WeightRecordData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeightRecordTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    weight,
    note,
    syncStatus,
    serverId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weight_record';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeightRecordData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    } else if (isInserting) {
      context.missing(_weightMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeightRecordData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeightRecordData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      date:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}date'],
          )!,
      weight:
          attachedDatabase.typeMapping.read(
            DriftSqlType.double,
            data['${effectivePrefix}weight'],
          )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      syncStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sync_status'],
          )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
    );
  }

  @override
  $WeightRecordTable createAlias(String alias) {
    return $WeightRecordTable(attachedDatabase, alias);
  }
}

class WeightRecordData extends DataClass
    implements Insertable<WeightRecordData> {
  final int id;
  final DateTime date;
  final double weight;
  final String? note;

  /// Maps to [WeightSyncStatus] by index. Defaults to [WeightSyncStatus.pending].
  final int syncStatus;

  /// The UUID assigned by the remote API after the first successful sync.
  /// Null until the record has been synced at least once.
  final String? serverId;
  const WeightRecordData({
    required this.id,
    required this.date,
    required this.weight,
    this.note,
    required this.syncStatus,
    this.serverId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['weight'] = Variable<double>(weight);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    return map;
  }

  WeightRecordCompanion toCompanion(bool nullToAbsent) {
    return WeightRecordCompanion(
      id: Value(id),
      date: Value(date),
      weight: Value(weight),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      syncStatus: Value(syncStatus),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
    );
  }

  factory WeightRecordData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeightRecordData(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      weight: serializer.fromJson<double>(json['weight']),
      note: serializer.fromJson<String?>(json['note']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      serverId: serializer.fromJson<String?>(json['serverId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'weight': serializer.toJson<double>(weight),
      'note': serializer.toJson<String?>(note),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'serverId': serializer.toJson<String?>(serverId),
    };
  }

  WeightRecordData copyWith({
    int? id,
    DateTime? date,
    double? weight,
    Value<String?> note = const Value.absent(),
    int? syncStatus,
    Value<String?> serverId = const Value.absent(),
  }) => WeightRecordData(
    id: id ?? this.id,
    date: date ?? this.date,
    weight: weight ?? this.weight,
    note: note.present ? note.value : this.note,
    syncStatus: syncStatus ?? this.syncStatus,
    serverId: serverId.present ? serverId.value : this.serverId,
  );
  WeightRecordData copyWithCompanion(WeightRecordCompanion data) {
    return WeightRecordData(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      weight: data.weight.present ? data.weight.value : this.weight,
      note: data.note.present ? data.note.value : this.note,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeightRecordData(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('weight: $weight, ')
          ..write('note: $note, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, weight, note, syncStatus, serverId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeightRecordData &&
          other.id == this.id &&
          other.date == this.date &&
          other.weight == this.weight &&
          other.note == this.note &&
          other.syncStatus == this.syncStatus &&
          other.serverId == this.serverId);
}

class WeightRecordCompanion extends UpdateCompanion<WeightRecordData> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<double> weight;
  final Value<String?> note;
  final Value<int> syncStatus;
  final Value<String?> serverId;
  const WeightRecordCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.weight = const Value.absent(),
    this.note = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverId = const Value.absent(),
  });
  WeightRecordCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required double weight,
    this.note = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.serverId = const Value.absent(),
  }) : date = Value(date),
       weight = Value(weight);
  static Insertable<WeightRecordData> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<double>? weight,
    Expression<String>? note,
    Expression<int>? syncStatus,
    Expression<String>? serverId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (weight != null) 'weight': weight,
      if (note != null) 'note': note,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (serverId != null) 'server_id': serverId,
    });
  }

  WeightRecordCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<double>? weight,
    Value<String?>? note,
    Value<int>? syncStatus,
    Value<String?>? serverId,
  }) {
    return WeightRecordCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      note: note ?? this.note,
      syncStatus: syncStatus ?? this.syncStatus,
      serverId: serverId ?? this.serverId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeightRecordCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('weight: $weight, ')
          ..write('note: $note, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('serverId: $serverId')
          ..write(')'))
        .toString();
  }
}

class $ExerciseTableTable extends ExerciseTable
    with TableInfo<$ExerciseTableTable, ExerciseTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExerciseTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameDeMeta = const VerificationMeta('nameDe');
  @override
  late final GeneratedColumn<String> nameDe = GeneratedColumn<String>(
    'name_de',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionDeMeta = const VerificationMeta(
    'descriptionDe',
  );
  @override
  late final GeneratedColumn<String> descriptionDe = GeneratedColumn<String>(
    'description_de',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<int> type = GeneratedColumn<int>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetMuscleGroupsMeta =
      const VerificationMeta('targetMuscleGroups');
  @override
  late final GeneratedColumn<String> targetMuscleGroups =
      GeneratedColumn<String>(
        'target_muscle_groups',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    nameDe,
    descriptionDe,
    type,
    targetMuscleGroups,
    imageUrl,
    isCustom,
    serverId,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercise_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExerciseTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('name_de')) {
      context.handle(
        _nameDeMeta,
        nameDe.isAcceptableOrUnknown(data['name_de']!, _nameDeMeta),
      );
    }
    if (data.containsKey('description_de')) {
      context.handle(
        _descriptionDeMeta,
        descriptionDe.isAcceptableOrUnknown(
          data['description_de']!,
          _descriptionDeMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('target_muscle_groups')) {
      context.handle(
        _targetMuscleGroupsMeta,
        targetMuscleGroups.isAcceptableOrUnknown(
          data['target_muscle_groups']!,
          _targetMuscleGroupsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetMuscleGroupsMeta);
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExerciseTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExerciseTableData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      nameDe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_de'],
      ),
      descriptionDe: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description_de'],
      ),
      type:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}type'],
          )!,
      targetMuscleGroups:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}target_muscle_groups'],
          )!,
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      isCustom:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_custom'],
          )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      syncStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sync_status'],
          )!,
    );
  }

  @override
  $ExerciseTableTable createAlias(String alias) {
    return $ExerciseTableTable(attachedDatabase, alias);
  }
}

class ExerciseTableData extends DataClass
    implements Insertable<ExerciseTableData> {
  final int id;
  final String name;
  final String? description;
  final String? nameDe;
  final String? descriptionDe;
  final int type;
  final String targetMuscleGroups;
  final String? imageUrl;
  final bool isCustom;
  final String? serverId;
  final int syncStatus;
  const ExerciseTableData({
    required this.id,
    required this.name,
    this.description,
    this.nameDe,
    this.descriptionDe,
    required this.type,
    required this.targetMuscleGroups,
    this.imageUrl,
    required this.isCustom,
    this.serverId,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || nameDe != null) {
      map['name_de'] = Variable<String>(nameDe);
    }
    if (!nullToAbsent || descriptionDe != null) {
      map['description_de'] = Variable<String>(descriptionDe);
    }
    map['type'] = Variable<int>(type);
    map['target_muscle_groups'] = Variable<String>(targetMuscleGroups);
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    map['is_custom'] = Variable<bool>(isCustom);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  ExerciseTableCompanion toCompanion(bool nullToAbsent) {
    return ExerciseTableCompanion(
      id: Value(id),
      name: Value(name),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
      nameDe:
          nameDe == null && nullToAbsent ? const Value.absent() : Value(nameDe),
      descriptionDe:
          descriptionDe == null && nullToAbsent
              ? const Value.absent()
              : Value(descriptionDe),
      type: Value(type),
      targetMuscleGroups: Value(targetMuscleGroups),
      imageUrl:
          imageUrl == null && nullToAbsent
              ? const Value.absent()
              : Value(imageUrl),
      isCustom: Value(isCustom),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
      syncStatus: Value(syncStatus),
    );
  }

  factory ExerciseTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExerciseTableData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      nameDe: serializer.fromJson<String?>(json['nameDe']),
      descriptionDe: serializer.fromJson<String?>(json['descriptionDe']),
      type: serializer.fromJson<int>(json['type']),
      targetMuscleGroups: serializer.fromJson<String>(
        json['targetMuscleGroups'],
      ),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'nameDe': serializer.toJson<String?>(nameDe),
      'descriptionDe': serializer.toJson<String?>(descriptionDe),
      'type': serializer.toJson<int>(type),
      'targetMuscleGroups': serializer.toJson<String>(targetMuscleGroups),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'isCustom': serializer.toJson<bool>(isCustom),
      'serverId': serializer.toJson<String?>(serverId),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  ExerciseTableData copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    Value<String?> nameDe = const Value.absent(),
    Value<String?> descriptionDe = const Value.absent(),
    int? type,
    String? targetMuscleGroups,
    Value<String?> imageUrl = const Value.absent(),
    bool? isCustom,
    Value<String?> serverId = const Value.absent(),
    int? syncStatus,
  }) => ExerciseTableData(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    nameDe: nameDe.present ? nameDe.value : this.nameDe,
    descriptionDe:
        descriptionDe.present ? descriptionDe.value : this.descriptionDe,
    type: type ?? this.type,
    targetMuscleGroups: targetMuscleGroups ?? this.targetMuscleGroups,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    isCustom: isCustom ?? this.isCustom,
    serverId: serverId.present ? serverId.value : this.serverId,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  ExerciseTableData copyWithCompanion(ExerciseTableCompanion data) {
    return ExerciseTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      nameDe: data.nameDe.present ? data.nameDe.value : this.nameDe,
      descriptionDe:
          data.descriptionDe.present
              ? data.descriptionDe.value
              : this.descriptionDe,
      type: data.type.present ? data.type.value : this.type,
      targetMuscleGroups:
          data.targetMuscleGroups.present
              ? data.targetMuscleGroups.value
              : this.targetMuscleGroups,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('nameDe: $nameDe, ')
          ..write('descriptionDe: $descriptionDe, ')
          ..write('type: $type, ')
          ..write('targetMuscleGroups: $targetMuscleGroups, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('isCustom: $isCustom, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    nameDe,
    descriptionDe,
    type,
    targetMuscleGroups,
    imageUrl,
    isCustom,
    serverId,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExerciseTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.nameDe == this.nameDe &&
          other.descriptionDe == this.descriptionDe &&
          other.type == this.type &&
          other.targetMuscleGroups == this.targetMuscleGroups &&
          other.imageUrl == this.imageUrl &&
          other.isCustom == this.isCustom &&
          other.serverId == this.serverId &&
          other.syncStatus == this.syncStatus);
}

class ExerciseTableCompanion extends UpdateCompanion<ExerciseTableData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> nameDe;
  final Value<String?> descriptionDe;
  final Value<int> type;
  final Value<String> targetMuscleGroups;
  final Value<String?> imageUrl;
  final Value<bool> isCustom;
  final Value<String?> serverId;
  final Value<int> syncStatus;
  const ExerciseTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.nameDe = const Value.absent(),
    this.descriptionDe = const Value.absent(),
    this.type = const Value.absent(),
    this.targetMuscleGroups = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  ExerciseTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    this.nameDe = const Value.absent(),
    this.descriptionDe = const Value.absent(),
    required int type,
    required String targetMuscleGroups,
    this.imageUrl = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : name = Value(name),
       type = Value(type),
       targetMuscleGroups = Value(targetMuscleGroups);
  static Insertable<ExerciseTableData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? nameDe,
    Expression<String>? descriptionDe,
    Expression<int>? type,
    Expression<String>? targetMuscleGroups,
    Expression<String>? imageUrl,
    Expression<bool>? isCustom,
    Expression<String>? serverId,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (nameDe != null) 'name_de': nameDe,
      if (descriptionDe != null) 'description_de': descriptionDe,
      if (type != null) 'type': type,
      if (targetMuscleGroups != null)
        'target_muscle_groups': targetMuscleGroups,
      if (imageUrl != null) 'image_url': imageUrl,
      if (isCustom != null) 'is_custom': isCustom,
      if (serverId != null) 'server_id': serverId,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  ExerciseTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<String?>? nameDe,
    Value<String?>? descriptionDe,
    Value<int>? type,
    Value<String>? targetMuscleGroups,
    Value<String?>? imageUrl,
    Value<bool>? isCustom,
    Value<String?>? serverId,
    Value<int>? syncStatus,
  }) {
    return ExerciseTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      nameDe: nameDe ?? this.nameDe,
      descriptionDe: descriptionDe ?? this.descriptionDe,
      type: type ?? this.type,
      targetMuscleGroups: targetMuscleGroups ?? this.targetMuscleGroups,
      imageUrl: imageUrl ?? this.imageUrl,
      isCustom: isCustom ?? this.isCustom,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (nameDe.present) {
      map['name_de'] = Variable<String>(nameDe.value);
    }
    if (descriptionDe.present) {
      map['description_de'] = Variable<String>(descriptionDe.value);
    }
    if (type.present) {
      map['type'] = Variable<int>(type.value);
    }
    if (targetMuscleGroups.present) {
      map['target_muscle_groups'] = Variable<String>(targetMuscleGroups.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExerciseTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('nameDe: $nameDe, ')
          ..write('descriptionDe: $descriptionDe, ')
          ..write('type: $type, ')
          ..write('targetMuscleGroups: $targetMuscleGroups, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('isCustom: $isCustom, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $WorkoutTableTable extends WorkoutTable
    with TableInfo<$WorkoutTableTable, WorkoutTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<int> difficulty = GeneratedColumn<int>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estimatedDurationMinutesMeta =
      const VerificationMeta('estimatedDurationMinutes');
  @override
  late final GeneratedColumn<int> estimatedDurationMinutes =
      GeneratedColumn<int>(
        'estimated_duration_minutes',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(30),
      );
  static const VerificationMeta _isTemplateMeta = const VerificationMeta(
    'isTemplate',
  );
  @override
  late final GeneratedColumn<bool> isTemplate = GeneratedColumn<bool>(
    'is_template',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_template" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _scheduledDateMeta = const VerificationMeta(
    'scheduledDate',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledDate =
      GeneratedColumn<DateTime>(
        'scheduled_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _completedDateMeta = const VerificationMeta(
    'completedDate',
  );
  @override
  late final GeneratedColumn<DateTime> completedDate =
      GeneratedColumn<DateTime>(
        'completed_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    difficulty,
    estimatedDurationMinutes,
    isTemplate,
    scheduledDate,
    completedDate,
    color,
    serverId,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('estimated_duration_minutes')) {
      context.handle(
        _estimatedDurationMinutesMeta,
        estimatedDurationMinutes.isAcceptableOrUnknown(
          data['estimated_duration_minutes']!,
          _estimatedDurationMinutesMeta,
        ),
      );
    }
    if (data.containsKey('is_template')) {
      context.handle(
        _isTemplateMeta,
        isTemplate.isAcceptableOrUnknown(data['is_template']!, _isTemplateMeta),
      );
    }
    if (data.containsKey('scheduled_date')) {
      context.handle(
        _scheduledDateMeta,
        scheduledDate.isAcceptableOrUnknown(
          data['scheduled_date']!,
          _scheduledDateMeta,
        ),
      );
    }
    if (data.containsKey('completed_date')) {
      context.handle(
        _completedDateMeta,
        completedDate.isAcceptableOrUnknown(
          data['completed_date']!,
          _completedDateMeta,
        ),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutTableData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      difficulty:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}difficulty'],
          )!,
      estimatedDurationMinutes:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}estimated_duration_minutes'],
          )!,
      isTemplate:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_template'],
          )!,
      scheduledDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_date'],
      ),
      completedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_date'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      syncStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sync_status'],
          )!,
    );
  }

  @override
  $WorkoutTableTable createAlias(String alias) {
    return $WorkoutTableTable(attachedDatabase, alias);
  }
}

class WorkoutTableData extends DataClass
    implements Insertable<WorkoutTableData> {
  final int id;
  final String name;
  final String? description;
  final int difficulty;
  final int estimatedDurationMinutes;
  final bool isTemplate;
  final DateTime? scheduledDate;
  final DateTime? completedDate;
  final int? color;
  final String? serverId;
  final int syncStatus;
  const WorkoutTableData({
    required this.id,
    required this.name,
    this.description,
    required this.difficulty,
    required this.estimatedDurationMinutes,
    required this.isTemplate,
    this.scheduledDate,
    this.completedDate,
    this.color,
    this.serverId,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['difficulty'] = Variable<int>(difficulty);
    map['estimated_duration_minutes'] = Variable<int>(estimatedDurationMinutes);
    map['is_template'] = Variable<bool>(isTemplate);
    if (!nullToAbsent || scheduledDate != null) {
      map['scheduled_date'] = Variable<DateTime>(scheduledDate);
    }
    if (!nullToAbsent || completedDate != null) {
      map['completed_date'] = Variable<DateTime>(completedDate);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  WorkoutTableCompanion toCompanion(bool nullToAbsent) {
    return WorkoutTableCompanion(
      id: Value(id),
      name: Value(name),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
      difficulty: Value(difficulty),
      estimatedDurationMinutes: Value(estimatedDurationMinutes),
      isTemplate: Value(isTemplate),
      scheduledDate:
          scheduledDate == null && nullToAbsent
              ? const Value.absent()
              : Value(scheduledDate),
      completedDate:
          completedDate == null && nullToAbsent
              ? const Value.absent()
              : Value(completedDate),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
      syncStatus: Value(syncStatus),
    );
  }

  factory WorkoutTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutTableData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      difficulty: serializer.fromJson<int>(json['difficulty']),
      estimatedDurationMinutes: serializer.fromJson<int>(
        json['estimatedDurationMinutes'],
      ),
      isTemplate: serializer.fromJson<bool>(json['isTemplate']),
      scheduledDate: serializer.fromJson<DateTime?>(json['scheduledDate']),
      completedDate: serializer.fromJson<DateTime?>(json['completedDate']),
      color: serializer.fromJson<int?>(json['color']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'difficulty': serializer.toJson<int>(difficulty),
      'estimatedDurationMinutes': serializer.toJson<int>(
        estimatedDurationMinutes,
      ),
      'isTemplate': serializer.toJson<bool>(isTemplate),
      'scheduledDate': serializer.toJson<DateTime?>(scheduledDate),
      'completedDate': serializer.toJson<DateTime?>(completedDate),
      'color': serializer.toJson<int?>(color),
      'serverId': serializer.toJson<String?>(serverId),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  WorkoutTableData copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    int? difficulty,
    int? estimatedDurationMinutes,
    bool? isTemplate,
    Value<DateTime?> scheduledDate = const Value.absent(),
    Value<DateTime?> completedDate = const Value.absent(),
    Value<int?> color = const Value.absent(),
    Value<String?> serverId = const Value.absent(),
    int? syncStatus,
  }) => WorkoutTableData(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    difficulty: difficulty ?? this.difficulty,
    estimatedDurationMinutes:
        estimatedDurationMinutes ?? this.estimatedDurationMinutes,
    isTemplate: isTemplate ?? this.isTemplate,
    scheduledDate:
        scheduledDate.present ? scheduledDate.value : this.scheduledDate,
    completedDate:
        completedDate.present ? completedDate.value : this.completedDate,
    color: color.present ? color.value : this.color,
    serverId: serverId.present ? serverId.value : this.serverId,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  WorkoutTableData copyWithCompanion(WorkoutTableCompanion data) {
    return WorkoutTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      difficulty:
          data.difficulty.present ? data.difficulty.value : this.difficulty,
      estimatedDurationMinutes:
          data.estimatedDurationMinutes.present
              ? data.estimatedDurationMinutes.value
              : this.estimatedDurationMinutes,
      isTemplate:
          data.isTemplate.present ? data.isTemplate.value : this.isTemplate,
      scheduledDate:
          data.scheduledDate.present
              ? data.scheduledDate.value
              : this.scheduledDate,
      completedDate:
          data.completedDate.present
              ? data.completedDate.value
              : this.completedDate,
      color: data.color.present ? data.color.value : this.color,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('difficulty: $difficulty, ')
          ..write('estimatedDurationMinutes: $estimatedDurationMinutes, ')
          ..write('isTemplate: $isTemplate, ')
          ..write('scheduledDate: $scheduledDate, ')
          ..write('completedDate: $completedDate, ')
          ..write('color: $color, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    difficulty,
    estimatedDurationMinutes,
    isTemplate,
    scheduledDate,
    completedDate,
    color,
    serverId,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.difficulty == this.difficulty &&
          other.estimatedDurationMinutes == this.estimatedDurationMinutes &&
          other.isTemplate == this.isTemplate &&
          other.scheduledDate == this.scheduledDate &&
          other.completedDate == this.completedDate &&
          other.color == this.color &&
          other.serverId == this.serverId &&
          other.syncStatus == this.syncStatus);
}

class WorkoutTableCompanion extends UpdateCompanion<WorkoutTableData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> difficulty;
  final Value<int> estimatedDurationMinutes;
  final Value<bool> isTemplate;
  final Value<DateTime?> scheduledDate;
  final Value<DateTime?> completedDate;
  final Value<int?> color;
  final Value<String?> serverId;
  final Value<int> syncStatus;
  const WorkoutTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.estimatedDurationMinutes = const Value.absent(),
    this.isTemplate = const Value.absent(),
    this.scheduledDate = const Value.absent(),
    this.completedDate = const Value.absent(),
    this.color = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  WorkoutTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    required int difficulty,
    this.estimatedDurationMinutes = const Value.absent(),
    this.isTemplate = const Value.absent(),
    this.scheduledDate = const Value.absent(),
    this.completedDate = const Value.absent(),
    this.color = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : name = Value(name),
       difficulty = Value(difficulty);
  static Insertable<WorkoutTableData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? difficulty,
    Expression<int>? estimatedDurationMinutes,
    Expression<bool>? isTemplate,
    Expression<DateTime>? scheduledDate,
    Expression<DateTime>? completedDate,
    Expression<int>? color,
    Expression<String>? serverId,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (difficulty != null) 'difficulty': difficulty,
      if (estimatedDurationMinutes != null)
        'estimated_duration_minutes': estimatedDurationMinutes,
      if (isTemplate != null) 'is_template': isTemplate,
      if (scheduledDate != null) 'scheduled_date': scheduledDate,
      if (completedDate != null) 'completed_date': completedDate,
      if (color != null) 'color': color,
      if (serverId != null) 'server_id': serverId,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  WorkoutTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<int>? difficulty,
    Value<int>? estimatedDurationMinutes,
    Value<bool>? isTemplate,
    Value<DateTime?>? scheduledDate,
    Value<DateTime?>? completedDate,
    Value<int?>? color,
    Value<String?>? serverId,
    Value<int>? syncStatus,
  }) {
    return WorkoutTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      difficulty: difficulty ?? this.difficulty,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      isTemplate: isTemplate ?? this.isTemplate,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      color: color ?? this.color,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<int>(difficulty.value);
    }
    if (estimatedDurationMinutes.present) {
      map['estimated_duration_minutes'] = Variable<int>(
        estimatedDurationMinutes.value,
      );
    }
    if (isTemplate.present) {
      map['is_template'] = Variable<bool>(isTemplate.value);
    }
    if (scheduledDate.present) {
      map['scheduled_date'] = Variable<DateTime>(scheduledDate.value);
    }
    if (completedDate.present) {
      map['completed_date'] = Variable<DateTime>(completedDate.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('difficulty: $difficulty, ')
          ..write('estimatedDurationMinutes: $estimatedDurationMinutes, ')
          ..write('isTemplate: $isTemplate, ')
          ..write('scheduledDate: $scheduledDate, ')
          ..write('completedDate: $completedDate, ')
          ..write('color: $color, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $WorkoutPlanTableTable extends WorkoutPlanTable
    with TableInfo<$WorkoutPlanTableTable, WorkoutPlanTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutPlanTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _cyclePatternJsonMeta = const VerificationMeta(
    'cyclePatternJson',
  );
  @override
  late final GeneratedColumn<String> cyclePatternJson = GeneratedColumn<String>(
    'cycle_pattern_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isFreeChoiceMeta = const VerificationMeta(
    'isFreeChoice',
  );
  @override
  late final GeneratedColumn<bool> isFreeChoice = GeneratedColumn<bool>(
    'is_free_choice',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_free_choice" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _durationDaysMeta = const VerificationMeta(
    'durationDays',
  );
  @override
  late final GeneratedColumn<int> durationDays = GeneratedColumn<int>(
    'duration_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    startDate,
    createdAt,
    isActive,
    cyclePatternJson,
    isFreeChoice,
    durationDays,
    serverId,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_plan_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutPlanTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('cycle_pattern_json')) {
      context.handle(
        _cyclePatternJsonMeta,
        cyclePatternJson.isAcceptableOrUnknown(
          data['cycle_pattern_json']!,
          _cyclePatternJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cyclePatternJsonMeta);
    }
    if (data.containsKey('is_free_choice')) {
      context.handle(
        _isFreeChoiceMeta,
        isFreeChoice.isAcceptableOrUnknown(
          data['is_free_choice']!,
          _isFreeChoiceMeta,
        ),
      );
    }
    if (data.containsKey('duration_days')) {
      context.handle(
        _durationDaysMeta,
        durationDays.isAcceptableOrUnknown(
          data['duration_days']!,
          _durationDaysMeta,
        ),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutPlanTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutPlanTableData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      name:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}name'],
          )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      startDate:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}start_date'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      isActive:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_active'],
          )!,
      cyclePatternJson:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}cycle_pattern_json'],
          )!,
      isFreeChoice:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_free_choice'],
          )!,
      durationDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_days'],
      ),
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      syncStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sync_status'],
          )!,
    );
  }

  @override
  $WorkoutPlanTableTable createAlias(String alias) {
    return $WorkoutPlanTableTable(attachedDatabase, alias);
  }
}

class WorkoutPlanTableData extends DataClass
    implements Insertable<WorkoutPlanTableData> {
  final int id;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime createdAt;
  final bool isActive;
  final String cyclePatternJson;
  final bool isFreeChoice;
  final int? durationDays;
  final String? serverId;
  final int syncStatus;
  const WorkoutPlanTableData({
    required this.id,
    required this.name,
    this.description,
    required this.startDate,
    required this.createdAt,
    required this.isActive,
    required this.cyclePatternJson,
    required this.isFreeChoice,
    this.durationDays,
    this.serverId,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['start_date'] = Variable<DateTime>(startDate);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_active'] = Variable<bool>(isActive);
    map['cycle_pattern_json'] = Variable<String>(cyclePatternJson);
    map['is_free_choice'] = Variable<bool>(isFreeChoice);
    if (!nullToAbsent || durationDays != null) {
      map['duration_days'] = Variable<int>(durationDays);
    }
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  WorkoutPlanTableCompanion toCompanion(bool nullToAbsent) {
    return WorkoutPlanTableCompanion(
      id: Value(id),
      name: Value(name),
      description:
          description == null && nullToAbsent
              ? const Value.absent()
              : Value(description),
      startDate: Value(startDate),
      createdAt: Value(createdAt),
      isActive: Value(isActive),
      cyclePatternJson: Value(cyclePatternJson),
      isFreeChoice: Value(isFreeChoice),
      durationDays:
          durationDays == null && nullToAbsent
              ? const Value.absent()
              : Value(durationDays),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
      syncStatus: Value(syncStatus),
    );
  }

  factory WorkoutPlanTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutPlanTableData(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      cyclePatternJson: serializer.fromJson<String>(json['cyclePatternJson']),
      isFreeChoice: serializer.fromJson<bool>(json['isFreeChoice']),
      durationDays: serializer.fromJson<int?>(json['durationDays']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'startDate': serializer.toJson<DateTime>(startDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isActive': serializer.toJson<bool>(isActive),
      'cyclePatternJson': serializer.toJson<String>(cyclePatternJson),
      'isFreeChoice': serializer.toJson<bool>(isFreeChoice),
      'durationDays': serializer.toJson<int?>(durationDays),
      'serverId': serializer.toJson<String?>(serverId),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  WorkoutPlanTableData copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    DateTime? startDate,
    DateTime? createdAt,
    bool? isActive,
    String? cyclePatternJson,
    bool? isFreeChoice,
    Value<int?> durationDays = const Value.absent(),
    Value<String?> serverId = const Value.absent(),
    int? syncStatus,
  }) => WorkoutPlanTableData(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    startDate: startDate ?? this.startDate,
    createdAt: createdAt ?? this.createdAt,
    isActive: isActive ?? this.isActive,
    cyclePatternJson: cyclePatternJson ?? this.cyclePatternJson,
    isFreeChoice: isFreeChoice ?? this.isFreeChoice,
    durationDays: durationDays.present ? durationDays.value : this.durationDays,
    serverId: serverId.present ? serverId.value : this.serverId,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  WorkoutPlanTableData copyWithCompanion(WorkoutPlanTableCompanion data) {
    return WorkoutPlanTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      cyclePatternJson:
          data.cyclePatternJson.present
              ? data.cyclePatternJson.value
              : this.cyclePatternJson,
      isFreeChoice:
          data.isFreeChoice.present
              ? data.isFreeChoice.value
              : this.isFreeChoice,
      durationDays:
          data.durationDays.present
              ? data.durationDays.value
              : this.durationDays,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutPlanTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('startDate: $startDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('isActive: $isActive, ')
          ..write('cyclePatternJson: $cyclePatternJson, ')
          ..write('isFreeChoice: $isFreeChoice, ')
          ..write('durationDays: $durationDays, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    startDate,
    createdAt,
    isActive,
    cyclePatternJson,
    isFreeChoice,
    durationDays,
    serverId,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutPlanTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.startDate == this.startDate &&
          other.createdAt == this.createdAt &&
          other.isActive == this.isActive &&
          other.cyclePatternJson == this.cyclePatternJson &&
          other.isFreeChoice == this.isFreeChoice &&
          other.durationDays == this.durationDays &&
          other.serverId == this.serverId &&
          other.syncStatus == this.syncStatus);
}

class WorkoutPlanTableCompanion extends UpdateCompanion<WorkoutPlanTableData> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<DateTime> startDate;
  final Value<DateTime> createdAt;
  final Value<bool> isActive;
  final Value<String> cyclePatternJson;
  final Value<bool> isFreeChoice;
  final Value<int?> durationDays;
  final Value<String?> serverId;
  final Value<int> syncStatus;
  const WorkoutPlanTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.startDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isActive = const Value.absent(),
    this.cyclePatternJson = const Value.absent(),
    this.isFreeChoice = const Value.absent(),
    this.durationDays = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  WorkoutPlanTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    required DateTime startDate,
    this.createdAt = const Value.absent(),
    this.isActive = const Value.absent(),
    required String cyclePatternJson,
    this.isFreeChoice = const Value.absent(),
    this.durationDays = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : name = Value(name),
       startDate = Value(startDate),
       cyclePatternJson = Value(cyclePatternJson);
  static Insertable<WorkoutPlanTableData> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<DateTime>? startDate,
    Expression<DateTime>? createdAt,
    Expression<bool>? isActive,
    Expression<String>? cyclePatternJson,
    Expression<bool>? isFreeChoice,
    Expression<int>? durationDays,
    Expression<String>? serverId,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (startDate != null) 'start_date': startDate,
      if (createdAt != null) 'created_at': createdAt,
      if (isActive != null) 'is_active': isActive,
      if (cyclePatternJson != null) 'cycle_pattern_json': cyclePatternJson,
      if (isFreeChoice != null) 'is_free_choice': isFreeChoice,
      if (durationDays != null) 'duration_days': durationDays,
      if (serverId != null) 'server_id': serverId,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  WorkoutPlanTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<DateTime>? startDate,
    Value<DateTime>? createdAt,
    Value<bool>? isActive,
    Value<String>? cyclePatternJson,
    Value<bool>? isFreeChoice,
    Value<int?>? durationDays,
    Value<String?>? serverId,
    Value<int>? syncStatus,
  }) {
    return WorkoutPlanTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      cyclePatternJson: cyclePatternJson ?? this.cyclePatternJson,
      isFreeChoice: isFreeChoice ?? this.isFreeChoice,
      durationDays: durationDays ?? this.durationDays,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (cyclePatternJson.present) {
      map['cycle_pattern_json'] = Variable<String>(cyclePatternJson.value);
    }
    if (isFreeChoice.present) {
      map['is_free_choice'] = Variable<bool>(isFreeChoice.value);
    }
    if (durationDays.present) {
      map['duration_days'] = Variable<int>(durationDays.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutPlanTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('startDate: $startDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('isActive: $isActive, ')
          ..write('cyclePatternJson: $cyclePatternJson, ')
          ..write('isFreeChoice: $isFreeChoice, ')
          ..write('durationDays: $durationDays, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $WorkoutExerciseTableTable extends WorkoutExerciseTable
    with TableInfo<$WorkoutExerciseTableTable, WorkoutExerciseTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutExerciseTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _workoutIdMeta = const VerificationMeta(
    'workoutId',
  );
  @override
  late final GeneratedColumn<int> workoutId = GeneratedColumn<int>(
    'workout_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_table (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _exerciseIdMeta = const VerificationMeta(
    'exerciseId',
  );
  @override
  late final GeneratedColumn<int> exerciseId = GeneratedColumn<int>(
    'exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES exercise_table (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _orderPositionMeta = const VerificationMeta(
    'orderPosition',
  );
  @override
  late final GeneratedColumn<int> orderPosition = GeneratedColumn<int>(
    'order_position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _supersetGroupIdMeta = const VerificationMeta(
    'supersetGroupId',
  );
  @override
  late final GeneratedColumn<int> supersetGroupId = GeneratedColumn<int>(
    'superset_group_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workoutId,
    exerciseId,
    orderPosition,
    notes,
    supersetGroupId,
    serverId,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_exercise_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutExerciseTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('workout_id')) {
      context.handle(
        _workoutIdMeta,
        workoutId.isAcceptableOrUnknown(data['workout_id']!, _workoutIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workoutIdMeta);
    }
    if (data.containsKey('exercise_id')) {
      context.handle(
        _exerciseIdMeta,
        exerciseId.isAcceptableOrUnknown(data['exercise_id']!, _exerciseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_exerciseIdMeta);
    }
    if (data.containsKey('order_position')) {
      context.handle(
        _orderPositionMeta,
        orderPosition.isAcceptableOrUnknown(
          data['order_position']!,
          _orderPositionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_orderPositionMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('superset_group_id')) {
      context.handle(
        _supersetGroupIdMeta,
        supersetGroupId.isAcceptableOrUnknown(
          data['superset_group_id']!,
          _supersetGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutExerciseTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutExerciseTableData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      workoutId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}workout_id'],
          )!,
      exerciseId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}exercise_id'],
          )!,
      orderPosition:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}order_position'],
          )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      supersetGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}superset_group_id'],
      ),
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      syncStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sync_status'],
          )!,
    );
  }

  @override
  $WorkoutExerciseTableTable createAlias(String alias) {
    return $WorkoutExerciseTableTable(attachedDatabase, alias);
  }
}

class WorkoutExerciseTableData extends DataClass
    implements Insertable<WorkoutExerciseTableData> {
  final int id;
  final int workoutId;
  final int exerciseId;
  final int orderPosition;
  final String? notes;
  final int? supersetGroupId;
  final String? serverId;
  final int syncStatus;
  const WorkoutExerciseTableData({
    required this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.orderPosition,
    this.notes,
    this.supersetGroupId,
    this.serverId,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['workout_id'] = Variable<int>(workoutId);
    map['exercise_id'] = Variable<int>(exerciseId);
    map['order_position'] = Variable<int>(orderPosition);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || supersetGroupId != null) {
      map['superset_group_id'] = Variable<int>(supersetGroupId);
    }
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  WorkoutExerciseTableCompanion toCompanion(bool nullToAbsent) {
    return WorkoutExerciseTableCompanion(
      id: Value(id),
      workoutId: Value(workoutId),
      exerciseId: Value(exerciseId),
      orderPosition: Value(orderPosition),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      supersetGroupId:
          supersetGroupId == null && nullToAbsent
              ? const Value.absent()
              : Value(supersetGroupId),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
      syncStatus: Value(syncStatus),
    );
  }

  factory WorkoutExerciseTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutExerciseTableData(
      id: serializer.fromJson<int>(json['id']),
      workoutId: serializer.fromJson<int>(json['workoutId']),
      exerciseId: serializer.fromJson<int>(json['exerciseId']),
      orderPosition: serializer.fromJson<int>(json['orderPosition']),
      notes: serializer.fromJson<String?>(json['notes']),
      supersetGroupId: serializer.fromJson<int?>(json['supersetGroupId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'workoutId': serializer.toJson<int>(workoutId),
      'exerciseId': serializer.toJson<int>(exerciseId),
      'orderPosition': serializer.toJson<int>(orderPosition),
      'notes': serializer.toJson<String?>(notes),
      'supersetGroupId': serializer.toJson<int?>(supersetGroupId),
      'serverId': serializer.toJson<String?>(serverId),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  WorkoutExerciseTableData copyWith({
    int? id,
    int? workoutId,
    int? exerciseId,
    int? orderPosition,
    Value<String?> notes = const Value.absent(),
    Value<int?> supersetGroupId = const Value.absent(),
    Value<String?> serverId = const Value.absent(),
    int? syncStatus,
  }) => WorkoutExerciseTableData(
    id: id ?? this.id,
    workoutId: workoutId ?? this.workoutId,
    exerciseId: exerciseId ?? this.exerciseId,
    orderPosition: orderPosition ?? this.orderPosition,
    notes: notes.present ? notes.value : this.notes,
    supersetGroupId:
        supersetGroupId.present ? supersetGroupId.value : this.supersetGroupId,
    serverId: serverId.present ? serverId.value : this.serverId,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  WorkoutExerciseTableData copyWithCompanion(
    WorkoutExerciseTableCompanion data,
  ) {
    return WorkoutExerciseTableData(
      id: data.id.present ? data.id.value : this.id,
      workoutId: data.workoutId.present ? data.workoutId.value : this.workoutId,
      exerciseId:
          data.exerciseId.present ? data.exerciseId.value : this.exerciseId,
      orderPosition:
          data.orderPosition.present
              ? data.orderPosition.value
              : this.orderPosition,
      notes: data.notes.present ? data.notes.value : this.notes,
      supersetGroupId:
          data.supersetGroupId.present
              ? data.supersetGroupId.value
              : this.supersetGroupId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutExerciseTableData(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('orderPosition: $orderPosition, ')
          ..write('notes: $notes, ')
          ..write('supersetGroupId: $supersetGroupId, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workoutId,
    exerciseId,
    orderPosition,
    notes,
    supersetGroupId,
    serverId,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutExerciseTableData &&
          other.id == this.id &&
          other.workoutId == this.workoutId &&
          other.exerciseId == this.exerciseId &&
          other.orderPosition == this.orderPosition &&
          other.notes == this.notes &&
          other.supersetGroupId == this.supersetGroupId &&
          other.serverId == this.serverId &&
          other.syncStatus == this.syncStatus);
}

class WorkoutExerciseTableCompanion
    extends UpdateCompanion<WorkoutExerciseTableData> {
  final Value<int> id;
  final Value<int> workoutId;
  final Value<int> exerciseId;
  final Value<int> orderPosition;
  final Value<String?> notes;
  final Value<int?> supersetGroupId;
  final Value<String?> serverId;
  final Value<int> syncStatus;
  const WorkoutExerciseTableCompanion({
    this.id = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.exerciseId = const Value.absent(),
    this.orderPosition = const Value.absent(),
    this.notes = const Value.absent(),
    this.supersetGroupId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  WorkoutExerciseTableCompanion.insert({
    this.id = const Value.absent(),
    required int workoutId,
    required int exerciseId,
    required int orderPosition,
    this.notes = const Value.absent(),
    this.supersetGroupId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : workoutId = Value(workoutId),
       exerciseId = Value(exerciseId),
       orderPosition = Value(orderPosition);
  static Insertable<WorkoutExerciseTableData> custom({
    Expression<int>? id,
    Expression<int>? workoutId,
    Expression<int>? exerciseId,
    Expression<int>? orderPosition,
    Expression<String>? notes,
    Expression<int>? supersetGroupId,
    Expression<String>? serverId,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workoutId != null) 'workout_id': workoutId,
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (orderPosition != null) 'order_position': orderPosition,
      if (notes != null) 'notes': notes,
      if (supersetGroupId != null) 'superset_group_id': supersetGroupId,
      if (serverId != null) 'server_id': serverId,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  WorkoutExerciseTableCompanion copyWith({
    Value<int>? id,
    Value<int>? workoutId,
    Value<int>? exerciseId,
    Value<int>? orderPosition,
    Value<String?>? notes,
    Value<int?>? supersetGroupId,
    Value<String?>? serverId,
    Value<int>? syncStatus,
  }) {
    return WorkoutExerciseTableCompanion(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      exerciseId: exerciseId ?? this.exerciseId,
      orderPosition: orderPosition ?? this.orderPosition,
      notes: notes ?? this.notes,
      supersetGroupId: supersetGroupId ?? this.supersetGroupId,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (workoutId.present) {
      map['workout_id'] = Variable<int>(workoutId.value);
    }
    if (exerciseId.present) {
      map['exercise_id'] = Variable<int>(exerciseId.value);
    }
    if (orderPosition.present) {
      map['order_position'] = Variable<int>(orderPosition.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (supersetGroupId.present) {
      map['superset_group_id'] = Variable<int>(supersetGroupId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutExerciseTableCompanion(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('exerciseId: $exerciseId, ')
          ..write('orderPosition: $orderPosition, ')
          ..write('notes: $notes, ')
          ..write('supersetGroupId: $supersetGroupId, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $ScheduledWorkoutTableTable extends ScheduledWorkoutTable
    with TableInfo<$ScheduledWorkoutTableTable, ScheduledWorkoutTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledWorkoutTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _workoutIdMeta = const VerificationMeta(
    'workoutId',
  );
  @override
  late final GeneratedColumn<int> workoutId = GeneratedColumn<int>(
    'workout_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_table (id)',
    ),
  );
  static const VerificationMeta _workoutPlanIdMeta = const VerificationMeta(
    'workoutPlanId',
  );
  @override
  late final GeneratedColumn<int> workoutPlanId = GeneratedColumn<int>(
    'workout_plan_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_plan_table (id)',
    ),
  );
  static const VerificationMeta _templateWorkoutIdMeta = const VerificationMeta(
    'templateWorkoutId',
  );
  @override
  late final GeneratedColumn<int> templateWorkoutId = GeneratedColumn<int>(
    'template_workout_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_table (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _scheduledDateMeta = const VerificationMeta(
    'scheduledDate',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledDate =
      GeneratedColumn<DateTime>(
        'scheduled_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isSkippedMeta = const VerificationMeta(
    'isSkipped',
  );
  @override
  late final GeneratedColumn<bool> isSkipped = GeneratedColumn<bool>(
    'is_skipped',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_skipped" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workoutId,
    workoutPlanId,
    templateWorkoutId,
    scheduledDate,
    createdAt,
    notes,
    isCompleted,
    isSkipped,
    serverId,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_workout_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledWorkoutTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('workout_id')) {
      context.handle(
        _workoutIdMeta,
        workoutId.isAcceptableOrUnknown(data['workout_id']!, _workoutIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workoutIdMeta);
    }
    if (data.containsKey('workout_plan_id')) {
      context.handle(
        _workoutPlanIdMeta,
        workoutPlanId.isAcceptableOrUnknown(
          data['workout_plan_id']!,
          _workoutPlanIdMeta,
        ),
      );
    }
    if (data.containsKey('template_workout_id')) {
      context.handle(
        _templateWorkoutIdMeta,
        templateWorkoutId.isAcceptableOrUnknown(
          data['template_workout_id']!,
          _templateWorkoutIdMeta,
        ),
      );
    }
    if (data.containsKey('scheduled_date')) {
      context.handle(
        _scheduledDateMeta,
        scheduledDate.isAcceptableOrUnknown(
          data['scheduled_date']!,
          _scheduledDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledDateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('is_skipped')) {
      context.handle(
        _isSkippedMeta,
        isSkipped.isAcceptableOrUnknown(data['is_skipped']!, _isSkippedMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduledWorkoutTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledWorkoutTableData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      workoutId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}workout_id'],
          )!,
      workoutPlanId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}workout_plan_id'],
      ),
      templateWorkoutId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}template_workout_id'],
      ),
      scheduledDate:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}scheduled_date'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      isCompleted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_completed'],
          )!,
      isSkipped:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_skipped'],
          )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      syncStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sync_status'],
          )!,
    );
  }

  @override
  $ScheduledWorkoutTableTable createAlias(String alias) {
    return $ScheduledWorkoutTableTable(attachedDatabase, alias);
  }
}

class ScheduledWorkoutTableData extends DataClass
    implements Insertable<ScheduledWorkoutTableData> {
  final int id;

  /// Links to the workout template or workout entry
  final int workoutId;
  final int? workoutPlanId;
  final int? templateWorkoutId;

  /// The date/time this workout is scheduled for
  final DateTime scheduledDate;

  /// When the scheduled entry was created. Use a clientDefault so
  /// sqlite3 native doesn't receive a non-constant SQL default.
  final DateTime createdAt;
  final String? notes;
  final bool isCompleted;
  final bool isSkipped;
  final String? serverId;
  final int syncStatus;
  const ScheduledWorkoutTableData({
    required this.id,
    required this.workoutId,
    this.workoutPlanId,
    this.templateWorkoutId,
    required this.scheduledDate,
    required this.createdAt,
    this.notes,
    required this.isCompleted,
    required this.isSkipped,
    this.serverId,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['workout_id'] = Variable<int>(workoutId);
    if (!nullToAbsent || workoutPlanId != null) {
      map['workout_plan_id'] = Variable<int>(workoutPlanId);
    }
    if (!nullToAbsent || templateWorkoutId != null) {
      map['template_workout_id'] = Variable<int>(templateWorkoutId);
    }
    map['scheduled_date'] = Variable<DateTime>(scheduledDate);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['is_completed'] = Variable<bool>(isCompleted);
    map['is_skipped'] = Variable<bool>(isSkipped);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  ScheduledWorkoutTableCompanion toCompanion(bool nullToAbsent) {
    return ScheduledWorkoutTableCompanion(
      id: Value(id),
      workoutId: Value(workoutId),
      workoutPlanId:
          workoutPlanId == null && nullToAbsent
              ? const Value.absent()
              : Value(workoutPlanId),
      templateWorkoutId:
          templateWorkoutId == null && nullToAbsent
              ? const Value.absent()
              : Value(templateWorkoutId),
      scheduledDate: Value(scheduledDate),
      createdAt: Value(createdAt),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      isCompleted: Value(isCompleted),
      isSkipped: Value(isSkipped),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
      syncStatus: Value(syncStatus),
    );
  }

  factory ScheduledWorkoutTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledWorkoutTableData(
      id: serializer.fromJson<int>(json['id']),
      workoutId: serializer.fromJson<int>(json['workoutId']),
      workoutPlanId: serializer.fromJson<int?>(json['workoutPlanId']),
      templateWorkoutId: serializer.fromJson<int?>(json['templateWorkoutId']),
      scheduledDate: serializer.fromJson<DateTime>(json['scheduledDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      notes: serializer.fromJson<String?>(json['notes']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      isSkipped: serializer.fromJson<bool>(json['isSkipped']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'workoutId': serializer.toJson<int>(workoutId),
      'workoutPlanId': serializer.toJson<int?>(workoutPlanId),
      'templateWorkoutId': serializer.toJson<int?>(templateWorkoutId),
      'scheduledDate': serializer.toJson<DateTime>(scheduledDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'notes': serializer.toJson<String?>(notes),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'isSkipped': serializer.toJson<bool>(isSkipped),
      'serverId': serializer.toJson<String?>(serverId),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  ScheduledWorkoutTableData copyWith({
    int? id,
    int? workoutId,
    Value<int?> workoutPlanId = const Value.absent(),
    Value<int?> templateWorkoutId = const Value.absent(),
    DateTime? scheduledDate,
    DateTime? createdAt,
    Value<String?> notes = const Value.absent(),
    bool? isCompleted,
    bool? isSkipped,
    Value<String?> serverId = const Value.absent(),
    int? syncStatus,
  }) => ScheduledWorkoutTableData(
    id: id ?? this.id,
    workoutId: workoutId ?? this.workoutId,
    workoutPlanId:
        workoutPlanId.present ? workoutPlanId.value : this.workoutPlanId,
    templateWorkoutId:
        templateWorkoutId.present
            ? templateWorkoutId.value
            : this.templateWorkoutId,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    createdAt: createdAt ?? this.createdAt,
    notes: notes.present ? notes.value : this.notes,
    isCompleted: isCompleted ?? this.isCompleted,
    isSkipped: isSkipped ?? this.isSkipped,
    serverId: serverId.present ? serverId.value : this.serverId,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  ScheduledWorkoutTableData copyWithCompanion(
    ScheduledWorkoutTableCompanion data,
  ) {
    return ScheduledWorkoutTableData(
      id: data.id.present ? data.id.value : this.id,
      workoutId: data.workoutId.present ? data.workoutId.value : this.workoutId,
      workoutPlanId:
          data.workoutPlanId.present
              ? data.workoutPlanId.value
              : this.workoutPlanId,
      templateWorkoutId:
          data.templateWorkoutId.present
              ? data.templateWorkoutId.value
              : this.templateWorkoutId,
      scheduledDate:
          data.scheduledDate.present
              ? data.scheduledDate.value
              : this.scheduledDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      notes: data.notes.present ? data.notes.value : this.notes,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      isSkipped: data.isSkipped.present ? data.isSkipped.value : this.isSkipped,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledWorkoutTableData(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('workoutPlanId: $workoutPlanId, ')
          ..write('templateWorkoutId: $templateWorkoutId, ')
          ..write('scheduledDate: $scheduledDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('notes: $notes, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('isSkipped: $isSkipped, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workoutId,
    workoutPlanId,
    templateWorkoutId,
    scheduledDate,
    createdAt,
    notes,
    isCompleted,
    isSkipped,
    serverId,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledWorkoutTableData &&
          other.id == this.id &&
          other.workoutId == this.workoutId &&
          other.workoutPlanId == this.workoutPlanId &&
          other.templateWorkoutId == this.templateWorkoutId &&
          other.scheduledDate == this.scheduledDate &&
          other.createdAt == this.createdAt &&
          other.notes == this.notes &&
          other.isCompleted == this.isCompleted &&
          other.isSkipped == this.isSkipped &&
          other.serverId == this.serverId &&
          other.syncStatus == this.syncStatus);
}

class ScheduledWorkoutTableCompanion
    extends UpdateCompanion<ScheduledWorkoutTableData> {
  final Value<int> id;
  final Value<int> workoutId;
  final Value<int?> workoutPlanId;
  final Value<int?> templateWorkoutId;
  final Value<DateTime> scheduledDate;
  final Value<DateTime> createdAt;
  final Value<String?> notes;
  final Value<bool> isCompleted;
  final Value<bool> isSkipped;
  final Value<String?> serverId;
  final Value<int> syncStatus;
  const ScheduledWorkoutTableCompanion({
    this.id = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.workoutPlanId = const Value.absent(),
    this.templateWorkoutId = const Value.absent(),
    this.scheduledDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.isSkipped = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  ScheduledWorkoutTableCompanion.insert({
    this.id = const Value.absent(),
    required int workoutId,
    this.workoutPlanId = const Value.absent(),
    this.templateWorkoutId = const Value.absent(),
    required DateTime scheduledDate,
    this.createdAt = const Value.absent(),
    this.notes = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.isSkipped = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : workoutId = Value(workoutId),
       scheduledDate = Value(scheduledDate);
  static Insertable<ScheduledWorkoutTableData> custom({
    Expression<int>? id,
    Expression<int>? workoutId,
    Expression<int>? workoutPlanId,
    Expression<int>? templateWorkoutId,
    Expression<DateTime>? scheduledDate,
    Expression<DateTime>? createdAt,
    Expression<String>? notes,
    Expression<bool>? isCompleted,
    Expression<bool>? isSkipped,
    Expression<String>? serverId,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workoutId != null) 'workout_id': workoutId,
      if (workoutPlanId != null) 'workout_plan_id': workoutPlanId,
      if (templateWorkoutId != null) 'template_workout_id': templateWorkoutId,
      if (scheduledDate != null) 'scheduled_date': scheduledDate,
      if (createdAt != null) 'created_at': createdAt,
      if (notes != null) 'notes': notes,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (isSkipped != null) 'is_skipped': isSkipped,
      if (serverId != null) 'server_id': serverId,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  ScheduledWorkoutTableCompanion copyWith({
    Value<int>? id,
    Value<int>? workoutId,
    Value<int?>? workoutPlanId,
    Value<int?>? templateWorkoutId,
    Value<DateTime>? scheduledDate,
    Value<DateTime>? createdAt,
    Value<String?>? notes,
    Value<bool>? isCompleted,
    Value<bool>? isSkipped,
    Value<String?>? serverId,
    Value<int>? syncStatus,
  }) {
    return ScheduledWorkoutTableCompanion(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      workoutPlanId: workoutPlanId ?? this.workoutPlanId,
      templateWorkoutId: templateWorkoutId ?? this.templateWorkoutId,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      createdAt: createdAt ?? this.createdAt,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      isSkipped: isSkipped ?? this.isSkipped,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (workoutId.present) {
      map['workout_id'] = Variable<int>(workoutId.value);
    }
    if (workoutPlanId.present) {
      map['workout_plan_id'] = Variable<int>(workoutPlanId.value);
    }
    if (templateWorkoutId.present) {
      map['template_workout_id'] = Variable<int>(templateWorkoutId.value);
    }
    if (scheduledDate.present) {
      map['scheduled_date'] = Variable<DateTime>(scheduledDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (isSkipped.present) {
      map['is_skipped'] = Variable<bool>(isSkipped.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledWorkoutTableCompanion(')
          ..write('id: $id, ')
          ..write('workoutId: $workoutId, ')
          ..write('workoutPlanId: $workoutPlanId, ')
          ..write('templateWorkoutId: $templateWorkoutId, ')
          ..write('scheduledDate: $scheduledDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('notes: $notes, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('isSkipped: $isSkipped, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $ScheduledWorkoutExerciseTableTable extends ScheduledWorkoutExerciseTable
    with
        TableInfo<
          $ScheduledWorkoutExerciseTableTable,
          ScheduledWorkoutExerciseTableData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScheduledWorkoutExerciseTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _scheduledWorkoutIdMeta =
      const VerificationMeta('scheduledWorkoutId');
  @override
  late final GeneratedColumn<int> scheduledWorkoutId = GeneratedColumn<int>(
    'scheduled_workout_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES scheduled_workout_table (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _workoutExerciseIdMeta = const VerificationMeta(
    'workoutExerciseId',
  );
  @override
  late final GeneratedColumn<int> workoutExerciseId = GeneratedColumn<int>(
    'workout_exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_exercise_table (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _overrideExerciseIdMeta =
      const VerificationMeta('overrideExerciseId');
  @override
  late final GeneratedColumn<int> overrideExerciseId = GeneratedColumn<int>(
    'override_exercise_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scheduledWorkoutId,
    workoutExerciseId,
    isCompleted,
    notes,
    overrideExerciseId,
    serverId,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scheduled_workout_exercise_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScheduledWorkoutExerciseTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scheduled_workout_id')) {
      context.handle(
        _scheduledWorkoutIdMeta,
        scheduledWorkoutId.isAcceptableOrUnknown(
          data['scheduled_workout_id']!,
          _scheduledWorkoutIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledWorkoutIdMeta);
    }
    if (data.containsKey('workout_exercise_id')) {
      context.handle(
        _workoutExerciseIdMeta,
        workoutExerciseId.isAcceptableOrUnknown(
          data['workout_exercise_id']!,
          _workoutExerciseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workoutExerciseIdMeta);
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('override_exercise_id')) {
      context.handle(
        _overrideExerciseIdMeta,
        overrideExerciseId.isAcceptableOrUnknown(
          data['override_exercise_id']!,
          _overrideExerciseIdMeta,
        ),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScheduledWorkoutExerciseTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScheduledWorkoutExerciseTableData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      scheduledWorkoutId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}scheduled_workout_id'],
          )!,
      workoutExerciseId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}workout_exercise_id'],
          )!,
      isCompleted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_completed'],
          )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      overrideExerciseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}override_exercise_id'],
      ),
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      syncStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sync_status'],
          )!,
    );
  }

  @override
  $ScheduledWorkoutExerciseTableTable createAlias(String alias) {
    return $ScheduledWorkoutExerciseTableTable(attachedDatabase, alias);
  }
}

class ScheduledWorkoutExerciseTableData extends DataClass
    implements Insertable<ScheduledWorkoutExerciseTableData> {
  final int id;

  /// The scheduled workout (this is the date!)
  final int scheduledWorkoutId;
  final int workoutExerciseId;
  final bool isCompleted;
  final String? notes;

  /// Exercise override for this specific day only. Null = use the template exercise.
  final int? overrideExerciseId;
  final String? serverId;
  final int syncStatus;
  const ScheduledWorkoutExerciseTableData({
    required this.id,
    required this.scheduledWorkoutId,
    required this.workoutExerciseId,
    required this.isCompleted,
    this.notes,
    this.overrideExerciseId,
    this.serverId,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scheduled_workout_id'] = Variable<int>(scheduledWorkoutId);
    map['workout_exercise_id'] = Variable<int>(workoutExerciseId);
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || overrideExerciseId != null) {
      map['override_exercise_id'] = Variable<int>(overrideExerciseId);
    }
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  ScheduledWorkoutExerciseTableCompanion toCompanion(bool nullToAbsent) {
    return ScheduledWorkoutExerciseTableCompanion(
      id: Value(id),
      scheduledWorkoutId: Value(scheduledWorkoutId),
      workoutExerciseId: Value(workoutExerciseId),
      isCompleted: Value(isCompleted),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      overrideExerciseId:
          overrideExerciseId == null && nullToAbsent
              ? const Value.absent()
              : Value(overrideExerciseId),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
      syncStatus: Value(syncStatus),
    );
  }

  factory ScheduledWorkoutExerciseTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScheduledWorkoutExerciseTableData(
      id: serializer.fromJson<int>(json['id']),
      scheduledWorkoutId: serializer.fromJson<int>(json['scheduledWorkoutId']),
      workoutExerciseId: serializer.fromJson<int>(json['workoutExerciseId']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      notes: serializer.fromJson<String?>(json['notes']),
      overrideExerciseId: serializer.fromJson<int?>(json['overrideExerciseId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scheduledWorkoutId': serializer.toJson<int>(scheduledWorkoutId),
      'workoutExerciseId': serializer.toJson<int>(workoutExerciseId),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'notes': serializer.toJson<String?>(notes),
      'overrideExerciseId': serializer.toJson<int?>(overrideExerciseId),
      'serverId': serializer.toJson<String?>(serverId),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  ScheduledWorkoutExerciseTableData copyWith({
    int? id,
    int? scheduledWorkoutId,
    int? workoutExerciseId,
    bool? isCompleted,
    Value<String?> notes = const Value.absent(),
    Value<int?> overrideExerciseId = const Value.absent(),
    Value<String?> serverId = const Value.absent(),
    int? syncStatus,
  }) => ScheduledWorkoutExerciseTableData(
    id: id ?? this.id,
    scheduledWorkoutId: scheduledWorkoutId ?? this.scheduledWorkoutId,
    workoutExerciseId: workoutExerciseId ?? this.workoutExerciseId,
    isCompleted: isCompleted ?? this.isCompleted,
    notes: notes.present ? notes.value : this.notes,
    overrideExerciseId:
        overrideExerciseId.present
            ? overrideExerciseId.value
            : this.overrideExerciseId,
    serverId: serverId.present ? serverId.value : this.serverId,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  ScheduledWorkoutExerciseTableData copyWithCompanion(
    ScheduledWorkoutExerciseTableCompanion data,
  ) {
    return ScheduledWorkoutExerciseTableData(
      id: data.id.present ? data.id.value : this.id,
      scheduledWorkoutId:
          data.scheduledWorkoutId.present
              ? data.scheduledWorkoutId.value
              : this.scheduledWorkoutId,
      workoutExerciseId:
          data.workoutExerciseId.present
              ? data.workoutExerciseId.value
              : this.workoutExerciseId,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      notes: data.notes.present ? data.notes.value : this.notes,
      overrideExerciseId:
          data.overrideExerciseId.present
              ? data.overrideExerciseId.value
              : this.overrideExerciseId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledWorkoutExerciseTableData(')
          ..write('id: $id, ')
          ..write('scheduledWorkoutId: $scheduledWorkoutId, ')
          ..write('workoutExerciseId: $workoutExerciseId, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('notes: $notes, ')
          ..write('overrideExerciseId: $overrideExerciseId, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scheduledWorkoutId,
    workoutExerciseId,
    isCompleted,
    notes,
    overrideExerciseId,
    serverId,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScheduledWorkoutExerciseTableData &&
          other.id == this.id &&
          other.scheduledWorkoutId == this.scheduledWorkoutId &&
          other.workoutExerciseId == this.workoutExerciseId &&
          other.isCompleted == this.isCompleted &&
          other.notes == this.notes &&
          other.overrideExerciseId == this.overrideExerciseId &&
          other.serverId == this.serverId &&
          other.syncStatus == this.syncStatus);
}

class ScheduledWorkoutExerciseTableCompanion
    extends UpdateCompanion<ScheduledWorkoutExerciseTableData> {
  final Value<int> id;
  final Value<int> scheduledWorkoutId;
  final Value<int> workoutExerciseId;
  final Value<bool> isCompleted;
  final Value<String?> notes;
  final Value<int?> overrideExerciseId;
  final Value<String?> serverId;
  final Value<int> syncStatus;
  const ScheduledWorkoutExerciseTableCompanion({
    this.id = const Value.absent(),
    this.scheduledWorkoutId = const Value.absent(),
    this.workoutExerciseId = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.notes = const Value.absent(),
    this.overrideExerciseId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  ScheduledWorkoutExerciseTableCompanion.insert({
    this.id = const Value.absent(),
    required int scheduledWorkoutId,
    required int workoutExerciseId,
    this.isCompleted = const Value.absent(),
    this.notes = const Value.absent(),
    this.overrideExerciseId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : scheduledWorkoutId = Value(scheduledWorkoutId),
       workoutExerciseId = Value(workoutExerciseId);
  static Insertable<ScheduledWorkoutExerciseTableData> custom({
    Expression<int>? id,
    Expression<int>? scheduledWorkoutId,
    Expression<int>? workoutExerciseId,
    Expression<bool>? isCompleted,
    Expression<String>? notes,
    Expression<int>? overrideExerciseId,
    Expression<String>? serverId,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scheduledWorkoutId != null)
        'scheduled_workout_id': scheduledWorkoutId,
      if (workoutExerciseId != null) 'workout_exercise_id': workoutExerciseId,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (notes != null) 'notes': notes,
      if (overrideExerciseId != null)
        'override_exercise_id': overrideExerciseId,
      if (serverId != null) 'server_id': serverId,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  ScheduledWorkoutExerciseTableCompanion copyWith({
    Value<int>? id,
    Value<int>? scheduledWorkoutId,
    Value<int>? workoutExerciseId,
    Value<bool>? isCompleted,
    Value<String?>? notes,
    Value<int?>? overrideExerciseId,
    Value<String?>? serverId,
    Value<int>? syncStatus,
  }) {
    return ScheduledWorkoutExerciseTableCompanion(
      id: id ?? this.id,
      scheduledWorkoutId: scheduledWorkoutId ?? this.scheduledWorkoutId,
      workoutExerciseId: workoutExerciseId ?? this.workoutExerciseId,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      overrideExerciseId: overrideExerciseId ?? this.overrideExerciseId,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scheduledWorkoutId.present) {
      map['scheduled_workout_id'] = Variable<int>(scheduledWorkoutId.value);
    }
    if (workoutExerciseId.present) {
      map['workout_exercise_id'] = Variable<int>(workoutExerciseId.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (overrideExerciseId.present) {
      map['override_exercise_id'] = Variable<int>(overrideExerciseId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScheduledWorkoutExerciseTableCompanion(')
          ..write('id: $id, ')
          ..write('scheduledWorkoutId: $scheduledWorkoutId, ')
          ..write('workoutExerciseId: $workoutExerciseId, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('notes: $notes, ')
          ..write('overrideExerciseId: $overrideExerciseId, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSetTableTable extends WorkoutSetTable
    with TableInfo<$WorkoutSetTableTable, WorkoutSetTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSetTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _scheduledWorkoutExerciseIdMeta =
      const VerificationMeta('scheduledWorkoutExerciseId');
  @override
  late final GeneratedColumn<int> scheduledWorkoutExerciseId =
      GeneratedColumn<int>(
        'scheduled_workout_exercise_id',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES scheduled_workout_exercise_table (id) ON DELETE CASCADE',
        ),
      );
  static const VerificationMeta _setNumberMeta = const VerificationMeta(
    'setNumber',
  );
  @override
  late final GeneratedColumn<int> setNumber = GeneratedColumn<int>(
    'set_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _repsMeta = const VerificationMeta('reps');
  @override
  late final GeneratedColumn<int> reps = GeneratedColumn<int>(
    'reps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightUnitMeta = const VerificationMeta(
    'weightUnit',
  );
  @override
  late final GeneratedColumn<String> weightUnit = GeneratedColumn<String>(
    'weight_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rpeMeta = const VerificationMeta('rpe');
  @override
  late final GeneratedColumn<int> rpe = GeneratedColumn<int>(
    'rpe',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _setTypeMeta = const VerificationMeta(
    'setType',
  );
  @override
  late final GeneratedColumn<int> setType = GeneratedColumn<int>(
    'set_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sideMeta = const VerificationMeta('side');
  @override
  late final GeneratedColumn<int> side = GeneratedColumn<int>(
    'side',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    scheduledWorkoutExerciseId,
    setNumber,
    reps,
    weight,
    weightUnit,
    durationSeconds,
    isCompleted,
    notes,
    serverId,
    syncStatus,
    rpe,
    setType,
    side,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_set_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSetTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('scheduled_workout_exercise_id')) {
      context.handle(
        _scheduledWorkoutExerciseIdMeta,
        scheduledWorkoutExerciseId.isAcceptableOrUnknown(
          data['scheduled_workout_exercise_id']!,
          _scheduledWorkoutExerciseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledWorkoutExerciseIdMeta);
    }
    if (data.containsKey('set_number')) {
      context.handle(
        _setNumberMeta,
        setNumber.isAcceptableOrUnknown(data['set_number']!, _setNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_setNumberMeta);
    }
    if (data.containsKey('reps')) {
      context.handle(
        _repsMeta,
        reps.isAcceptableOrUnknown(data['reps']!, _repsMeta),
      );
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('weight_unit')) {
      context.handle(
        _weightUnitMeta,
        weightUnit.isAcceptableOrUnknown(data['weight_unit']!, _weightUnitMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('rpe')) {
      context.handle(
        _rpeMeta,
        rpe.isAcceptableOrUnknown(data['rpe']!, _rpeMeta),
      );
    }
    if (data.containsKey('set_type')) {
      context.handle(
        _setTypeMeta,
        setType.isAcceptableOrUnknown(data['set_type']!, _setTypeMeta),
      );
    }
    if (data.containsKey('side')) {
      context.handle(
        _sideMeta,
        side.isAcceptableOrUnknown(data['side']!, _sideMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSetTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSetTableData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      scheduledWorkoutExerciseId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}scheduled_workout_exercise_id'],
          )!,
      setNumber:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}set_number'],
          )!,
      reps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reps'],
      ),
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      ),
      weightUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}weight_unit'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      isCompleted:
          attachedDatabase.typeMapping.read(
            DriftSqlType.bool,
            data['${effectivePrefix}is_completed'],
          )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      syncStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sync_status'],
          )!,
      rpe: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rpe'],
      ),
      setType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}set_type'],
          )!,
      side:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}side'],
          )!,
    );
  }

  @override
  $WorkoutSetTableTable createAlias(String alias) {
    return $WorkoutSetTableTable(attachedDatabase, alias);
  }
}

class WorkoutSetTableData extends DataClass
    implements Insertable<WorkoutSetTableData> {
  final int id;
  final int scheduledWorkoutExerciseId;
  final int setNumber;
  final int? reps;
  final double? weight;
  final String? weightUnit;
  final int? durationSeconds;
  final bool isCompleted;
  final String? notes;
  final String? serverId;
  final int syncStatus;

  /// Rate of Perceived Exertion (6-10). Null when the user didn't log one.
  final int? rpe;

  /// Maps to [SetType] by index. Warmups are excluded from volume/PR stats.
  final int setType;

  /// Maps to [SetSide] by index. Left/right for unilateral tracking.
  final int side;
  const WorkoutSetTableData({
    required this.id,
    required this.scheduledWorkoutExerciseId,
    required this.setNumber,
    this.reps,
    this.weight,
    this.weightUnit,
    this.durationSeconds,
    required this.isCompleted,
    this.notes,
    this.serverId,
    required this.syncStatus,
    this.rpe,
    required this.setType,
    required this.side,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['scheduled_workout_exercise_id'] = Variable<int>(
      scheduledWorkoutExerciseId,
    );
    map['set_number'] = Variable<int>(setNumber);
    if (!nullToAbsent || reps != null) {
      map['reps'] = Variable<int>(reps);
    }
    if (!nullToAbsent || weight != null) {
      map['weight'] = Variable<double>(weight);
    }
    if (!nullToAbsent || weightUnit != null) {
      map['weight_unit'] = Variable<String>(weightUnit);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    if (!nullToAbsent || rpe != null) {
      map['rpe'] = Variable<int>(rpe);
    }
    map['set_type'] = Variable<int>(setType);
    map['side'] = Variable<int>(side);
    return map;
  }

  WorkoutSetTableCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetTableCompanion(
      id: Value(id),
      scheduledWorkoutExerciseId: Value(scheduledWorkoutExerciseId),
      setNumber: Value(setNumber),
      reps: reps == null && nullToAbsent ? const Value.absent() : Value(reps),
      weight:
          weight == null && nullToAbsent ? const Value.absent() : Value(weight),
      weightUnit:
          weightUnit == null && nullToAbsent
              ? const Value.absent()
              : Value(weightUnit),
      durationSeconds:
          durationSeconds == null && nullToAbsent
              ? const Value.absent()
              : Value(durationSeconds),
      isCompleted: Value(isCompleted),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
      syncStatus: Value(syncStatus),
      rpe: rpe == null && nullToAbsent ? const Value.absent() : Value(rpe),
      setType: Value(setType),
      side: Value(side),
    );
  }

  factory WorkoutSetTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSetTableData(
      id: serializer.fromJson<int>(json['id']),
      scheduledWorkoutExerciseId: serializer.fromJson<int>(
        json['scheduledWorkoutExerciseId'],
      ),
      setNumber: serializer.fromJson<int>(json['setNumber']),
      reps: serializer.fromJson<int?>(json['reps']),
      weight: serializer.fromJson<double?>(json['weight']),
      weightUnit: serializer.fromJson<String?>(json['weightUnit']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      notes: serializer.fromJson<String?>(json['notes']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
      rpe: serializer.fromJson<int?>(json['rpe']),
      setType: serializer.fromJson<int>(json['setType']),
      side: serializer.fromJson<int>(json['side']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'scheduledWorkoutExerciseId': serializer.toJson<int>(
        scheduledWorkoutExerciseId,
      ),
      'setNumber': serializer.toJson<int>(setNumber),
      'reps': serializer.toJson<int?>(reps),
      'weight': serializer.toJson<double?>(weight),
      'weightUnit': serializer.toJson<String?>(weightUnit),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'notes': serializer.toJson<String?>(notes),
      'serverId': serializer.toJson<String?>(serverId),
      'syncStatus': serializer.toJson<int>(syncStatus),
      'rpe': serializer.toJson<int?>(rpe),
      'setType': serializer.toJson<int>(setType),
      'side': serializer.toJson<int>(side),
    };
  }

  WorkoutSetTableData copyWith({
    int? id,
    int? scheduledWorkoutExerciseId,
    int? setNumber,
    Value<int?> reps = const Value.absent(),
    Value<double?> weight = const Value.absent(),
    Value<String?> weightUnit = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    bool? isCompleted,
    Value<String?> notes = const Value.absent(),
    Value<String?> serverId = const Value.absent(),
    int? syncStatus,
    Value<int?> rpe = const Value.absent(),
    int? setType,
    int? side,
  }) => WorkoutSetTableData(
    id: id ?? this.id,
    scheduledWorkoutExerciseId:
        scheduledWorkoutExerciseId ?? this.scheduledWorkoutExerciseId,
    setNumber: setNumber ?? this.setNumber,
    reps: reps.present ? reps.value : this.reps,
    weight: weight.present ? weight.value : this.weight,
    weightUnit: weightUnit.present ? weightUnit.value : this.weightUnit,
    durationSeconds:
        durationSeconds.present ? durationSeconds.value : this.durationSeconds,
    isCompleted: isCompleted ?? this.isCompleted,
    notes: notes.present ? notes.value : this.notes,
    serverId: serverId.present ? serverId.value : this.serverId,
    syncStatus: syncStatus ?? this.syncStatus,
    rpe: rpe.present ? rpe.value : this.rpe,
    setType: setType ?? this.setType,
    side: side ?? this.side,
  );
  WorkoutSetTableData copyWithCompanion(WorkoutSetTableCompanion data) {
    return WorkoutSetTableData(
      id: data.id.present ? data.id.value : this.id,
      scheduledWorkoutExerciseId:
          data.scheduledWorkoutExerciseId.present
              ? data.scheduledWorkoutExerciseId.value
              : this.scheduledWorkoutExerciseId,
      setNumber: data.setNumber.present ? data.setNumber.value : this.setNumber,
      reps: data.reps.present ? data.reps.value : this.reps,
      weight: data.weight.present ? data.weight.value : this.weight,
      weightUnit:
          data.weightUnit.present ? data.weightUnit.value : this.weightUnit,
      durationSeconds:
          data.durationSeconds.present
              ? data.durationSeconds.value
              : this.durationSeconds,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      notes: data.notes.present ? data.notes.value : this.notes,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
      rpe: data.rpe.present ? data.rpe.value : this.rpe,
      setType: data.setType.present ? data.setType.value : this.setType,
      side: data.side.present ? data.side.value : this.side,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetTableData(')
          ..write('id: $id, ')
          ..write('scheduledWorkoutExerciseId: $scheduledWorkoutExerciseId, ')
          ..write('setNumber: $setNumber, ')
          ..write('reps: $reps, ')
          ..write('weight: $weight, ')
          ..write('weightUnit: $weightUnit, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('notes: $notes, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rpe: $rpe, ')
          ..write('setType: $setType, ')
          ..write('side: $side')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    scheduledWorkoutExerciseId,
    setNumber,
    reps,
    weight,
    weightUnit,
    durationSeconds,
    isCompleted,
    notes,
    serverId,
    syncStatus,
    rpe,
    setType,
    side,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSetTableData &&
          other.id == this.id &&
          other.scheduledWorkoutExerciseId == this.scheduledWorkoutExerciseId &&
          other.setNumber == this.setNumber &&
          other.reps == this.reps &&
          other.weight == this.weight &&
          other.weightUnit == this.weightUnit &&
          other.durationSeconds == this.durationSeconds &&
          other.isCompleted == this.isCompleted &&
          other.notes == this.notes &&
          other.serverId == this.serverId &&
          other.syncStatus == this.syncStatus &&
          other.rpe == this.rpe &&
          other.setType == this.setType &&
          other.side == this.side);
}

class WorkoutSetTableCompanion extends UpdateCompanion<WorkoutSetTableData> {
  final Value<int> id;
  final Value<int> scheduledWorkoutExerciseId;
  final Value<int> setNumber;
  final Value<int?> reps;
  final Value<double?> weight;
  final Value<String?> weightUnit;
  final Value<int?> durationSeconds;
  final Value<bool> isCompleted;
  final Value<String?> notes;
  final Value<String?> serverId;
  final Value<int> syncStatus;
  final Value<int?> rpe;
  final Value<int> setType;
  final Value<int> side;
  const WorkoutSetTableCompanion({
    this.id = const Value.absent(),
    this.scheduledWorkoutExerciseId = const Value.absent(),
    this.setNumber = const Value.absent(),
    this.reps = const Value.absent(),
    this.weight = const Value.absent(),
    this.weightUnit = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.notes = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rpe = const Value.absent(),
    this.setType = const Value.absent(),
    this.side = const Value.absent(),
  });
  WorkoutSetTableCompanion.insert({
    this.id = const Value.absent(),
    required int scheduledWorkoutExerciseId,
    required int setNumber,
    this.reps = const Value.absent(),
    this.weight = const Value.absent(),
    this.weightUnit = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.notes = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rpe = const Value.absent(),
    this.setType = const Value.absent(),
    this.side = const Value.absent(),
  }) : scheduledWorkoutExerciseId = Value(scheduledWorkoutExerciseId),
       setNumber = Value(setNumber);
  static Insertable<WorkoutSetTableData> custom({
    Expression<int>? id,
    Expression<int>? scheduledWorkoutExerciseId,
    Expression<int>? setNumber,
    Expression<int>? reps,
    Expression<double>? weight,
    Expression<String>? weightUnit,
    Expression<int>? durationSeconds,
    Expression<bool>? isCompleted,
    Expression<String>? notes,
    Expression<String>? serverId,
    Expression<int>? syncStatus,
    Expression<int>? rpe,
    Expression<int>? setType,
    Expression<int>? side,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scheduledWorkoutExerciseId != null)
        'scheduled_workout_exercise_id': scheduledWorkoutExerciseId,
      if (setNumber != null) 'set_number': setNumber,
      if (reps != null) 'reps': reps,
      if (weight != null) 'weight': weight,
      if (weightUnit != null) 'weight_unit': weightUnit,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (notes != null) 'notes': notes,
      if (serverId != null) 'server_id': serverId,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rpe != null) 'rpe': rpe,
      if (setType != null) 'set_type': setType,
      if (side != null) 'side': side,
    });
  }

  WorkoutSetTableCompanion copyWith({
    Value<int>? id,
    Value<int>? scheduledWorkoutExerciseId,
    Value<int>? setNumber,
    Value<int?>? reps,
    Value<double?>? weight,
    Value<String?>? weightUnit,
    Value<int?>? durationSeconds,
    Value<bool>? isCompleted,
    Value<String?>? notes,
    Value<String?>? serverId,
    Value<int>? syncStatus,
    Value<int?>? rpe,
    Value<int>? setType,
    Value<int>? side,
  }) {
    return WorkoutSetTableCompanion(
      id: id ?? this.id,
      scheduledWorkoutExerciseId:
          scheduledWorkoutExerciseId ?? this.scheduledWorkoutExerciseId,
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      weightUnit: weightUnit ?? this.weightUnit,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      rpe: rpe ?? this.rpe,
      setType: setType ?? this.setType,
      side: side ?? this.side,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (scheduledWorkoutExerciseId.present) {
      map['scheduled_workout_exercise_id'] = Variable<int>(
        scheduledWorkoutExerciseId.value,
      );
    }
    if (setNumber.present) {
      map['set_number'] = Variable<int>(setNumber.value);
    }
    if (reps.present) {
      map['reps'] = Variable<int>(reps.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (weightUnit.present) {
      map['weight_unit'] = Variable<String>(weightUnit.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    if (rpe.present) {
      map['rpe'] = Variable<int>(rpe.value);
    }
    if (setType.present) {
      map['set_type'] = Variable<int>(setType.value);
    }
    if (side.present) {
      map['side'] = Variable<int>(side.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetTableCompanion(')
          ..write('id: $id, ')
          ..write('scheduledWorkoutExerciseId: $scheduledWorkoutExerciseId, ')
          ..write('setNumber: $setNumber, ')
          ..write('reps: $reps, ')
          ..write('weight: $weight, ')
          ..write('weightUnit: $weightUnit, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('notes: $notes, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rpe: $rpe, ')
          ..write('setType: $setType, ')
          ..write('side: $side')
          ..write(')'))
        .toString();
  }
}

class $WorkoutPlanWorkoutTableTable extends WorkoutPlanWorkoutTable
    with TableInfo<$WorkoutPlanWorkoutTableTable, WorkoutPlanWorkoutTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutPlanWorkoutTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<int> planId = GeneratedColumn<int>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_plan_table (id)',
    ),
  );
  static const VerificationMeta _workoutIdMeta = const VerificationMeta(
    'workoutId',
  );
  @override
  late final GeneratedColumn<int> workoutId = GeneratedColumn<int>(
    'workout_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_table (id)',
    ),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    workoutId,
    serverId,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_plan_workout_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutPlanWorkoutTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('workout_id')) {
      context.handle(
        _workoutIdMeta,
        workoutId.isAcceptableOrUnknown(data['workout_id']!, _workoutIdMeta),
      );
    } else if (isInserting) {
      context.missing(_workoutIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutPlanWorkoutTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutPlanWorkoutTableData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      planId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}plan_id'],
          )!,
      workoutId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}workout_id'],
          )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      syncStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sync_status'],
          )!,
    );
  }

  @override
  $WorkoutPlanWorkoutTableTable createAlias(String alias) {
    return $WorkoutPlanWorkoutTableTable(attachedDatabase, alias);
  }
}

class WorkoutPlanWorkoutTableData extends DataClass
    implements Insertable<WorkoutPlanWorkoutTableData> {
  final int id;
  final int planId;
  final int workoutId;
  final String? serverId;
  final int syncStatus;
  const WorkoutPlanWorkoutTableData({
    required this.id,
    required this.planId,
    required this.workoutId,
    this.serverId,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['plan_id'] = Variable<int>(planId);
    map['workout_id'] = Variable<int>(workoutId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  WorkoutPlanWorkoutTableCompanion toCompanion(bool nullToAbsent) {
    return WorkoutPlanWorkoutTableCompanion(
      id: Value(id),
      planId: Value(planId),
      workoutId: Value(workoutId),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
      syncStatus: Value(syncStatus),
    );
  }

  factory WorkoutPlanWorkoutTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutPlanWorkoutTableData(
      id: serializer.fromJson<int>(json['id']),
      planId: serializer.fromJson<int>(json['planId']),
      workoutId: serializer.fromJson<int>(json['workoutId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'planId': serializer.toJson<int>(planId),
      'workoutId': serializer.toJson<int>(workoutId),
      'serverId': serializer.toJson<String?>(serverId),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  WorkoutPlanWorkoutTableData copyWith({
    int? id,
    int? planId,
    int? workoutId,
    Value<String?> serverId = const Value.absent(),
    int? syncStatus,
  }) => WorkoutPlanWorkoutTableData(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    workoutId: workoutId ?? this.workoutId,
    serverId: serverId.present ? serverId.value : this.serverId,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  WorkoutPlanWorkoutTableData copyWithCompanion(
    WorkoutPlanWorkoutTableCompanion data,
  ) {
    return WorkoutPlanWorkoutTableData(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      workoutId: data.workoutId.present ? data.workoutId.value : this.workoutId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutPlanWorkoutTableData(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('workoutId: $workoutId, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, planId, workoutId, serverId, syncStatus);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutPlanWorkoutTableData &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.workoutId == this.workoutId &&
          other.serverId == this.serverId &&
          other.syncStatus == this.syncStatus);
}

class WorkoutPlanWorkoutTableCompanion
    extends UpdateCompanion<WorkoutPlanWorkoutTableData> {
  final Value<int> id;
  final Value<int> planId;
  final Value<int> workoutId;
  final Value<String?> serverId;
  final Value<int> syncStatus;
  const WorkoutPlanWorkoutTableCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  WorkoutPlanWorkoutTableCompanion.insert({
    this.id = const Value.absent(),
    required int planId,
    required int workoutId,
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : planId = Value(planId),
       workoutId = Value(workoutId);
  static Insertable<WorkoutPlanWorkoutTableData> custom({
    Expression<int>? id,
    Expression<int>? planId,
    Expression<int>? workoutId,
    Expression<String>? serverId,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (workoutId != null) 'workout_id': workoutId,
      if (serverId != null) 'server_id': serverId,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  WorkoutPlanWorkoutTableCompanion copyWith({
    Value<int>? id,
    Value<int>? planId,
    Value<int>? workoutId,
    Value<String?>? serverId,
    Value<int>? syncStatus,
  }) {
    return WorkoutPlanWorkoutTableCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      workoutId: workoutId ?? this.workoutId,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<int>(planId.value);
    }
    if (workoutId.present) {
      map['workout_id'] = Variable<int>(workoutId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutPlanWorkoutTableCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('workoutId: $workoutId, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $WorkoutSetTemplateTableTable extends WorkoutSetTemplateTable
    with TableInfo<$WorkoutSetTemplateTableTable, WorkoutSetTemplateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutSetTemplateTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _workoutExerciseIdMeta = const VerificationMeta(
    'workoutExerciseId',
  );
  @override
  late final GeneratedColumn<int> workoutExerciseId = GeneratedColumn<int>(
    'workout_exercise_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES workout_exercise_table (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _setNumberMeta = const VerificationMeta(
    'setNumber',
  );
  @override
  late final GeneratedColumn<int> setNumber = GeneratedColumn<int>(
    'set_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetRepsMeta = const VerificationMeta(
    'targetReps',
  );
  @override
  late final GeneratedColumn<String> targetReps = GeneratedColumn<String>(
    'target_reps',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderPositionMeta = const VerificationMeta(
    'orderPosition',
  );
  @override
  late final GeneratedColumn<int> orderPosition = GeneratedColumn<int>(
    'order_position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<int> syncStatus = GeneratedColumn<int>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workoutExerciseId,
    setNumber,
    targetReps,
    orderPosition,
    serverId,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_set_template_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutSetTemplateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('workout_exercise_id')) {
      context.handle(
        _workoutExerciseIdMeta,
        workoutExerciseId.isAcceptableOrUnknown(
          data['workout_exercise_id']!,
          _workoutExerciseIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_workoutExerciseIdMeta);
    }
    if (data.containsKey('set_number')) {
      context.handle(
        _setNumberMeta,
        setNumber.isAcceptableOrUnknown(data['set_number']!, _setNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_setNumberMeta);
    }
    if (data.containsKey('target_reps')) {
      context.handle(
        _targetRepsMeta,
        targetReps.isAcceptableOrUnknown(data['target_reps']!, _targetRepsMeta),
      );
    } else if (isInserting) {
      context.missing(_targetRepsMeta);
    }
    if (data.containsKey('order_position')) {
      context.handle(
        _orderPositionMeta,
        orderPosition.isAcceptableOrUnknown(
          data['order_position']!,
          _orderPositionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_orderPositionMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WorkoutSetTemplateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutSetTemplateData(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      workoutExerciseId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}workout_exercise_id'],
          )!,
      setNumber:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}set_number'],
          )!,
      targetReps:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}target_reps'],
          )!,
      orderPosition:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}order_position'],
          )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      syncStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}sync_status'],
          )!,
    );
  }

  @override
  $WorkoutSetTemplateTableTable createAlias(String alias) {
    return $WorkoutSetTemplateTableTable(attachedDatabase, alias);
  }
}

class WorkoutSetTemplateData extends DataClass
    implements Insertable<WorkoutSetTemplateData> {
  final int id;
  final int workoutExerciseId;
  final int setNumber;
  final String targetReps;
  final int orderPosition;
  final String? serverId;
  final int syncStatus;
  const WorkoutSetTemplateData({
    required this.id,
    required this.workoutExerciseId,
    required this.setNumber,
    required this.targetReps,
    required this.orderPosition,
    this.serverId,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['workout_exercise_id'] = Variable<int>(workoutExerciseId);
    map['set_number'] = Variable<int>(setNumber);
    map['target_reps'] = Variable<String>(targetReps);
    map['order_position'] = Variable<int>(orderPosition);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['sync_status'] = Variable<int>(syncStatus);
    return map;
  }

  WorkoutSetTemplateTableCompanion toCompanion(bool nullToAbsent) {
    return WorkoutSetTemplateTableCompanion(
      id: Value(id),
      workoutExerciseId: Value(workoutExerciseId),
      setNumber: Value(setNumber),
      targetReps: Value(targetReps),
      orderPosition: Value(orderPosition),
      serverId:
          serverId == null && nullToAbsent
              ? const Value.absent()
              : Value(serverId),
      syncStatus: Value(syncStatus),
    );
  }

  factory WorkoutSetTemplateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutSetTemplateData(
      id: serializer.fromJson<int>(json['id']),
      workoutExerciseId: serializer.fromJson<int>(json['workoutExerciseId']),
      setNumber: serializer.fromJson<int>(json['setNumber']),
      targetReps: serializer.fromJson<String>(json['targetReps']),
      orderPosition: serializer.fromJson<int>(json['orderPosition']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      syncStatus: serializer.fromJson<int>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'workoutExerciseId': serializer.toJson<int>(workoutExerciseId),
      'setNumber': serializer.toJson<int>(setNumber),
      'targetReps': serializer.toJson<String>(targetReps),
      'orderPosition': serializer.toJson<int>(orderPosition),
      'serverId': serializer.toJson<String?>(serverId),
      'syncStatus': serializer.toJson<int>(syncStatus),
    };
  }

  WorkoutSetTemplateData copyWith({
    int? id,
    int? workoutExerciseId,
    int? setNumber,
    String? targetReps,
    int? orderPosition,
    Value<String?> serverId = const Value.absent(),
    int? syncStatus,
  }) => WorkoutSetTemplateData(
    id: id ?? this.id,
    workoutExerciseId: workoutExerciseId ?? this.workoutExerciseId,
    setNumber: setNumber ?? this.setNumber,
    targetReps: targetReps ?? this.targetReps,
    orderPosition: orderPosition ?? this.orderPosition,
    serverId: serverId.present ? serverId.value : this.serverId,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  WorkoutSetTemplateData copyWithCompanion(
    WorkoutSetTemplateTableCompanion data,
  ) {
    return WorkoutSetTemplateData(
      id: data.id.present ? data.id.value : this.id,
      workoutExerciseId:
          data.workoutExerciseId.present
              ? data.workoutExerciseId.value
              : this.workoutExerciseId,
      setNumber: data.setNumber.present ? data.setNumber.value : this.setNumber,
      targetReps:
          data.targetReps.present ? data.targetReps.value : this.targetReps,
      orderPosition:
          data.orderPosition.present
              ? data.orderPosition.value
              : this.orderPosition,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetTemplateData(')
          ..write('id: $id, ')
          ..write('workoutExerciseId: $workoutExerciseId, ')
          ..write('setNumber: $setNumber, ')
          ..write('targetReps: $targetReps, ')
          ..write('orderPosition: $orderPosition, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workoutExerciseId,
    setNumber,
    targetReps,
    orderPosition,
    serverId,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutSetTemplateData &&
          other.id == this.id &&
          other.workoutExerciseId == this.workoutExerciseId &&
          other.setNumber == this.setNumber &&
          other.targetReps == this.targetReps &&
          other.orderPosition == this.orderPosition &&
          other.serverId == this.serverId &&
          other.syncStatus == this.syncStatus);
}

class WorkoutSetTemplateTableCompanion
    extends UpdateCompanion<WorkoutSetTemplateData> {
  final Value<int> id;
  final Value<int> workoutExerciseId;
  final Value<int> setNumber;
  final Value<String> targetReps;
  final Value<int> orderPosition;
  final Value<String?> serverId;
  final Value<int> syncStatus;
  const WorkoutSetTemplateTableCompanion({
    this.id = const Value.absent(),
    this.workoutExerciseId = const Value.absent(),
    this.setNumber = const Value.absent(),
    this.targetReps = const Value.absent(),
    this.orderPosition = const Value.absent(),
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  WorkoutSetTemplateTableCompanion.insert({
    this.id = const Value.absent(),
    required int workoutExerciseId,
    required int setNumber,
    required String targetReps,
    required int orderPosition,
    this.serverId = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : workoutExerciseId = Value(workoutExerciseId),
       setNumber = Value(setNumber),
       targetReps = Value(targetReps),
       orderPosition = Value(orderPosition);
  static Insertable<WorkoutSetTemplateData> custom({
    Expression<int>? id,
    Expression<int>? workoutExerciseId,
    Expression<int>? setNumber,
    Expression<String>? targetReps,
    Expression<int>? orderPosition,
    Expression<String>? serverId,
    Expression<int>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workoutExerciseId != null) 'workout_exercise_id': workoutExerciseId,
      if (setNumber != null) 'set_number': setNumber,
      if (targetReps != null) 'target_reps': targetReps,
      if (orderPosition != null) 'order_position': orderPosition,
      if (serverId != null) 'server_id': serverId,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  WorkoutSetTemplateTableCompanion copyWith({
    Value<int>? id,
    Value<int>? workoutExerciseId,
    Value<int>? setNumber,
    Value<String>? targetReps,
    Value<int>? orderPosition,
    Value<String?>? serverId,
    Value<int>? syncStatus,
  }) {
    return WorkoutSetTemplateTableCompanion(
      id: id ?? this.id,
      workoutExerciseId: workoutExerciseId ?? this.workoutExerciseId,
      setNumber: setNumber ?? this.setNumber,
      targetReps: targetReps ?? this.targetReps,
      orderPosition: orderPosition ?? this.orderPosition,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (workoutExerciseId.present) {
      map['workout_exercise_id'] = Variable<int>(workoutExerciseId.value);
    }
    if (setNumber.present) {
      map['set_number'] = Variable<int>(setNumber.value);
    }
    if (targetReps.present) {
      map['target_reps'] = Variable<String>(targetReps.value);
    }
    if (orderPosition.present) {
      map['order_position'] = Variable<int>(orderPosition.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<int>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutSetTemplateTableCompanion(')
          ..write('id: $id, ')
          ..write('workoutExerciseId: $workoutExerciseId, ')
          ..write('setNumber: $setNumber, ')
          ..write('targetReps: $targetReps, ')
          ..write('orderPosition: $orderPosition, ')
          ..write('serverId: $serverId, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $ChatOutBoxTableTable extends ChatOutBoxTable
    with TableInfo<$ChatOutBoxTableTable, ChatOutBoxTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatOutBoxTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _otherPartyIdMeta = const VerificationMeta(
    'otherPartyId',
  );
  @override
  late final GeneratedColumn<String> otherPartyId = GeneratedColumn<String>(
    'other_party_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chatMessageStatusMeta = const VerificationMeta(
    'chatMessageStatus',
  );
  @override
  late final GeneratedColumn<int> chatMessageStatus = GeneratedColumn<int>(
    'chat_message_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    messageId,
    otherPartyId,
    body,
    createdAt,
    chatMessageStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_out_box_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatOutBoxTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('other_party_id')) {
      context.handle(
        _otherPartyIdMeta,
        otherPartyId.isAcceptableOrUnknown(
          data['other_party_id']!,
          _otherPartyIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_otherPartyIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('chat_message_status')) {
      context.handle(
        _chatMessageStatusMeta,
        chatMessageStatus.isAcceptableOrUnknown(
          data['chat_message_status']!,
          _chatMessageStatusMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId};
  @override
  ChatOutBoxTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatOutBoxTableData(
      messageId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}message_id'],
          )!,
      otherPartyId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}other_party_id'],
          )!,
      body:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}body'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      chatMessageStatus:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}chat_message_status'],
          )!,
    );
  }

  @override
  $ChatOutBoxTableTable createAlias(String alias) {
    return $ChatOutBoxTableTable(attachedDatabase, alias);
  }
}

class ChatOutBoxTableData extends DataClass
    implements Insertable<ChatOutBoxTableData> {
  final String messageId;
  final String otherPartyId;
  final String body;
  final DateTime createdAt;

  /// Maps to [ChatMessageStatus] by index.
  final int chatMessageStatus;
  const ChatOutBoxTableData({
    required this.messageId,
    required this.otherPartyId,
    required this.body,
    required this.createdAt,
    required this.chatMessageStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['other_party_id'] = Variable<String>(otherPartyId);
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['chat_message_status'] = Variable<int>(chatMessageStatus);
    return map;
  }

  ChatOutBoxTableCompanion toCompanion(bool nullToAbsent) {
    return ChatOutBoxTableCompanion(
      messageId: Value(messageId),
      otherPartyId: Value(otherPartyId),
      body: Value(body),
      createdAt: Value(createdAt),
      chatMessageStatus: Value(chatMessageStatus),
    );
  }

  factory ChatOutBoxTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatOutBoxTableData(
      messageId: serializer.fromJson<String>(json['messageId']),
      otherPartyId: serializer.fromJson<String>(json['otherPartyId']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      chatMessageStatus: serializer.fromJson<int>(json['chatMessageStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'otherPartyId': serializer.toJson<String>(otherPartyId),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'chatMessageStatus': serializer.toJson<int>(chatMessageStatus),
    };
  }

  ChatOutBoxTableData copyWith({
    String? messageId,
    String? otherPartyId,
    String? body,
    DateTime? createdAt,
    int? chatMessageStatus,
  }) => ChatOutBoxTableData(
    messageId: messageId ?? this.messageId,
    otherPartyId: otherPartyId ?? this.otherPartyId,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
    chatMessageStatus: chatMessageStatus ?? this.chatMessageStatus,
  );
  ChatOutBoxTableData copyWithCompanion(ChatOutBoxTableCompanion data) {
    return ChatOutBoxTableData(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      otherPartyId:
          data.otherPartyId.present
              ? data.otherPartyId.value
              : this.otherPartyId,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      chatMessageStatus:
          data.chatMessageStatus.present
              ? data.chatMessageStatus.value
              : this.chatMessageStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatOutBoxTableData(')
          ..write('messageId: $messageId, ')
          ..write('otherPartyId: $otherPartyId, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('chatMessageStatus: $chatMessageStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(messageId, otherPartyId, body, createdAt, chatMessageStatus);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatOutBoxTableData &&
          other.messageId == this.messageId &&
          other.otherPartyId == this.otherPartyId &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.chatMessageStatus == this.chatMessageStatus);
}

class ChatOutBoxTableCompanion extends UpdateCompanion<ChatOutBoxTableData> {
  final Value<String> messageId;
  final Value<String> otherPartyId;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<int> chatMessageStatus;
  final Value<int> rowid;
  const ChatOutBoxTableCompanion({
    this.messageId = const Value.absent(),
    this.otherPartyId = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.chatMessageStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatOutBoxTableCompanion.insert({
    required String messageId,
    required String otherPartyId,
    required String body,
    required DateTime createdAt,
    this.chatMessageStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       otherPartyId = Value(otherPartyId),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<ChatOutBoxTableData> custom({
    Expression<String>? messageId,
    Expression<String>? otherPartyId,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<int>? chatMessageStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (otherPartyId != null) 'other_party_id': otherPartyId,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (chatMessageStatus != null) 'chat_message_status': chatMessageStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatOutBoxTableCompanion copyWith({
    Value<String>? messageId,
    Value<String>? otherPartyId,
    Value<String>? body,
    Value<DateTime>? createdAt,
    Value<int>? chatMessageStatus,
    Value<int>? rowid,
  }) {
    return ChatOutBoxTableCompanion(
      messageId: messageId ?? this.messageId,
      otherPartyId: otherPartyId ?? this.otherPartyId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      chatMessageStatus: chatMessageStatus ?? this.chatMessageStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (otherPartyId.present) {
      map['other_party_id'] = Variable<String>(otherPartyId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (chatMessageStatus.present) {
      map['chat_message_status'] = Variable<int>(chatMessageStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatOutBoxTableCompanion(')
          ..write('messageId: $messageId, ')
          ..write('otherPartyId: $otherPartyId, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('chatMessageStatus: $chatMessageStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoodItemTable foodItem = $FoodItemTable(this);
  late final $VerifiedFoodTableTable verifiedFoodTable =
      $VerifiedFoodTableTable(this);
  late final $UserSettingsTable userSettings = $UserSettingsTable(this);
  late final $MealTableTable mealTable = $MealTableTable(this);
  late final $MealFoodTableTable mealFoodTable = $MealFoodTableTable(this);
  late final $SearchCacheTableTable searchCacheTable = $SearchCacheTableTable(
    this,
  );
  late final $WeightRecordTable weightRecord = $WeightRecordTable(this);
  late final $ExerciseTableTable exerciseTable = $ExerciseTableTable(this);
  late final $WorkoutTableTable workoutTable = $WorkoutTableTable(this);
  late final $WorkoutPlanTableTable workoutPlanTable = $WorkoutPlanTableTable(
    this,
  );
  late final $WorkoutExerciseTableTable workoutExerciseTable =
      $WorkoutExerciseTableTable(this);
  late final $ScheduledWorkoutTableTable scheduledWorkoutTable =
      $ScheduledWorkoutTableTable(this);
  late final $ScheduledWorkoutExerciseTableTable scheduledWorkoutExerciseTable =
      $ScheduledWorkoutExerciseTableTable(this);
  late final $WorkoutSetTableTable workoutSetTable = $WorkoutSetTableTable(
    this,
  );
  late final $WorkoutPlanWorkoutTableTable workoutPlanWorkoutTable =
      $WorkoutPlanWorkoutTableTable(this);
  late final $WorkoutSetTemplateTableTable workoutSetTemplateTable =
      $WorkoutSetTemplateTableTable(this);
  late final $ChatOutBoxTableTable chatOutBoxTable = $ChatOutBoxTableTable(
    this,
  );
  late final FoodItemDao foodItemDao = FoodItemDao(this as AppDatabase);
  late final UserSettingsDao userSettingsDao = UserSettingsDao(
    this as AppDatabase,
  );
  late final MealDao mealDao = MealDao(this as AppDatabase);
  late final SearchCacheDao searchCacheDao = SearchCacheDao(
    this as AppDatabase,
  );
  late final WeightRecordDao weightRecordDao = WeightRecordDao(
    this as AppDatabase,
  );
  late final ExerciseDao exerciseDao = ExerciseDao(this as AppDatabase);
  late final WorkoutDao workoutDao = WorkoutDao(this as AppDatabase);
  late final WorkoutPlanDao workoutPlanDao = WorkoutPlanDao(
    this as AppDatabase,
  );
  late final ScheduledWorkoutDao scheduledWorkoutDao = ScheduledWorkoutDao(
    this as AppDatabase,
  );
  late final ScheduledWorkoutExerciseDao scheduledWorkoutExerciseDao =
      ScheduledWorkoutExerciseDao(this as AppDatabase);
  late final WorkoutSetTemplateTableDao workoutSetTemplateTableDao =
      WorkoutSetTemplateTableDao(this as AppDatabase);
  late final ChatoutboxDao chatoutboxDao = ChatoutboxDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    foodItem,
    verifiedFoodTable,
    userSettings,
    mealTable,
    mealFoodTable,
    searchCacheTable,
    weightRecord,
    exerciseTable,
    workoutTable,
    workoutPlanTable,
    workoutExerciseTable,
    scheduledWorkoutTable,
    scheduledWorkoutExerciseTable,
    workoutSetTable,
    workoutPlanWorkoutTable,
    workoutSetTemplateTable,
    chatOutBoxTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workout_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workout_exercise_table', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'exercise_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workout_exercise_table', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workout_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('scheduled_workout_table', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scheduled_workout_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate(
          'scheduled_workout_exercise_table',
          kind: UpdateKind.delete,
        ),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workout_exercise_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate(
          'scheduled_workout_exercise_table',
          kind: UpdateKind.delete,
        ),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'scheduled_workout_exercise_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('workout_set_table', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'workout_exercise_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('workout_set_template_table', kind: UpdateKind.delete),
      ],
    ),
  ]);
}

typedef $$FoodItemTableCreateCompanionBuilder =
    FoodItemCompanion Function({
      Value<int> id,
      required String name,
      required int calories,
      required int protein,
      required int carbs,
      required int fat,
      Value<int> gramm,
      Value<bool> hiddenFromRecent,
      Value<String?> extendedNutrientsJson,
      Value<int> syncStatus,
      Value<String?> serverId,
      Value<String?> openFoodFactsId,
    });
typedef $$FoodItemTableUpdateCompanionBuilder =
    FoodItemCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<int> calories,
      Value<int> protein,
      Value<int> carbs,
      Value<int> fat,
      Value<int> gramm,
      Value<bool> hiddenFromRecent,
      Value<String?> extendedNutrientsJson,
      Value<int> syncStatus,
      Value<String?> serverId,
      Value<String?> openFoodFactsId,
    });

final class $$FoodItemTableReferences
    extends BaseReferences<_$AppDatabase, $FoodItemTable, FoodItemData> {
  $$FoodItemTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MealFoodTableTable, List<MealFoodTableData>>
  _mealFoodTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealFoodTable,
    aliasName: $_aliasNameGenerator(
      db.foodItem.id,
      db.mealFoodTable.foodEntryId,
    ),
  );

  $$MealFoodTableTableProcessedTableManager get mealFoodTableRefs {
    final manager = $$MealFoodTableTableTableManager(
      $_db,
      $_db.mealFoodTable,
    ).filter((f) => f.foodEntryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mealFoodTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoodItemTableFilterComposer
    extends Composer<_$AppDatabase, $FoodItemTable> {
  $$FoodItemTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fat => $composableBuilder(
    column: $table.fat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gramm => $composableBuilder(
    column: $table.gramm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hiddenFromRecent => $composableBuilder(
    column: $table.hiddenFromRecent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extendedNutrientsJson => $composableBuilder(
    column: $table.extendedNutrientsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get openFoodFactsId => $composableBuilder(
    column: $table.openFoodFactsId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mealFoodTableRefs(
    Expression<bool> Function($$MealFoodTableTableFilterComposer f) f,
  ) {
    final $$MealFoodTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealFoodTable,
      getReferencedColumn: (t) => t.foodEntryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealFoodTableTableFilterComposer(
            $db: $db,
            $table: $db.mealFoodTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodItemTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodItemTable> {
  $$FoodItemTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fat => $composableBuilder(
    column: $table.fat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gramm => $composableBuilder(
    column: $table.gramm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hiddenFromRecent => $composableBuilder(
    column: $table.hiddenFromRecent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extendedNutrientsJson => $composableBuilder(
    column: $table.extendedNutrientsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get openFoodFactsId => $composableBuilder(
    column: $table.openFoodFactsId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoodItemTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodItemTable> {
  $$FoodItemTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<int> get protein =>
      $composableBuilder(column: $table.protein, builder: (column) => column);

  GeneratedColumn<int> get carbs =>
      $composableBuilder(column: $table.carbs, builder: (column) => column);

  GeneratedColumn<int> get fat =>
      $composableBuilder(column: $table.fat, builder: (column) => column);

  GeneratedColumn<int> get gramm =>
      $composableBuilder(column: $table.gramm, builder: (column) => column);

  GeneratedColumn<bool> get hiddenFromRecent => $composableBuilder(
    column: $table.hiddenFromRecent,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extendedNutrientsJson => $composableBuilder(
    column: $table.extendedNutrientsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get openFoodFactsId => $composableBuilder(
    column: $table.openFoodFactsId,
    builder: (column) => column,
  );

  Expression<T> mealFoodTableRefs<T extends Object>(
    Expression<T> Function($$MealFoodTableTableAnnotationComposer a) f,
  ) {
    final $$MealFoodTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealFoodTable,
      getReferencedColumn: (t) => t.foodEntryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealFoodTableTableAnnotationComposer(
            $db: $db,
            $table: $db.mealFoodTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodItemTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodItemTable,
          FoodItemData,
          $$FoodItemTableFilterComposer,
          $$FoodItemTableOrderingComposer,
          $$FoodItemTableAnnotationComposer,
          $$FoodItemTableCreateCompanionBuilder,
          $$FoodItemTableUpdateCompanionBuilder,
          (FoodItemData, $$FoodItemTableReferences),
          FoodItemData,
          PrefetchHooks Function({bool mealFoodTableRefs})
        > {
  $$FoodItemTableTableManager(_$AppDatabase db, $FoodItemTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$FoodItemTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$FoodItemTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$FoodItemTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> calories = const Value.absent(),
                Value<int> protein = const Value.absent(),
                Value<int> carbs = const Value.absent(),
                Value<int> fat = const Value.absent(),
                Value<int> gramm = const Value.absent(),
                Value<bool> hiddenFromRecent = const Value.absent(),
                Value<String?> extendedNutrientsJson = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String?> openFoodFactsId = const Value.absent(),
              }) => FoodItemCompanion(
                id: id,
                name: name,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                gramm: gramm,
                hiddenFromRecent: hiddenFromRecent,
                extendedNutrientsJson: extendedNutrientsJson,
                syncStatus: syncStatus,
                serverId: serverId,
                openFoodFactsId: openFoodFactsId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int calories,
                required int protein,
                required int carbs,
                required int fat,
                Value<int> gramm = const Value.absent(),
                Value<bool> hiddenFromRecent = const Value.absent(),
                Value<String?> extendedNutrientsJson = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String?> openFoodFactsId = const Value.absent(),
              }) => FoodItemCompanion.insert(
                id: id,
                name: name,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                gramm: gramm,
                hiddenFromRecent: hiddenFromRecent,
                extendedNutrientsJson: extendedNutrientsJson,
                syncStatus: syncStatus,
                serverId: serverId,
                openFoodFactsId: openFoodFactsId,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$FoodItemTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({mealFoodTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (mealFoodTableRefs) db.mealFoodTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mealFoodTableRefs)
                    await $_getPrefetchedData<
                      FoodItemData,
                      $FoodItemTable,
                      MealFoodTableData
                    >(
                      currentTable: table,
                      referencedTable: $$FoodItemTableReferences
                          ._mealFoodTableRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$FoodItemTableReferences(
                                db,
                                table,
                                p0,
                              ).mealFoodTableRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.foodEntryId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FoodItemTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodItemTable,
      FoodItemData,
      $$FoodItemTableFilterComposer,
      $$FoodItemTableOrderingComposer,
      $$FoodItemTableAnnotationComposer,
      $$FoodItemTableCreateCompanionBuilder,
      $$FoodItemTableUpdateCompanionBuilder,
      (FoodItemData, $$FoodItemTableReferences),
      FoodItemData,
      PrefetchHooks Function({bool mealFoodTableRefs})
    >;
typedef $$VerifiedFoodTableTableCreateCompanionBuilder =
    VerifiedFoodTableCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> nameDe,
      required int calories,
      required double protein,
      required double carbs,
      required double fat,
      Value<String?> sourceCode,
    });
typedef $$VerifiedFoodTableTableUpdateCompanionBuilder =
    VerifiedFoodTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> nameDe,
      Value<int> calories,
      Value<double> protein,
      Value<double> carbs,
      Value<double> fat,
      Value<String?> sourceCode,
    });

class $$VerifiedFoodTableTableFilterComposer
    extends Composer<_$AppDatabase, $VerifiedFoodTableTable> {
  $$VerifiedFoodTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameDe => $composableBuilder(
    column: $table.nameDe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fat => $composableBuilder(
    column: $table.fat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceCode => $composableBuilder(
    column: $table.sourceCode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VerifiedFoodTableTableOrderingComposer
    extends Composer<_$AppDatabase, $VerifiedFoodTableTable> {
  $$VerifiedFoodTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameDe => $composableBuilder(
    column: $table.nameDe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fat => $composableBuilder(
    column: $table.fat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceCode => $composableBuilder(
    column: $table.sourceCode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VerifiedFoodTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $VerifiedFoodTableTable> {
  $$VerifiedFoodTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameDe =>
      $composableBuilder(column: $table.nameDe, builder: (column) => column);

  GeneratedColumn<int> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<double> get protein =>
      $composableBuilder(column: $table.protein, builder: (column) => column);

  GeneratedColumn<double> get carbs =>
      $composableBuilder(column: $table.carbs, builder: (column) => column);

  GeneratedColumn<double> get fat =>
      $composableBuilder(column: $table.fat, builder: (column) => column);

  GeneratedColumn<String> get sourceCode => $composableBuilder(
    column: $table.sourceCode,
    builder: (column) => column,
  );
}

class $$VerifiedFoodTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VerifiedFoodTableTable,
          VerifiedFoodTableData,
          $$VerifiedFoodTableTableFilterComposer,
          $$VerifiedFoodTableTableOrderingComposer,
          $$VerifiedFoodTableTableAnnotationComposer,
          $$VerifiedFoodTableTableCreateCompanionBuilder,
          $$VerifiedFoodTableTableUpdateCompanionBuilder,
          (
            VerifiedFoodTableData,
            BaseReferences<
              _$AppDatabase,
              $VerifiedFoodTableTable,
              VerifiedFoodTableData
            >,
          ),
          VerifiedFoodTableData,
          PrefetchHooks Function()
        > {
  $$VerifiedFoodTableTableTableManager(
    _$AppDatabase db,
    $VerifiedFoodTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$VerifiedFoodTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$VerifiedFoodTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$VerifiedFoodTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> nameDe = const Value.absent(),
                Value<int> calories = const Value.absent(),
                Value<double> protein = const Value.absent(),
                Value<double> carbs = const Value.absent(),
                Value<double> fat = const Value.absent(),
                Value<String?> sourceCode = const Value.absent(),
              }) => VerifiedFoodTableCompanion(
                id: id,
                name: name,
                nameDe: nameDe,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                sourceCode: sourceCode,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> nameDe = const Value.absent(),
                required int calories,
                required double protein,
                required double carbs,
                required double fat,
                Value<String?> sourceCode = const Value.absent(),
              }) => VerifiedFoodTableCompanion.insert(
                id: id,
                name: name,
                nameDe: nameDe,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                sourceCode: sourceCode,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VerifiedFoodTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VerifiedFoodTableTable,
      VerifiedFoodTableData,
      $$VerifiedFoodTableTableFilterComposer,
      $$VerifiedFoodTableTableOrderingComposer,
      $$VerifiedFoodTableTableAnnotationComposer,
      $$VerifiedFoodTableTableCreateCompanionBuilder,
      $$VerifiedFoodTableTableUpdateCompanionBuilder,
      (
        VerifiedFoodTableData,
        BaseReferences<
          _$AppDatabase,
          $VerifiedFoodTableTable,
          VerifiedFoodTableData
        >,
      ),
      VerifiedFoodTableData,
      PrefetchHooks Function()
    >;
typedef $$UserSettingsTableCreateCompanionBuilder =
    UserSettingsCompanion Function({
      Value<int> id,
      Value<int> dailyCalorieGoal,
      Value<String> themeMode,
      Value<String> name,
      Value<int> age,
      Value<int> heightCm,
      Value<String> sex,
      Value<int> activityLevel,
      Value<int> goalType,
      Value<double> startingWeight,
      Value<double> goalWeight,
    });
typedef $$UserSettingsTableUpdateCompanionBuilder =
    UserSettingsCompanion Function({
      Value<int> id,
      Value<int> dailyCalorieGoal,
      Value<String> themeMode,
      Value<String> name,
      Value<int> age,
      Value<int> heightCm,
      Value<String> sex,
      Value<int> activityLevel,
      Value<int> goalType,
      Value<double> startingWeight,
      Value<double> goalWeight,
    });

class $$UserSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dailyCalorieGoal => $composableBuilder(
    column: $table.dailyCalorieGoal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get startingWeight => $composableBuilder(
    column: $table.startingWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get goalWeight => $composableBuilder(
    column: $table.goalWeight,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dailyCalorieGoal => $composableBuilder(
    column: $table.dailyCalorieGoal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get startingWeight => $composableBuilder(
    column: $table.startingWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get goalWeight => $composableBuilder(
    column: $table.goalWeight,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserSettingsTable> {
  $$UserSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dailyCalorieGoal => $composableBuilder(
    column: $table.dailyCalorieGoal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<int> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumn<String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<int> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get goalType =>
      $composableBuilder(column: $table.goalType, builder: (column) => column);

  GeneratedColumn<double> get startingWeight => $composableBuilder(
    column: $table.startingWeight,
    builder: (column) => column,
  );

  GeneratedColumn<double> get goalWeight => $composableBuilder(
    column: $table.goalWeight,
    builder: (column) => column,
  );
}

class $$UserSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserSettingsTable,
          UserSetting,
          $$UserSettingsTableFilterComposer,
          $$UserSettingsTableOrderingComposer,
          $$UserSettingsTableAnnotationComposer,
          $$UserSettingsTableCreateCompanionBuilder,
          $$UserSettingsTableUpdateCompanionBuilder,
          (
            UserSetting,
            BaseReferences<_$AppDatabase, $UserSettingsTable, UserSetting>,
          ),
          UserSetting,
          PrefetchHooks Function()
        > {
  $$UserSettingsTableTableManager(_$AppDatabase db, $UserSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$UserSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$UserSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$UserSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dailyCalorieGoal = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> age = const Value.absent(),
                Value<int> heightCm = const Value.absent(),
                Value<String> sex = const Value.absent(),
                Value<int> activityLevel = const Value.absent(),
                Value<int> goalType = const Value.absent(),
                Value<double> startingWeight = const Value.absent(),
                Value<double> goalWeight = const Value.absent(),
              }) => UserSettingsCompanion(
                id: id,
                dailyCalorieGoal: dailyCalorieGoal,
                themeMode: themeMode,
                name: name,
                age: age,
                heightCm: heightCm,
                sex: sex,
                activityLevel: activityLevel,
                goalType: goalType,
                startingWeight: startingWeight,
                goalWeight: goalWeight,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dailyCalorieGoal = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> age = const Value.absent(),
                Value<int> heightCm = const Value.absent(),
                Value<String> sex = const Value.absent(),
                Value<int> activityLevel = const Value.absent(),
                Value<int> goalType = const Value.absent(),
                Value<double> startingWeight = const Value.absent(),
                Value<double> goalWeight = const Value.absent(),
              }) => UserSettingsCompanion.insert(
                id: id,
                dailyCalorieGoal: dailyCalorieGoal,
                themeMode: themeMode,
                name: name,
                age: age,
                heightCm: heightCm,
                sex: sex,
                activityLevel: activityLevel,
                goalType: goalType,
                startingWeight: startingWeight,
                goalWeight: goalWeight,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserSettingsTable,
      UserSetting,
      $$UserSettingsTableFilterComposer,
      $$UserSettingsTableOrderingComposer,
      $$UserSettingsTableAnnotationComposer,
      $$UserSettingsTableCreateCompanionBuilder,
      $$UserSettingsTableUpdateCompanionBuilder,
      (
        UserSetting,
        BaseReferences<_$AppDatabase, $UserSettingsTable, UserSetting>,
      ),
      UserSetting,
      PrefetchHooks Function()
    >;
typedef $$MealTableTableCreateCompanionBuilder =
    MealTableCompanion Function({
      Value<int> id,
      required DateTime date,
      required String category,
      required int foodItemId,
      Value<int> syncStatus,
      Value<String?> serverId,
    });
typedef $$MealTableTableUpdateCompanionBuilder =
    MealTableCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String> category,
      Value<int> foodItemId,
      Value<int> syncStatus,
      Value<String?> serverId,
    });

final class $$MealTableTableReferences
    extends BaseReferences<_$AppDatabase, $MealTableTable, MealTableData> {
  $$MealTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MealFoodTableTable, List<MealFoodTableData>>
  _mealFoodTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealFoodTable,
    aliasName: $_aliasNameGenerator(db.mealTable.id, db.mealFoodTable.mealId),
  );

  $$MealFoodTableTableProcessedTableManager get mealFoodTableRefs {
    final manager = $$MealFoodTableTableTableManager(
      $_db,
      $_db.mealFoodTable,
    ).filter((f) => f.mealId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mealFoodTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MealTableTableFilterComposer
    extends Composer<_$AppDatabase, $MealTableTable> {
  $$MealTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get foodItemId => $composableBuilder(
    column: $table.foodItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mealFoodTableRefs(
    Expression<bool> Function($$MealFoodTableTableFilterComposer f) f,
  ) {
    final $$MealFoodTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealFoodTable,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealFoodTableTableFilterComposer(
            $db: $db,
            $table: $db.mealFoodTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MealTableTable> {
  $$MealTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get foodItemId => $composableBuilder(
    column: $table.foodItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealTableTable> {
  $$MealTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get foodItemId => $composableBuilder(
    column: $table.foodItemId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  Expression<T> mealFoodTableRefs<T extends Object>(
    Expression<T> Function($$MealFoodTableTableAnnotationComposer a) f,
  ) {
    final $$MealFoodTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealFoodTable,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealFoodTableTableAnnotationComposer(
            $db: $db,
            $table: $db.mealFoodTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealTableTable,
          MealTableData,
          $$MealTableTableFilterComposer,
          $$MealTableTableOrderingComposer,
          $$MealTableTableAnnotationComposer,
          $$MealTableTableCreateCompanionBuilder,
          $$MealTableTableUpdateCompanionBuilder,
          (MealTableData, $$MealTableTableReferences),
          MealTableData,
          PrefetchHooks Function({bool mealFoodTableRefs})
        > {
  $$MealTableTableTableManager(_$AppDatabase db, $MealTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$MealTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$MealTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$MealTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> foodItemId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
              }) => MealTableCompanion(
                id: id,
                date: date,
                category: category,
                foodItemId: foodItemId,
                syncStatus: syncStatus,
                serverId: serverId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required String category,
                required int foodItemId,
                Value<int> syncStatus = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
              }) => MealTableCompanion.insert(
                id: id,
                date: date,
                category: category,
                foodItemId: foodItemId,
                syncStatus: syncStatus,
                serverId: serverId,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$MealTableTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({mealFoodTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (mealFoodTableRefs) db.mealFoodTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mealFoodTableRefs)
                    await $_getPrefetchedData<
                      MealTableData,
                      $MealTableTable,
                      MealFoodTableData
                    >(
                      currentTable: table,
                      referencedTable: $$MealTableTableReferences
                          ._mealFoodTableRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$MealTableTableReferences(
                                db,
                                table,
                                p0,
                              ).mealFoodTableRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.mealId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MealTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealTableTable,
      MealTableData,
      $$MealTableTableFilterComposer,
      $$MealTableTableOrderingComposer,
      $$MealTableTableAnnotationComposer,
      $$MealTableTableCreateCompanionBuilder,
      $$MealTableTableUpdateCompanionBuilder,
      (MealTableData, $$MealTableTableReferences),
      MealTableData,
      PrefetchHooks Function({bool mealFoodTableRefs})
    >;
typedef $$MealFoodTableTableCreateCompanionBuilder =
    MealFoodTableCompanion Function({
      Value<int> id,
      required int mealId,
      required int foodEntryId,
      Value<String?> serverId,
    });
typedef $$MealFoodTableTableUpdateCompanionBuilder =
    MealFoodTableCompanion Function({
      Value<int> id,
      Value<int> mealId,
      Value<int> foodEntryId,
      Value<String?> serverId,
    });

final class $$MealFoodTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $MealFoodTableTable, MealFoodTableData> {
  $$MealFoodTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MealTableTable _mealIdTable(_$AppDatabase db) =>
      db.mealTable.createAlias(
        $_aliasNameGenerator(db.mealFoodTable.mealId, db.mealTable.id),
      );

  $$MealTableTableProcessedTableManager get mealId {
    final $_column = $_itemColumn<int>('meal_id')!;

    final manager = $$MealTableTableTableManager(
      $_db,
      $_db.mealTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FoodItemTable _foodEntryIdTable(_$AppDatabase db) =>
      db.foodItem.createAlias(
        $_aliasNameGenerator(db.mealFoodTable.foodEntryId, db.foodItem.id),
      );

  $$FoodItemTableProcessedTableManager get foodEntryId {
    final $_column = $_itemColumn<int>('food_entry_id')!;

    final manager = $$FoodItemTableTableManager(
      $_db,
      $_db.foodItem,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodEntryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MealFoodTableTableFilterComposer
    extends Composer<_$AppDatabase, $MealFoodTableTable> {
  $$MealFoodTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  $$MealTableTableFilterComposer get mealId {
    final $$MealTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.mealTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealTableTableFilterComposer(
            $db: $db,
            $table: $db.mealTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoodItemTableFilterComposer get foodEntryId {
    final $$FoodItemTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodEntryId,
      referencedTable: $db.foodItem,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemTableFilterComposer(
            $db: $db,
            $table: $db.foodItem,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealFoodTableTableOrderingComposer
    extends Composer<_$AppDatabase, $MealFoodTableTable> {
  $$MealFoodTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  $$MealTableTableOrderingComposer get mealId {
    final $$MealTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.mealTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealTableTableOrderingComposer(
            $db: $db,
            $table: $db.mealTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoodItemTableOrderingComposer get foodEntryId {
    final $$FoodItemTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodEntryId,
      referencedTable: $db.foodItem,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemTableOrderingComposer(
            $db: $db,
            $table: $db.foodItem,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealFoodTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealFoodTableTable> {
  $$MealFoodTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  $$MealTableTableAnnotationComposer get mealId {
    final $$MealTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.mealTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealTableTableAnnotationComposer(
            $db: $db,
            $table: $db.mealTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoodItemTableAnnotationComposer get foodEntryId {
    final $$FoodItemTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodEntryId,
      referencedTable: $db.foodItem,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemTableAnnotationComposer(
            $db: $db,
            $table: $db.foodItem,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealFoodTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealFoodTableTable,
          MealFoodTableData,
          $$MealFoodTableTableFilterComposer,
          $$MealFoodTableTableOrderingComposer,
          $$MealFoodTableTableAnnotationComposer,
          $$MealFoodTableTableCreateCompanionBuilder,
          $$MealFoodTableTableUpdateCompanionBuilder,
          (MealFoodTableData, $$MealFoodTableTableReferences),
          MealFoodTableData,
          PrefetchHooks Function({bool mealId, bool foodEntryId})
        > {
  $$MealFoodTableTableTableManager(_$AppDatabase db, $MealFoodTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$MealFoodTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$MealFoodTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$MealFoodTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mealId = const Value.absent(),
                Value<int> foodEntryId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
              }) => MealFoodTableCompanion(
                id: id,
                mealId: mealId,
                foodEntryId: foodEntryId,
                serverId: serverId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mealId,
                required int foodEntryId,
                Value<String?> serverId = const Value.absent(),
              }) => MealFoodTableCompanion.insert(
                id: id,
                mealId: mealId,
                foodEntryId: foodEntryId,
                serverId: serverId,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$MealFoodTableTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({mealId = false, foodEntryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (mealId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.mealId,
                            referencedTable: $$MealFoodTableTableReferences
                                ._mealIdTable(db),
                            referencedColumn:
                                $$MealFoodTableTableReferences
                                    ._mealIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (foodEntryId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.foodEntryId,
                            referencedTable: $$MealFoodTableTableReferences
                                ._foodEntryIdTable(db),
                            referencedColumn:
                                $$MealFoodTableTableReferences
                                    ._foodEntryIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MealFoodTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealFoodTableTable,
      MealFoodTableData,
      $$MealFoodTableTableFilterComposer,
      $$MealFoodTableTableOrderingComposer,
      $$MealFoodTableTableAnnotationComposer,
      $$MealFoodTableTableCreateCompanionBuilder,
      $$MealFoodTableTableUpdateCompanionBuilder,
      (MealFoodTableData, $$MealFoodTableTableReferences),
      MealFoodTableData,
      PrefetchHooks Function({bool mealId, bool foodEntryId})
    >;
typedef $$SearchCacheTableTableCreateCompanionBuilder =
    SearchCacheTableCompanion Function({
      required String query,
      required String json,
      required int ts,
      Value<int> rowid,
    });
typedef $$SearchCacheTableTableUpdateCompanionBuilder =
    SearchCacheTableCompanion Function({
      Value<String> query,
      Value<String> json,
      Value<int> ts,
      Value<int> rowid,
    });

class $$SearchCacheTableTableFilterComposer
    extends Composer<_$AppDatabase, $SearchCacheTableTable> {
  $$SearchCacheTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchCacheTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SearchCacheTableTable> {
  $$SearchCacheTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get query => $composableBuilder(
    column: $table.query,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ts => $composableBuilder(
    column: $table.ts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchCacheTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SearchCacheTableTable> {
  $$SearchCacheTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get query =>
      $composableBuilder(column: $table.query, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get ts =>
      $composableBuilder(column: $table.ts, builder: (column) => column);
}

class $$SearchCacheTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SearchCacheTableTable,
          SearchCacheTableData,
          $$SearchCacheTableTableFilterComposer,
          $$SearchCacheTableTableOrderingComposer,
          $$SearchCacheTableTableAnnotationComposer,
          $$SearchCacheTableTableCreateCompanionBuilder,
          $$SearchCacheTableTableUpdateCompanionBuilder,
          (
            SearchCacheTableData,
            BaseReferences<
              _$AppDatabase,
              $SearchCacheTableTable,
              SearchCacheTableData
            >,
          ),
          SearchCacheTableData,
          PrefetchHooks Function()
        > {
  $$SearchCacheTableTableTableManager(
    _$AppDatabase db,
    $SearchCacheTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$SearchCacheTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SearchCacheTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$SearchCacheTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> query = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> ts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SearchCacheTableCompanion(
                query: query,
                json: json,
                ts: ts,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String query,
                required String json,
                required int ts,
                Value<int> rowid = const Value.absent(),
              }) => SearchCacheTableCompanion.insert(
                query: query,
                json: json,
                ts: ts,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchCacheTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SearchCacheTableTable,
      SearchCacheTableData,
      $$SearchCacheTableTableFilterComposer,
      $$SearchCacheTableTableOrderingComposer,
      $$SearchCacheTableTableAnnotationComposer,
      $$SearchCacheTableTableCreateCompanionBuilder,
      $$SearchCacheTableTableUpdateCompanionBuilder,
      (
        SearchCacheTableData,
        BaseReferences<
          _$AppDatabase,
          $SearchCacheTableTable,
          SearchCacheTableData
        >,
      ),
      SearchCacheTableData,
      PrefetchHooks Function()
    >;
typedef $$WeightRecordTableCreateCompanionBuilder =
    WeightRecordCompanion Function({
      Value<int> id,
      required DateTime date,
      required double weight,
      Value<String?> note,
      Value<int> syncStatus,
      Value<String?> serverId,
    });
typedef $$WeightRecordTableUpdateCompanionBuilder =
    WeightRecordCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<double> weight,
      Value<String?> note,
      Value<int> syncStatus,
      Value<String?> serverId,
    });

class $$WeightRecordTableFilterComposer
    extends Composer<_$AppDatabase, $WeightRecordTable> {
  $$WeightRecordTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeightRecordTableOrderingComposer
    extends Composer<_$AppDatabase, $WeightRecordTable> {
  $$WeightRecordTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeightRecordTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeightRecordTable> {
  $$WeightRecordTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);
}

class $$WeightRecordTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeightRecordTable,
          WeightRecordData,
          $$WeightRecordTableFilterComposer,
          $$WeightRecordTableOrderingComposer,
          $$WeightRecordTableAnnotationComposer,
          $$WeightRecordTableCreateCompanionBuilder,
          $$WeightRecordTableUpdateCompanionBuilder,
          (
            WeightRecordData,
            BaseReferences<_$AppDatabase, $WeightRecordTable, WeightRecordData>,
          ),
          WeightRecordData,
          PrefetchHooks Function()
        > {
  $$WeightRecordTableTableManager(_$AppDatabase db, $WeightRecordTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$WeightRecordTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$WeightRecordTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$WeightRecordTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
              }) => WeightRecordCompanion(
                id: id,
                date: date,
                weight: weight,
                note: note,
                syncStatus: syncStatus,
                serverId: serverId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required double weight,
                Value<String?> note = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
              }) => WeightRecordCompanion.insert(
                id: id,
                date: date,
                weight: weight,
                note: note,
                syncStatus: syncStatus,
                serverId: serverId,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeightRecordTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeightRecordTable,
      WeightRecordData,
      $$WeightRecordTableFilterComposer,
      $$WeightRecordTableOrderingComposer,
      $$WeightRecordTableAnnotationComposer,
      $$WeightRecordTableCreateCompanionBuilder,
      $$WeightRecordTableUpdateCompanionBuilder,
      (
        WeightRecordData,
        BaseReferences<_$AppDatabase, $WeightRecordTable, WeightRecordData>,
      ),
      WeightRecordData,
      PrefetchHooks Function()
    >;
typedef $$ExerciseTableTableCreateCompanionBuilder =
    ExerciseTableCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> description,
      Value<String?> nameDe,
      Value<String?> descriptionDe,
      required int type,
      required String targetMuscleGroups,
      Value<String?> imageUrl,
      Value<bool> isCustom,
      Value<String?> serverId,
      Value<int> syncStatus,
    });
typedef $$ExerciseTableTableUpdateCompanionBuilder =
    ExerciseTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> description,
      Value<String?> nameDe,
      Value<String?> descriptionDe,
      Value<int> type,
      Value<String> targetMuscleGroups,
      Value<String?> imageUrl,
      Value<bool> isCustom,
      Value<String?> serverId,
      Value<int> syncStatus,
    });

final class $$ExerciseTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $ExerciseTableTable, ExerciseTableData> {
  $$ExerciseTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $WorkoutExerciseTableTable,
    List<WorkoutExerciseTableData>
  >
  _workoutExerciseTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workoutExerciseTable,
        aliasName: $_aliasNameGenerator(
          db.exerciseTable.id,
          db.workoutExerciseTable.exerciseId,
        ),
      );

  $$WorkoutExerciseTableTableProcessedTableManager
  get workoutExerciseTableRefs {
    final manager = $$WorkoutExerciseTableTableTableManager(
      $_db,
      $_db.workoutExerciseTable,
    ).filter((f) => f.exerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workoutExerciseTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ExerciseTableTableFilterComposer
    extends Composer<_$AppDatabase, $ExerciseTableTable> {
  $$ExerciseTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameDe => $composableBuilder(
    column: $table.nameDe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descriptionDe => $composableBuilder(
    column: $table.descriptionDe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetMuscleGroups => $composableBuilder(
    column: $table.targetMuscleGroups,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workoutExerciseTableRefs(
    Expression<bool> Function($$WorkoutExerciseTableTableFilterComposer f) f,
  ) {
    final $$WorkoutExerciseTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutExerciseTable,
      getReferencedColumn: (t) => t.exerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutExerciseTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutExerciseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ExerciseTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ExerciseTableTable> {
  $$ExerciseTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameDe => $composableBuilder(
    column: $table.nameDe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descriptionDe => $composableBuilder(
    column: $table.descriptionDe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetMuscleGroups => $composableBuilder(
    column: $table.targetMuscleGroups,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExerciseTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExerciseTableTable> {
  $$ExerciseTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nameDe =>
      $composableBuilder(column: $table.nameDe, builder: (column) => column);

  GeneratedColumn<String> get descriptionDe => $composableBuilder(
    column: $table.descriptionDe,
    builder: (column) => column,
  );

  GeneratedColumn<int> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get targetMuscleGroups => $composableBuilder(
    column: $table.targetMuscleGroups,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  Expression<T> workoutExerciseTableRefs<T extends Object>(
    Expression<T> Function($$WorkoutExerciseTableTableAnnotationComposer a) f,
  ) {
    final $$WorkoutExerciseTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutExerciseTable,
          getReferencedColumn: (t) => t.exerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExerciseTableTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ExerciseTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExerciseTableTable,
          ExerciseTableData,
          $$ExerciseTableTableFilterComposer,
          $$ExerciseTableTableOrderingComposer,
          $$ExerciseTableTableAnnotationComposer,
          $$ExerciseTableTableCreateCompanionBuilder,
          $$ExerciseTableTableUpdateCompanionBuilder,
          (ExerciseTableData, $$ExerciseTableTableReferences),
          ExerciseTableData,
          PrefetchHooks Function({bool workoutExerciseTableRefs})
        > {
  $$ExerciseTableTableTableManager(_$AppDatabase db, $ExerciseTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ExerciseTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () =>
                  $$ExerciseTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () => $$ExerciseTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> nameDe = const Value.absent(),
                Value<String?> descriptionDe = const Value.absent(),
                Value<int> type = const Value.absent(),
                Value<String> targetMuscleGroups = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => ExerciseTableCompanion(
                id: id,
                name: name,
                description: description,
                nameDe: nameDe,
                descriptionDe: descriptionDe,
                type: type,
                targetMuscleGroups: targetMuscleGroups,
                imageUrl: imageUrl,
                isCustom: isCustom,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                Value<String?> nameDe = const Value.absent(),
                Value<String?> descriptionDe = const Value.absent(),
                required int type,
                required String targetMuscleGroups,
                Value<String?> imageUrl = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => ExerciseTableCompanion.insert(
                id: id,
                name: name,
                description: description,
                nameDe: nameDe,
                descriptionDe: descriptionDe,
                type: type,
                targetMuscleGroups: targetMuscleGroups,
                imageUrl: imageUrl,
                isCustom: isCustom,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$ExerciseTableTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({workoutExerciseTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (workoutExerciseTableRefs) db.workoutExerciseTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (workoutExerciseTableRefs)
                    await $_getPrefetchedData<
                      ExerciseTableData,
                      $ExerciseTableTable,
                      WorkoutExerciseTableData
                    >(
                      currentTable: table,
                      referencedTable: $$ExerciseTableTableReferences
                          ._workoutExerciseTableRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$ExerciseTableTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutExerciseTableRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.exerciseId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ExerciseTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExerciseTableTable,
      ExerciseTableData,
      $$ExerciseTableTableFilterComposer,
      $$ExerciseTableTableOrderingComposer,
      $$ExerciseTableTableAnnotationComposer,
      $$ExerciseTableTableCreateCompanionBuilder,
      $$ExerciseTableTableUpdateCompanionBuilder,
      (ExerciseTableData, $$ExerciseTableTableReferences),
      ExerciseTableData,
      PrefetchHooks Function({bool workoutExerciseTableRefs})
    >;
typedef $$WorkoutTableTableCreateCompanionBuilder =
    WorkoutTableCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> description,
      required int difficulty,
      Value<int> estimatedDurationMinutes,
      Value<bool> isTemplate,
      Value<DateTime?> scheduledDate,
      Value<DateTime?> completedDate,
      Value<int?> color,
      Value<String?> serverId,
      Value<int> syncStatus,
    });
typedef $$WorkoutTableTableUpdateCompanionBuilder =
    WorkoutTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> description,
      Value<int> difficulty,
      Value<int> estimatedDurationMinutes,
      Value<bool> isTemplate,
      Value<DateTime?> scheduledDate,
      Value<DateTime?> completedDate,
      Value<int?> color,
      Value<String?> serverId,
      Value<int> syncStatus,
    });

final class $$WorkoutTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $WorkoutTableTable, WorkoutTableData> {
  $$WorkoutTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $WorkoutExerciseTableTable,
    List<WorkoutExerciseTableData>
  >
  _workoutExerciseTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workoutExerciseTable,
        aliasName: $_aliasNameGenerator(
          db.workoutTable.id,
          db.workoutExerciseTable.workoutId,
        ),
      );

  $$WorkoutExerciseTableTableProcessedTableManager
  get workoutExerciseTableRefs {
    final manager = $$WorkoutExerciseTableTableTableManager(
      $_db,
      $_db.workoutExerciseTable,
    ).filter((f) => f.workoutId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workoutExerciseTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ScheduledWorkoutTableTable,
    List<ScheduledWorkoutTableData>
  >
  _scheduledWorkoutTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduledWorkoutTable,
        aliasName: $_aliasNameGenerator(
          db.workoutTable.id,
          db.scheduledWorkoutTable.workoutId,
        ),
      );

  $$ScheduledWorkoutTableTableProcessedTableManager
  get scheduledWorkoutTableRefs {
    final manager = $$ScheduledWorkoutTableTableTableManager(
      $_db,
      $_db.scheduledWorkoutTable,
    ).filter((f) => f.workoutId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scheduledWorkoutTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ScheduledWorkoutTableTable,
    List<ScheduledWorkoutTableData>
  >
  _scheduledWorkoutTemplateRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduledWorkoutTable,
        aliasName: $_aliasNameGenerator(
          db.workoutTable.id,
          db.scheduledWorkoutTable.templateWorkoutId,
        ),
      );

  $$ScheduledWorkoutTableTableProcessedTableManager
  get scheduledWorkoutTemplateRefs {
    final manager = $$ScheduledWorkoutTableTableTableManager(
      $_db,
      $_db.scheduledWorkoutTable,
    ).filter((f) => f.templateWorkoutId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scheduledWorkoutTemplateRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WorkoutPlanWorkoutTableTable,
    List<WorkoutPlanWorkoutTableData>
  >
  _workoutPlanWorkoutTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workoutPlanWorkoutTable,
        aliasName: $_aliasNameGenerator(
          db.workoutTable.id,
          db.workoutPlanWorkoutTable.workoutId,
        ),
      );

  $$WorkoutPlanWorkoutTableTableProcessedTableManager
  get workoutPlanWorkoutTableRefs {
    final manager = $$WorkoutPlanWorkoutTableTableTableManager(
      $_db,
      $_db.workoutPlanWorkoutTable,
    ).filter((f) => f.workoutId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workoutPlanWorkoutTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutTableTable> {
  $$WorkoutTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedDurationMinutes => $composableBuilder(
    column: $table.estimatedDurationMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isTemplate => $composableBuilder(
    column: $table.isTemplate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedDate => $composableBuilder(
    column: $table.completedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> workoutExerciseTableRefs(
    Expression<bool> Function($$WorkoutExerciseTableTableFilterComposer f) f,
  ) {
    final $$WorkoutExerciseTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutExerciseTable,
      getReferencedColumn: (t) => t.workoutId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutExerciseTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutExerciseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> scheduledWorkoutTableRefs(
    Expression<bool> Function($$ScheduledWorkoutTableTableFilterComposer f) f,
  ) {
    final $$ScheduledWorkoutTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledWorkoutTable,
          getReferencedColumn: (t) => t.workoutId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutTableTableFilterComposer(
                $db: $db,
                $table: $db.scheduledWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> scheduledWorkoutTemplateRefs(
    Expression<bool> Function($$ScheduledWorkoutTableTableFilterComposer f) f,
  ) {
    final $$ScheduledWorkoutTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledWorkoutTable,
          getReferencedColumn: (t) => t.templateWorkoutId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutTableTableFilterComposer(
                $db: $db,
                $table: $db.scheduledWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> workoutPlanWorkoutTableRefs(
    Expression<bool> Function($$WorkoutPlanWorkoutTableTableFilterComposer f) f,
  ) {
    final $$WorkoutPlanWorkoutTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutPlanWorkoutTable,
          getReferencedColumn: (t) => t.workoutId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutPlanWorkoutTableTableFilterComposer(
                $db: $db,
                $table: $db.workoutPlanWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorkoutTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutTableTable> {
  $$WorkoutTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedDurationMinutes => $composableBuilder(
    column: $table.estimatedDurationMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isTemplate => $composableBuilder(
    column: $table.isTemplate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedDate => $composableBuilder(
    column: $table.completedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutTableTable> {
  $$WorkoutTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimatedDurationMinutes => $composableBuilder(
    column: $table.estimatedDurationMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isTemplate => $composableBuilder(
    column: $table.isTemplate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedDate => $composableBuilder(
    column: $table.completedDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  Expression<T> workoutExerciseTableRefs<T extends Object>(
    Expression<T> Function($$WorkoutExerciseTableTableAnnotationComposer a) f,
  ) {
    final $$WorkoutExerciseTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutExerciseTable,
          getReferencedColumn: (t) => t.workoutId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExerciseTableTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> scheduledWorkoutTableRefs<T extends Object>(
    Expression<T> Function($$ScheduledWorkoutTableTableAnnotationComposer a) f,
  ) {
    final $$ScheduledWorkoutTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledWorkoutTable,
          getReferencedColumn: (t) => t.workoutId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutTableTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> scheduledWorkoutTemplateRefs<T extends Object>(
    Expression<T> Function($$ScheduledWorkoutTableTableAnnotationComposer a) f,
  ) {
    final $$ScheduledWorkoutTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledWorkoutTable,
          getReferencedColumn: (t) => t.templateWorkoutId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutTableTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> workoutPlanWorkoutTableRefs<T extends Object>(
    Expression<T> Function($$WorkoutPlanWorkoutTableTableAnnotationComposer a)
    f,
  ) {
    final $$WorkoutPlanWorkoutTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutPlanWorkoutTable,
          getReferencedColumn: (t) => t.workoutId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutPlanWorkoutTableTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutPlanWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorkoutTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutTableTable,
          WorkoutTableData,
          $$WorkoutTableTableFilterComposer,
          $$WorkoutTableTableOrderingComposer,
          $$WorkoutTableTableAnnotationComposer,
          $$WorkoutTableTableCreateCompanionBuilder,
          $$WorkoutTableTableUpdateCompanionBuilder,
          (WorkoutTableData, $$WorkoutTableTableReferences),
          WorkoutTableData,
          PrefetchHooks Function({
            bool workoutExerciseTableRefs,
            bool scheduledWorkoutTableRefs,
            bool scheduledWorkoutTemplateRefs,
            bool workoutPlanWorkoutTableRefs,
          })
        > {
  $$WorkoutTableTableTableManager(_$AppDatabase db, $WorkoutTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$WorkoutTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$WorkoutTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer:
              () =>
                  $$WorkoutTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> difficulty = const Value.absent(),
                Value<int> estimatedDurationMinutes = const Value.absent(),
                Value<bool> isTemplate = const Value.absent(),
                Value<DateTime?> scheduledDate = const Value.absent(),
                Value<DateTime?> completedDate = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => WorkoutTableCompanion(
                id: id,
                name: name,
                description: description,
                difficulty: difficulty,
                estimatedDurationMinutes: estimatedDurationMinutes,
                isTemplate: isTemplate,
                scheduledDate: scheduledDate,
                completedDate: completedDate,
                color: color,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                required int difficulty,
                Value<int> estimatedDurationMinutes = const Value.absent(),
                Value<bool> isTemplate = const Value.absent(),
                Value<DateTime?> scheduledDate = const Value.absent(),
                Value<DateTime?> completedDate = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => WorkoutTableCompanion.insert(
                id: id,
                name: name,
                description: description,
                difficulty: difficulty,
                estimatedDurationMinutes: estimatedDurationMinutes,
                isTemplate: isTemplate,
                scheduledDate: scheduledDate,
                completedDate: completedDate,
                color: color,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$WorkoutTableTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            workoutExerciseTableRefs = false,
            scheduledWorkoutTableRefs = false,
            scheduledWorkoutTemplateRefs = false,
            workoutPlanWorkoutTableRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (workoutExerciseTableRefs) db.workoutExerciseTable,
                if (scheduledWorkoutTableRefs) db.scheduledWorkoutTable,
                if (scheduledWorkoutTemplateRefs) db.scheduledWorkoutTable,
                if (workoutPlanWorkoutTableRefs) db.workoutPlanWorkoutTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (workoutExerciseTableRefs)
                    await $_getPrefetchedData<
                      WorkoutTableData,
                      $WorkoutTableTable,
                      WorkoutExerciseTableData
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutTableTableReferences
                          ._workoutExerciseTableRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$WorkoutTableTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutExerciseTableRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.workoutId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (scheduledWorkoutTableRefs)
                    await $_getPrefetchedData<
                      WorkoutTableData,
                      $WorkoutTableTable,
                      ScheduledWorkoutTableData
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutTableTableReferences
                          ._scheduledWorkoutTableRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$WorkoutTableTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledWorkoutTableRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.workoutId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (scheduledWorkoutTemplateRefs)
                    await $_getPrefetchedData<
                      WorkoutTableData,
                      $WorkoutTableTable,
                      ScheduledWorkoutTableData
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutTableTableReferences
                          ._scheduledWorkoutTemplateRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$WorkoutTableTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledWorkoutTemplateRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.templateWorkoutId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (workoutPlanWorkoutTableRefs)
                    await $_getPrefetchedData<
                      WorkoutTableData,
                      $WorkoutTableTable,
                      WorkoutPlanWorkoutTableData
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutTableTableReferences
                          ._workoutPlanWorkoutTableRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$WorkoutTableTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutPlanWorkoutTableRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.workoutId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutTableTable,
      WorkoutTableData,
      $$WorkoutTableTableFilterComposer,
      $$WorkoutTableTableOrderingComposer,
      $$WorkoutTableTableAnnotationComposer,
      $$WorkoutTableTableCreateCompanionBuilder,
      $$WorkoutTableTableUpdateCompanionBuilder,
      (WorkoutTableData, $$WorkoutTableTableReferences),
      WorkoutTableData,
      PrefetchHooks Function({
        bool workoutExerciseTableRefs,
        bool scheduledWorkoutTableRefs,
        bool scheduledWorkoutTemplateRefs,
        bool workoutPlanWorkoutTableRefs,
      })
    >;
typedef $$WorkoutPlanTableTableCreateCompanionBuilder =
    WorkoutPlanTableCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> description,
      required DateTime startDate,
      Value<DateTime> createdAt,
      Value<bool> isActive,
      required String cyclePatternJson,
      Value<bool> isFreeChoice,
      Value<int?> durationDays,
      Value<String?> serverId,
      Value<int> syncStatus,
    });
typedef $$WorkoutPlanTableTableUpdateCompanionBuilder =
    WorkoutPlanTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> description,
      Value<DateTime> startDate,
      Value<DateTime> createdAt,
      Value<bool> isActive,
      Value<String> cyclePatternJson,
      Value<bool> isFreeChoice,
      Value<int?> durationDays,
      Value<String?> serverId,
      Value<int> syncStatus,
    });

final class $$WorkoutPlanTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorkoutPlanTableTable,
          WorkoutPlanTableData
        > {
  $$WorkoutPlanTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $ScheduledWorkoutTableTable,
    List<ScheduledWorkoutTableData>
  >
  _scheduledWorkoutTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduledWorkoutTable,
        aliasName: $_aliasNameGenerator(
          db.workoutPlanTable.id,
          db.scheduledWorkoutTable.workoutPlanId,
        ),
      );

  $$ScheduledWorkoutTableTableProcessedTableManager
  get scheduledWorkoutTableRefs {
    final manager = $$ScheduledWorkoutTableTableTableManager(
      $_db,
      $_db.scheduledWorkoutTable,
    ).filter((f) => f.workoutPlanId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scheduledWorkoutTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WorkoutPlanWorkoutTableTable,
    List<WorkoutPlanWorkoutTableData>
  >
  _workoutPlanWorkoutTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workoutPlanWorkoutTable,
        aliasName: $_aliasNameGenerator(
          db.workoutPlanTable.id,
          db.workoutPlanWorkoutTable.planId,
        ),
      );

  $$WorkoutPlanWorkoutTableTableProcessedTableManager
  get workoutPlanWorkoutTableRefs {
    final manager = $$WorkoutPlanWorkoutTableTableTableManager(
      $_db,
      $_db.workoutPlanWorkoutTable,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workoutPlanWorkoutTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutPlanTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutPlanTableTable> {
  $$WorkoutPlanTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cyclePatternJson => $composableBuilder(
    column: $table.cyclePatternJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFreeChoice => $composableBuilder(
    column: $table.isFreeChoice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationDays => $composableBuilder(
    column: $table.durationDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> scheduledWorkoutTableRefs(
    Expression<bool> Function($$ScheduledWorkoutTableTableFilterComposer f) f,
  ) {
    final $$ScheduledWorkoutTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledWorkoutTable,
          getReferencedColumn: (t) => t.workoutPlanId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutTableTableFilterComposer(
                $db: $db,
                $table: $db.scheduledWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> workoutPlanWorkoutTableRefs(
    Expression<bool> Function($$WorkoutPlanWorkoutTableTableFilterComposer f) f,
  ) {
    final $$WorkoutPlanWorkoutTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutPlanWorkoutTable,
          getReferencedColumn: (t) => t.planId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutPlanWorkoutTableTableFilterComposer(
                $db: $db,
                $table: $db.workoutPlanWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorkoutPlanTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutPlanTableTable> {
  $$WorkoutPlanTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cyclePatternJson => $composableBuilder(
    column: $table.cyclePatternJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFreeChoice => $composableBuilder(
    column: $table.isFreeChoice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationDays => $composableBuilder(
    column: $table.durationDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutPlanTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutPlanTableTable> {
  $$WorkoutPlanTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get cyclePatternJson => $composableBuilder(
    column: $table.cyclePatternJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFreeChoice => $composableBuilder(
    column: $table.isFreeChoice,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationDays => $composableBuilder(
    column: $table.durationDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  Expression<T> scheduledWorkoutTableRefs<T extends Object>(
    Expression<T> Function($$ScheduledWorkoutTableTableAnnotationComposer a) f,
  ) {
    final $$ScheduledWorkoutTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledWorkoutTable,
          getReferencedColumn: (t) => t.workoutPlanId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutTableTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> workoutPlanWorkoutTableRefs<T extends Object>(
    Expression<T> Function($$WorkoutPlanWorkoutTableTableAnnotationComposer a)
    f,
  ) {
    final $$WorkoutPlanWorkoutTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutPlanWorkoutTable,
          getReferencedColumn: (t) => t.planId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutPlanWorkoutTableTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutPlanWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorkoutPlanTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutPlanTableTable,
          WorkoutPlanTableData,
          $$WorkoutPlanTableTableFilterComposer,
          $$WorkoutPlanTableTableOrderingComposer,
          $$WorkoutPlanTableTableAnnotationComposer,
          $$WorkoutPlanTableTableCreateCompanionBuilder,
          $$WorkoutPlanTableTableUpdateCompanionBuilder,
          (WorkoutPlanTableData, $$WorkoutPlanTableTableReferences),
          WorkoutPlanTableData,
          PrefetchHooks Function({
            bool scheduledWorkoutTableRefs,
            bool workoutPlanWorkoutTableRefs,
          })
        > {
  $$WorkoutPlanTableTableTableManager(
    _$AppDatabase db,
    $WorkoutPlanTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$WorkoutPlanTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$WorkoutPlanTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$WorkoutPlanTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String> cyclePatternJson = const Value.absent(),
                Value<bool> isFreeChoice = const Value.absent(),
                Value<int?> durationDays = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => WorkoutPlanTableCompanion(
                id: id,
                name: name,
                description: description,
                startDate: startDate,
                createdAt: createdAt,
                isActive: isActive,
                cyclePatternJson: cyclePatternJson,
                isFreeChoice: isFreeChoice,
                durationDays: durationDays,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                required DateTime startDate,
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required String cyclePatternJson,
                Value<bool> isFreeChoice = const Value.absent(),
                Value<int?> durationDays = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => WorkoutPlanTableCompanion.insert(
                id: id,
                name: name,
                description: description,
                startDate: startDate,
                createdAt: createdAt,
                isActive: isActive,
                cyclePatternJson: cyclePatternJson,
                isFreeChoice: isFreeChoice,
                durationDays: durationDays,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$WorkoutPlanTableTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            scheduledWorkoutTableRefs = false,
            workoutPlanWorkoutTableRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (scheduledWorkoutTableRefs) db.scheduledWorkoutTable,
                if (workoutPlanWorkoutTableRefs) db.workoutPlanWorkoutTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (scheduledWorkoutTableRefs)
                    await $_getPrefetchedData<
                      WorkoutPlanTableData,
                      $WorkoutPlanTableTable,
                      ScheduledWorkoutTableData
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutPlanTableTableReferences
                          ._scheduledWorkoutTableRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$WorkoutPlanTableTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledWorkoutTableRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.workoutPlanId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (workoutPlanWorkoutTableRefs)
                    await $_getPrefetchedData<
                      WorkoutPlanTableData,
                      $WorkoutPlanTableTable,
                      WorkoutPlanWorkoutTableData
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutPlanTableTableReferences
                          ._workoutPlanWorkoutTableRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$WorkoutPlanTableTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutPlanWorkoutTableRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) =>
                              referencedItems.where((e) => e.planId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutPlanTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutPlanTableTable,
      WorkoutPlanTableData,
      $$WorkoutPlanTableTableFilterComposer,
      $$WorkoutPlanTableTableOrderingComposer,
      $$WorkoutPlanTableTableAnnotationComposer,
      $$WorkoutPlanTableTableCreateCompanionBuilder,
      $$WorkoutPlanTableTableUpdateCompanionBuilder,
      (WorkoutPlanTableData, $$WorkoutPlanTableTableReferences),
      WorkoutPlanTableData,
      PrefetchHooks Function({
        bool scheduledWorkoutTableRefs,
        bool workoutPlanWorkoutTableRefs,
      })
    >;
typedef $$WorkoutExerciseTableTableCreateCompanionBuilder =
    WorkoutExerciseTableCompanion Function({
      Value<int> id,
      required int workoutId,
      required int exerciseId,
      required int orderPosition,
      Value<String?> notes,
      Value<int?> supersetGroupId,
      Value<String?> serverId,
      Value<int> syncStatus,
    });
typedef $$WorkoutExerciseTableTableUpdateCompanionBuilder =
    WorkoutExerciseTableCompanion Function({
      Value<int> id,
      Value<int> workoutId,
      Value<int> exerciseId,
      Value<int> orderPosition,
      Value<String?> notes,
      Value<int?> supersetGroupId,
      Value<String?> serverId,
      Value<int> syncStatus,
    });

final class $$WorkoutExerciseTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorkoutExerciseTableTable,
          WorkoutExerciseTableData
        > {
  $$WorkoutExerciseTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkoutTableTable _workoutIdTable(_$AppDatabase db) =>
      db.workoutTable.createAlias(
        $_aliasNameGenerator(
          db.workoutExerciseTable.workoutId,
          db.workoutTable.id,
        ),
      );

  $$WorkoutTableTableProcessedTableManager get workoutId {
    final $_column = $_itemColumn<int>('workout_id')!;

    final manager = $$WorkoutTableTableTableManager(
      $_db,
      $_db.workoutTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workoutIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ExerciseTableTable _exerciseIdTable(_$AppDatabase db) =>
      db.exerciseTable.createAlias(
        $_aliasNameGenerator(
          db.workoutExerciseTable.exerciseId,
          db.exerciseTable.id,
        ),
      );

  $$ExerciseTableTableProcessedTableManager get exerciseId {
    final $_column = $_itemColumn<int>('exercise_id')!;

    final manager = $$ExerciseTableTableTableManager(
      $_db,
      $_db.exerciseTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_exerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $ScheduledWorkoutExerciseTableTable,
    List<ScheduledWorkoutExerciseTableData>
  >
  _scheduledWorkoutExerciseTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduledWorkoutExerciseTable,
        aliasName: $_aliasNameGenerator(
          db.workoutExerciseTable.id,
          db.scheduledWorkoutExerciseTable.workoutExerciseId,
        ),
      );

  $$ScheduledWorkoutExerciseTableTableProcessedTableManager
  get scheduledWorkoutExerciseTableRefs {
    final manager = $$ScheduledWorkoutExerciseTableTableTableManager(
      $_db,
      $_db.scheduledWorkoutExerciseTable,
    ).filter((f) => f.workoutExerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _scheduledWorkoutExerciseTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $WorkoutSetTemplateTableTable,
    List<WorkoutSetTemplateData>
  >
  _workoutSetTemplateTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.workoutSetTemplateTable,
        aliasName: $_aliasNameGenerator(
          db.workoutExerciseTable.id,
          db.workoutSetTemplateTable.workoutExerciseId,
        ),
      );

  $$WorkoutSetTemplateTableTableProcessedTableManager
  get workoutSetTemplateTableRefs {
    final manager = $$WorkoutSetTemplateTableTableTableManager(
      $_db,
      $_db.workoutSetTemplateTable,
    ).filter((f) => f.workoutExerciseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _workoutSetTemplateTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$WorkoutExerciseTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutExerciseTableTable> {
  $$WorkoutExerciseTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderPosition => $composableBuilder(
    column: $table.orderPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get supersetGroupId => $composableBuilder(
    column: $table.supersetGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutTableTableFilterComposer get workoutId {
    final $$WorkoutTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workoutTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExerciseTableTableFilterComposer get exerciseId {
    final $$ExerciseTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exerciseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExerciseTableTableFilterComposer(
            $db: $db,
            $table: $db.exerciseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> scheduledWorkoutExerciseTableRefs(
    Expression<bool> Function(
      $$ScheduledWorkoutExerciseTableTableFilterComposer f,
    )
    f,
  ) {
    final $$ScheduledWorkoutExerciseTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledWorkoutExerciseTable,
          getReferencedColumn: (t) => t.workoutExerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutExerciseTableTableFilterComposer(
                $db: $db,
                $table: $db.scheduledWorkoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> workoutSetTemplateTableRefs(
    Expression<bool> Function($$WorkoutSetTemplateTableTableFilterComposer f) f,
  ) {
    final $$WorkoutSetTemplateTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutSetTemplateTable,
          getReferencedColumn: (t) => t.workoutExerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutSetTemplateTableTableFilterComposer(
                $db: $db,
                $table: $db.workoutSetTemplateTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorkoutExerciseTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutExerciseTableTable> {
  $$WorkoutExerciseTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderPosition => $composableBuilder(
    column: $table.orderPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get supersetGroupId => $composableBuilder(
    column: $table.supersetGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutTableTableOrderingComposer get workoutId {
    final $$WorkoutTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workoutTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutTableTableOrderingComposer(
            $db: $db,
            $table: $db.workoutTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExerciseTableTableOrderingComposer get exerciseId {
    final $$ExerciseTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exerciseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExerciseTableTableOrderingComposer(
            $db: $db,
            $table: $db.exerciseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutExerciseTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutExerciseTableTable> {
  $$WorkoutExerciseTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get orderPosition => $composableBuilder(
    column: $table.orderPosition,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get supersetGroupId => $composableBuilder(
    column: $table.supersetGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$WorkoutTableTableAnnotationComposer get workoutId {
    final $$WorkoutTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workoutTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutTableTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ExerciseTableTableAnnotationComposer get exerciseId {
    final $$ExerciseTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.exerciseId,
      referencedTable: $db.exerciseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExerciseTableTableAnnotationComposer(
            $db: $db,
            $table: $db.exerciseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> scheduledWorkoutExerciseTableRefs<T extends Object>(
    Expression<T> Function(
      $$ScheduledWorkoutExerciseTableTableAnnotationComposer a,
    )
    f,
  ) {
    final $$ScheduledWorkoutExerciseTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledWorkoutExerciseTable,
          getReferencedColumn: (t) => t.workoutExerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutExerciseTableTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledWorkoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> workoutSetTemplateTableRefs<T extends Object>(
    Expression<T> Function($$WorkoutSetTemplateTableTableAnnotationComposer a)
    f,
  ) {
    final $$WorkoutSetTemplateTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.workoutSetTemplateTable,
          getReferencedColumn: (t) => t.workoutExerciseId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutSetTemplateTableTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutSetTemplateTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$WorkoutExerciseTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutExerciseTableTable,
          WorkoutExerciseTableData,
          $$WorkoutExerciseTableTableFilterComposer,
          $$WorkoutExerciseTableTableOrderingComposer,
          $$WorkoutExerciseTableTableAnnotationComposer,
          $$WorkoutExerciseTableTableCreateCompanionBuilder,
          $$WorkoutExerciseTableTableUpdateCompanionBuilder,
          (WorkoutExerciseTableData, $$WorkoutExerciseTableTableReferences),
          WorkoutExerciseTableData,
          PrefetchHooks Function({
            bool workoutId,
            bool exerciseId,
            bool scheduledWorkoutExerciseTableRefs,
            bool workoutSetTemplateTableRefs,
          })
        > {
  $$WorkoutExerciseTableTableTableManager(
    _$AppDatabase db,
    $WorkoutExerciseTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$WorkoutExerciseTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$WorkoutExerciseTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$WorkoutExerciseTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> workoutId = const Value.absent(),
                Value<int> exerciseId = const Value.absent(),
                Value<int> orderPosition = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> supersetGroupId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => WorkoutExerciseTableCompanion(
                id: id,
                workoutId: workoutId,
                exerciseId: exerciseId,
                orderPosition: orderPosition,
                notes: notes,
                supersetGroupId: supersetGroupId,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int workoutId,
                required int exerciseId,
                required int orderPosition,
                Value<String?> notes = const Value.absent(),
                Value<int?> supersetGroupId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => WorkoutExerciseTableCompanion.insert(
                id: id,
                workoutId: workoutId,
                exerciseId: exerciseId,
                orderPosition: orderPosition,
                notes: notes,
                supersetGroupId: supersetGroupId,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$WorkoutExerciseTableTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            workoutId = false,
            exerciseId = false,
            scheduledWorkoutExerciseTableRefs = false,
            workoutSetTemplateTableRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (scheduledWorkoutExerciseTableRefs)
                  db.scheduledWorkoutExerciseTable,
                if (workoutSetTemplateTableRefs) db.workoutSetTemplateTable,
              ],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (workoutId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.workoutId,
                            referencedTable:
                                $$WorkoutExerciseTableTableReferences
                                    ._workoutIdTable(db),
                            referencedColumn:
                                $$WorkoutExerciseTableTableReferences
                                    ._workoutIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (exerciseId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.exerciseId,
                            referencedTable:
                                $$WorkoutExerciseTableTableReferences
                                    ._exerciseIdTable(db),
                            referencedColumn:
                                $$WorkoutExerciseTableTableReferences
                                    ._exerciseIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (scheduledWorkoutExerciseTableRefs)
                    await $_getPrefetchedData<
                      WorkoutExerciseTableData,
                      $WorkoutExerciseTableTable,
                      ScheduledWorkoutExerciseTableData
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutExerciseTableTableReferences
                          ._scheduledWorkoutExerciseTableRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$WorkoutExerciseTableTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledWorkoutExerciseTableRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.workoutExerciseId == item.id,
                          ),
                      typedResults: items,
                    ),
                  if (workoutSetTemplateTableRefs)
                    await $_getPrefetchedData<
                      WorkoutExerciseTableData,
                      $WorkoutExerciseTableTable,
                      WorkoutSetTemplateData
                    >(
                      currentTable: table,
                      referencedTable: $$WorkoutExerciseTableTableReferences
                          ._workoutSetTemplateTableRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$WorkoutExerciseTableTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutSetTemplateTableRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.workoutExerciseId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutExerciseTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutExerciseTableTable,
      WorkoutExerciseTableData,
      $$WorkoutExerciseTableTableFilterComposer,
      $$WorkoutExerciseTableTableOrderingComposer,
      $$WorkoutExerciseTableTableAnnotationComposer,
      $$WorkoutExerciseTableTableCreateCompanionBuilder,
      $$WorkoutExerciseTableTableUpdateCompanionBuilder,
      (WorkoutExerciseTableData, $$WorkoutExerciseTableTableReferences),
      WorkoutExerciseTableData,
      PrefetchHooks Function({
        bool workoutId,
        bool exerciseId,
        bool scheduledWorkoutExerciseTableRefs,
        bool workoutSetTemplateTableRefs,
      })
    >;
typedef $$ScheduledWorkoutTableTableCreateCompanionBuilder =
    ScheduledWorkoutTableCompanion Function({
      Value<int> id,
      required int workoutId,
      Value<int?> workoutPlanId,
      Value<int?> templateWorkoutId,
      required DateTime scheduledDate,
      Value<DateTime> createdAt,
      Value<String?> notes,
      Value<bool> isCompleted,
      Value<bool> isSkipped,
      Value<String?> serverId,
      Value<int> syncStatus,
    });
typedef $$ScheduledWorkoutTableTableUpdateCompanionBuilder =
    ScheduledWorkoutTableCompanion Function({
      Value<int> id,
      Value<int> workoutId,
      Value<int?> workoutPlanId,
      Value<int?> templateWorkoutId,
      Value<DateTime> scheduledDate,
      Value<DateTime> createdAt,
      Value<String?> notes,
      Value<bool> isCompleted,
      Value<bool> isSkipped,
      Value<String?> serverId,
      Value<int> syncStatus,
    });

final class $$ScheduledWorkoutTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ScheduledWorkoutTableTable,
          ScheduledWorkoutTableData
        > {
  $$ScheduledWorkoutTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkoutTableTable _workoutIdTable(_$AppDatabase db) =>
      db.workoutTable.createAlias(
        $_aliasNameGenerator(
          db.scheduledWorkoutTable.workoutId,
          db.workoutTable.id,
        ),
      );

  $$WorkoutTableTableProcessedTableManager get workoutId {
    final $_column = $_itemColumn<int>('workout_id')!;

    final manager = $$WorkoutTableTableTableManager(
      $_db,
      $_db.workoutTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workoutIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkoutPlanTableTable _workoutPlanIdTable(_$AppDatabase db) =>
      db.workoutPlanTable.createAlias(
        $_aliasNameGenerator(
          db.scheduledWorkoutTable.workoutPlanId,
          db.workoutPlanTable.id,
        ),
      );

  $$WorkoutPlanTableTableProcessedTableManager? get workoutPlanId {
    final $_column = $_itemColumn<int>('workout_plan_id');
    if ($_column == null) return null;
    final manager = $$WorkoutPlanTableTableTableManager(
      $_db,
      $_db.workoutPlanTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workoutPlanIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkoutTableTable _templateWorkoutIdTable(_$AppDatabase db) =>
      db.workoutTable.createAlias(
        $_aliasNameGenerator(
          db.scheduledWorkoutTable.templateWorkoutId,
          db.workoutTable.id,
        ),
      );

  $$WorkoutTableTableProcessedTableManager? get templateWorkoutId {
    final $_column = $_itemColumn<int>('template_workout_id');
    if ($_column == null) return null;
    final manager = $$WorkoutTableTableTableManager(
      $_db,
      $_db.workoutTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_templateWorkoutIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $ScheduledWorkoutExerciseTableTable,
    List<ScheduledWorkoutExerciseTableData>
  >
  _scheduledWorkoutExerciseTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.scheduledWorkoutExerciseTable,
        aliasName: $_aliasNameGenerator(
          db.scheduledWorkoutTable.id,
          db.scheduledWorkoutExerciseTable.scheduledWorkoutId,
        ),
      );

  $$ScheduledWorkoutExerciseTableTableProcessedTableManager
  get scheduledWorkoutExerciseTableRefs {
    final manager = $$ScheduledWorkoutExerciseTableTableTableManager(
      $_db,
      $_db.scheduledWorkoutExerciseTable,
    ).filter(
      (f) => f.scheduledWorkoutId.id.sqlEquals($_itemColumn<int>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(
      _scheduledWorkoutExerciseTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ScheduledWorkoutTableTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledWorkoutTableTable> {
  $$ScheduledWorkoutTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSkipped => $composableBuilder(
    column: $table.isSkipped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutTableTableFilterComposer get workoutId {
    final $$WorkoutTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workoutTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkoutPlanTableTableFilterComposer get workoutPlanId {
    final $$WorkoutPlanTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutPlanId,
      referencedTable: $db.workoutPlanTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutPlanTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutPlanTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkoutTableTableFilterComposer get templateWorkoutId {
    final $$WorkoutTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateWorkoutId,
      referencedTable: $db.workoutTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> scheduledWorkoutExerciseTableRefs(
    Expression<bool> Function(
      $$ScheduledWorkoutExerciseTableTableFilterComposer f,
    )
    f,
  ) {
    final $$ScheduledWorkoutExerciseTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledWorkoutExerciseTable,
          getReferencedColumn: (t) => t.scheduledWorkoutId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutExerciseTableTableFilterComposer(
                $db: $db,
                $table: $db.scheduledWorkoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ScheduledWorkoutTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledWorkoutTableTable> {
  $$ScheduledWorkoutTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSkipped => $composableBuilder(
    column: $table.isSkipped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutTableTableOrderingComposer get workoutId {
    final $$WorkoutTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workoutTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutTableTableOrderingComposer(
            $db: $db,
            $table: $db.workoutTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkoutPlanTableTableOrderingComposer get workoutPlanId {
    final $$WorkoutPlanTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutPlanId,
      referencedTable: $db.workoutPlanTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutPlanTableTableOrderingComposer(
            $db: $db,
            $table: $db.workoutPlanTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkoutTableTableOrderingComposer get templateWorkoutId {
    final $$WorkoutTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateWorkoutId,
      referencedTable: $db.workoutTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutTableTableOrderingComposer(
            $db: $db,
            $table: $db.workoutTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ScheduledWorkoutTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledWorkoutTableTable> {
  $$ScheduledWorkoutTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledDate => $composableBuilder(
    column: $table.scheduledDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSkipped =>
      $composableBuilder(column: $table.isSkipped, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$WorkoutTableTableAnnotationComposer get workoutId {
    final $$WorkoutTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workoutTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutTableTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkoutPlanTableTableAnnotationComposer get workoutPlanId {
    final $$WorkoutPlanTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutPlanId,
      referencedTable: $db.workoutPlanTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutPlanTableTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutPlanTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkoutTableTableAnnotationComposer get templateWorkoutId {
    final $$WorkoutTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.templateWorkoutId,
      referencedTable: $db.workoutTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutTableTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> scheduledWorkoutExerciseTableRefs<T extends Object>(
    Expression<T> Function(
      $$ScheduledWorkoutExerciseTableTableAnnotationComposer a,
    )
    f,
  ) {
    final $$ScheduledWorkoutExerciseTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.scheduledWorkoutExerciseTable,
          getReferencedColumn: (t) => t.scheduledWorkoutId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutExerciseTableTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledWorkoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ScheduledWorkoutTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledWorkoutTableTable,
          ScheduledWorkoutTableData,
          $$ScheduledWorkoutTableTableFilterComposer,
          $$ScheduledWorkoutTableTableOrderingComposer,
          $$ScheduledWorkoutTableTableAnnotationComposer,
          $$ScheduledWorkoutTableTableCreateCompanionBuilder,
          $$ScheduledWorkoutTableTableUpdateCompanionBuilder,
          (ScheduledWorkoutTableData, $$ScheduledWorkoutTableTableReferences),
          ScheduledWorkoutTableData,
          PrefetchHooks Function({
            bool workoutId,
            bool workoutPlanId,
            bool templateWorkoutId,
            bool scheduledWorkoutExerciseTableRefs,
          })
        > {
  $$ScheduledWorkoutTableTableTableManager(
    _$AppDatabase db,
    $ScheduledWorkoutTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ScheduledWorkoutTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$ScheduledWorkoutTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$ScheduledWorkoutTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> workoutId = const Value.absent(),
                Value<int?> workoutPlanId = const Value.absent(),
                Value<int?> templateWorkoutId = const Value.absent(),
                Value<DateTime> scheduledDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<bool> isSkipped = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => ScheduledWorkoutTableCompanion(
                id: id,
                workoutId: workoutId,
                workoutPlanId: workoutPlanId,
                templateWorkoutId: templateWorkoutId,
                scheduledDate: scheduledDate,
                createdAt: createdAt,
                notes: notes,
                isCompleted: isCompleted,
                isSkipped: isSkipped,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int workoutId,
                Value<int?> workoutPlanId = const Value.absent(),
                Value<int?> templateWorkoutId = const Value.absent(),
                required DateTime scheduledDate,
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<bool> isSkipped = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => ScheduledWorkoutTableCompanion.insert(
                id: id,
                workoutId: workoutId,
                workoutPlanId: workoutPlanId,
                templateWorkoutId: templateWorkoutId,
                scheduledDate: scheduledDate,
                createdAt: createdAt,
                notes: notes,
                isCompleted: isCompleted,
                isSkipped: isSkipped,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$ScheduledWorkoutTableTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            workoutId = false,
            workoutPlanId = false,
            templateWorkoutId = false,
            scheduledWorkoutExerciseTableRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (scheduledWorkoutExerciseTableRefs)
                  db.scheduledWorkoutExerciseTable,
              ],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (workoutId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.workoutId,
                            referencedTable:
                                $$ScheduledWorkoutTableTableReferences
                                    ._workoutIdTable(db),
                            referencedColumn:
                                $$ScheduledWorkoutTableTableReferences
                                    ._workoutIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (workoutPlanId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.workoutPlanId,
                            referencedTable:
                                $$ScheduledWorkoutTableTableReferences
                                    ._workoutPlanIdTable(db),
                            referencedColumn:
                                $$ScheduledWorkoutTableTableReferences
                                    ._workoutPlanIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (templateWorkoutId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.templateWorkoutId,
                            referencedTable:
                                $$ScheduledWorkoutTableTableReferences
                                    ._templateWorkoutIdTable(db),
                            referencedColumn:
                                $$ScheduledWorkoutTableTableReferences
                                    ._templateWorkoutIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (scheduledWorkoutExerciseTableRefs)
                    await $_getPrefetchedData<
                      ScheduledWorkoutTableData,
                      $ScheduledWorkoutTableTable,
                      ScheduledWorkoutExerciseTableData
                    >(
                      currentTable: table,
                      referencedTable: $$ScheduledWorkoutTableTableReferences
                          ._scheduledWorkoutExerciseTableRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$ScheduledWorkoutTableTableReferences(
                                db,
                                table,
                                p0,
                              ).scheduledWorkoutExerciseTableRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.scheduledWorkoutId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ScheduledWorkoutTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledWorkoutTableTable,
      ScheduledWorkoutTableData,
      $$ScheduledWorkoutTableTableFilterComposer,
      $$ScheduledWorkoutTableTableOrderingComposer,
      $$ScheduledWorkoutTableTableAnnotationComposer,
      $$ScheduledWorkoutTableTableCreateCompanionBuilder,
      $$ScheduledWorkoutTableTableUpdateCompanionBuilder,
      (ScheduledWorkoutTableData, $$ScheduledWorkoutTableTableReferences),
      ScheduledWorkoutTableData,
      PrefetchHooks Function({
        bool workoutId,
        bool workoutPlanId,
        bool templateWorkoutId,
        bool scheduledWorkoutExerciseTableRefs,
      })
    >;
typedef $$ScheduledWorkoutExerciseTableTableCreateCompanionBuilder =
    ScheduledWorkoutExerciseTableCompanion Function({
      Value<int> id,
      required int scheduledWorkoutId,
      required int workoutExerciseId,
      Value<bool> isCompleted,
      Value<String?> notes,
      Value<int?> overrideExerciseId,
      Value<String?> serverId,
      Value<int> syncStatus,
    });
typedef $$ScheduledWorkoutExerciseTableTableUpdateCompanionBuilder =
    ScheduledWorkoutExerciseTableCompanion Function({
      Value<int> id,
      Value<int> scheduledWorkoutId,
      Value<int> workoutExerciseId,
      Value<bool> isCompleted,
      Value<String?> notes,
      Value<int?> overrideExerciseId,
      Value<String?> serverId,
      Value<int> syncStatus,
    });

final class $$ScheduledWorkoutExerciseTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ScheduledWorkoutExerciseTableTable,
          ScheduledWorkoutExerciseTableData
        > {
  $$ScheduledWorkoutExerciseTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ScheduledWorkoutTableTable _scheduledWorkoutIdTable(
    _$AppDatabase db,
  ) => db.scheduledWorkoutTable.createAlias(
    $_aliasNameGenerator(
      db.scheduledWorkoutExerciseTable.scheduledWorkoutId,
      db.scheduledWorkoutTable.id,
    ),
  );

  $$ScheduledWorkoutTableTableProcessedTableManager get scheduledWorkoutId {
    final $_column = $_itemColumn<int>('scheduled_workout_id')!;

    final manager = $$ScheduledWorkoutTableTableTableManager(
      $_db,
      $_db.scheduledWorkoutTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_scheduledWorkoutIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkoutExerciseTableTable _workoutExerciseIdTable(_$AppDatabase db) =>
      db.workoutExerciseTable.createAlias(
        $_aliasNameGenerator(
          db.scheduledWorkoutExerciseTable.workoutExerciseId,
          db.workoutExerciseTable.id,
        ),
      );

  $$WorkoutExerciseTableTableProcessedTableManager get workoutExerciseId {
    final $_column = $_itemColumn<int>('workout_exercise_id')!;

    final manager = $$WorkoutExerciseTableTableTableManager(
      $_db,
      $_db.workoutExerciseTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workoutExerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$WorkoutSetTableTable, List<WorkoutSetTableData>>
  _workoutSetTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.workoutSetTable,
    aliasName: $_aliasNameGenerator(
      db.scheduledWorkoutExerciseTable.id,
      db.workoutSetTable.scheduledWorkoutExerciseId,
    ),
  );

  $$WorkoutSetTableTableProcessedTableManager get workoutSetTableRefs {
    final manager = $$WorkoutSetTableTableTableManager(
      $_db,
      $_db.workoutSetTable,
    ).filter(
      (f) =>
          f.scheduledWorkoutExerciseId.id.sqlEquals($_itemColumn<int>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(
      _workoutSetTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ScheduledWorkoutExerciseTableTableFilterComposer
    extends Composer<_$AppDatabase, $ScheduledWorkoutExerciseTableTable> {
  $$ScheduledWorkoutExerciseTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get overrideExerciseId => $composableBuilder(
    column: $table.overrideExerciseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$ScheduledWorkoutTableTableFilterComposer get scheduledWorkoutId {
    final $$ScheduledWorkoutTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduledWorkoutId,
          referencedTable: $db.scheduledWorkoutTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutTableTableFilterComposer(
                $db: $db,
                $table: $db.scheduledWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$WorkoutExerciseTableTableFilterComposer get workoutExerciseId {
    final $$WorkoutExerciseTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutExerciseId,
      referencedTable: $db.workoutExerciseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutExerciseTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutExerciseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> workoutSetTableRefs(
    Expression<bool> Function($$WorkoutSetTableTableFilterComposer f) f,
  ) {
    final $$WorkoutSetTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSetTable,
      getReferencedColumn: (t) => t.scheduledWorkoutExerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutSetTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScheduledWorkoutExerciseTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ScheduledWorkoutExerciseTableTable> {
  $$ScheduledWorkoutExerciseTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get overrideExerciseId => $composableBuilder(
    column: $table.overrideExerciseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScheduledWorkoutTableTableOrderingComposer get scheduledWorkoutId {
    final $$ScheduledWorkoutTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduledWorkoutId,
          referencedTable: $db.scheduledWorkoutTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutTableTableOrderingComposer(
                $db: $db,
                $table: $db.scheduledWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$WorkoutExerciseTableTableOrderingComposer get workoutExerciseId {
    final $$WorkoutExerciseTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.workoutExerciseId,
          referencedTable: $db.workoutExerciseTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExerciseTableTableOrderingComposer(
                $db: $db,
                $table: $db.workoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ScheduledWorkoutExerciseTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScheduledWorkoutExerciseTableTable> {
  $$ScheduledWorkoutExerciseTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get overrideExerciseId => $composableBuilder(
    column: $table.overrideExerciseId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$ScheduledWorkoutTableTableAnnotationComposer get scheduledWorkoutId {
    final $$ScheduledWorkoutTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduledWorkoutId,
          referencedTable: $db.scheduledWorkoutTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutTableTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledWorkoutTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$WorkoutExerciseTableTableAnnotationComposer get workoutExerciseId {
    final $$WorkoutExerciseTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.workoutExerciseId,
          referencedTable: $db.workoutExerciseTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExerciseTableTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> workoutSetTableRefs<T extends Object>(
    Expression<T> Function($$WorkoutSetTableTableAnnotationComposer a) f,
  ) {
    final $$WorkoutSetTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.workoutSetTable,
      getReferencedColumn: (t) => t.scheduledWorkoutExerciseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutSetTableTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutSetTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ScheduledWorkoutExerciseTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScheduledWorkoutExerciseTableTable,
          ScheduledWorkoutExerciseTableData,
          $$ScheduledWorkoutExerciseTableTableFilterComposer,
          $$ScheduledWorkoutExerciseTableTableOrderingComposer,
          $$ScheduledWorkoutExerciseTableTableAnnotationComposer,
          $$ScheduledWorkoutExerciseTableTableCreateCompanionBuilder,
          $$ScheduledWorkoutExerciseTableTableUpdateCompanionBuilder,
          (
            ScheduledWorkoutExerciseTableData,
            $$ScheduledWorkoutExerciseTableTableReferences,
          ),
          ScheduledWorkoutExerciseTableData,
          PrefetchHooks Function({
            bool scheduledWorkoutId,
            bool workoutExerciseId,
            bool workoutSetTableRefs,
          })
        > {
  $$ScheduledWorkoutExerciseTableTableTableManager(
    _$AppDatabase db,
    $ScheduledWorkoutExerciseTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$ScheduledWorkoutExerciseTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$ScheduledWorkoutExerciseTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$ScheduledWorkoutExerciseTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> scheduledWorkoutId = const Value.absent(),
                Value<int> workoutExerciseId = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> overrideExerciseId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => ScheduledWorkoutExerciseTableCompanion(
                id: id,
                scheduledWorkoutId: scheduledWorkoutId,
                workoutExerciseId: workoutExerciseId,
                isCompleted: isCompleted,
                notes: notes,
                overrideExerciseId: overrideExerciseId,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int scheduledWorkoutId,
                required int workoutExerciseId,
                Value<bool> isCompleted = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> overrideExerciseId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => ScheduledWorkoutExerciseTableCompanion.insert(
                id: id,
                scheduledWorkoutId: scheduledWorkoutId,
                workoutExerciseId: workoutExerciseId,
                isCompleted: isCompleted,
                notes: notes,
                overrideExerciseId: overrideExerciseId,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$ScheduledWorkoutExerciseTableTableReferences(
                            db,
                            table,
                            e,
                          ),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({
            scheduledWorkoutId = false,
            workoutExerciseId = false,
            workoutSetTableRefs = false,
          }) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (workoutSetTableRefs) db.workoutSetTable,
              ],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (scheduledWorkoutId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.scheduledWorkoutId,
                            referencedTable:
                                $$ScheduledWorkoutExerciseTableTableReferences
                                    ._scheduledWorkoutIdTable(db),
                            referencedColumn:
                                $$ScheduledWorkoutExerciseTableTableReferences
                                    ._scheduledWorkoutIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (workoutExerciseId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.workoutExerciseId,
                            referencedTable:
                                $$ScheduledWorkoutExerciseTableTableReferences
                                    ._workoutExerciseIdTable(db),
                            referencedColumn:
                                $$ScheduledWorkoutExerciseTableTableReferences
                                    ._workoutExerciseIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (workoutSetTableRefs)
                    await $_getPrefetchedData<
                      ScheduledWorkoutExerciseTableData,
                      $ScheduledWorkoutExerciseTableTable,
                      WorkoutSetTableData
                    >(
                      currentTable: table,
                      referencedTable:
                          $$ScheduledWorkoutExerciseTableTableReferences
                              ._workoutSetTableRefsTable(db),
                      managerFromTypedResult:
                          (p0) =>
                              $$ScheduledWorkoutExerciseTableTableReferences(
                                db,
                                table,
                                p0,
                              ).workoutSetTableRefs,
                      referencedItemsForCurrentItem:
                          (item, referencedItems) => referencedItems.where(
                            (e) => e.scheduledWorkoutExerciseId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ScheduledWorkoutExerciseTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScheduledWorkoutExerciseTableTable,
      ScheduledWorkoutExerciseTableData,
      $$ScheduledWorkoutExerciseTableTableFilterComposer,
      $$ScheduledWorkoutExerciseTableTableOrderingComposer,
      $$ScheduledWorkoutExerciseTableTableAnnotationComposer,
      $$ScheduledWorkoutExerciseTableTableCreateCompanionBuilder,
      $$ScheduledWorkoutExerciseTableTableUpdateCompanionBuilder,
      (
        ScheduledWorkoutExerciseTableData,
        $$ScheduledWorkoutExerciseTableTableReferences,
      ),
      ScheduledWorkoutExerciseTableData,
      PrefetchHooks Function({
        bool scheduledWorkoutId,
        bool workoutExerciseId,
        bool workoutSetTableRefs,
      })
    >;
typedef $$WorkoutSetTableTableCreateCompanionBuilder =
    WorkoutSetTableCompanion Function({
      Value<int> id,
      required int scheduledWorkoutExerciseId,
      required int setNumber,
      Value<int?> reps,
      Value<double?> weight,
      Value<String?> weightUnit,
      Value<int?> durationSeconds,
      Value<bool> isCompleted,
      Value<String?> notes,
      Value<String?> serverId,
      Value<int> syncStatus,
      Value<int?> rpe,
      Value<int> setType,
      Value<int> side,
    });
typedef $$WorkoutSetTableTableUpdateCompanionBuilder =
    WorkoutSetTableCompanion Function({
      Value<int> id,
      Value<int> scheduledWorkoutExerciseId,
      Value<int> setNumber,
      Value<int?> reps,
      Value<double?> weight,
      Value<String?> weightUnit,
      Value<int?> durationSeconds,
      Value<bool> isCompleted,
      Value<String?> notes,
      Value<String?> serverId,
      Value<int> syncStatus,
      Value<int?> rpe,
      Value<int> setType,
      Value<int> side,
    });

final class $$WorkoutSetTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorkoutSetTableTable,
          WorkoutSetTableData
        > {
  $$WorkoutSetTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ScheduledWorkoutExerciseTableTable _scheduledWorkoutExerciseIdTable(
    _$AppDatabase db,
  ) => db.scheduledWorkoutExerciseTable.createAlias(
    $_aliasNameGenerator(
      db.workoutSetTable.scheduledWorkoutExerciseId,
      db.scheduledWorkoutExerciseTable.id,
    ),
  );

  $$ScheduledWorkoutExerciseTableTableProcessedTableManager
  get scheduledWorkoutExerciseId {
    final $_column = $_itemColumn<int>('scheduled_workout_exercise_id')!;

    final manager = $$ScheduledWorkoutExerciseTableTableTableManager(
      $_db,
      $_db.scheduledWorkoutExerciseTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _scheduledWorkoutExerciseIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkoutSetTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSetTableTable> {
  $$WorkoutSetTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setNumber => $composableBuilder(
    column: $table.setNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weightUnit => $composableBuilder(
    column: $table.weightUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rpe => $composableBuilder(
    column: $table.rpe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setType => $composableBuilder(
    column: $table.setType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnFilters(column),
  );

  $$ScheduledWorkoutExerciseTableTableFilterComposer
  get scheduledWorkoutExerciseId {
    final $$ScheduledWorkoutExerciseTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduledWorkoutExerciseId,
          referencedTable: $db.scheduledWorkoutExerciseTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutExerciseTableTableFilterComposer(
                $db: $db,
                $table: $db.scheduledWorkoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$WorkoutSetTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSetTableTable> {
  $$WorkoutSetTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setNumber => $composableBuilder(
    column: $table.setNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reps => $composableBuilder(
    column: $table.reps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weightUnit => $composableBuilder(
    column: $table.weightUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rpe => $composableBuilder(
    column: $table.rpe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setType => $composableBuilder(
    column: $table.setType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get side => $composableBuilder(
    column: $table.side,
    builder: (column) => ColumnOrderings(column),
  );

  $$ScheduledWorkoutExerciseTableTableOrderingComposer
  get scheduledWorkoutExerciseId {
    final $$ScheduledWorkoutExerciseTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduledWorkoutExerciseId,
          referencedTable: $db.scheduledWorkoutExerciseTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutExerciseTableTableOrderingComposer(
                $db: $db,
                $table: $db.scheduledWorkoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$WorkoutSetTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSetTableTable> {
  $$WorkoutSetTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get setNumber =>
      $composableBuilder(column: $table.setNumber, builder: (column) => column);

  GeneratedColumn<int> get reps =>
      $composableBuilder(column: $table.reps, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<String> get weightUnit => $composableBuilder(
    column: $table.weightUnit,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rpe =>
      $composableBuilder(column: $table.rpe, builder: (column) => column);

  GeneratedColumn<int> get setType =>
      $composableBuilder(column: $table.setType, builder: (column) => column);

  GeneratedColumn<int> get side =>
      $composableBuilder(column: $table.side, builder: (column) => column);

  $$ScheduledWorkoutExerciseTableTableAnnotationComposer
  get scheduledWorkoutExerciseId {
    final $$ScheduledWorkoutExerciseTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.scheduledWorkoutExerciseId,
          referencedTable: $db.scheduledWorkoutExerciseTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ScheduledWorkoutExerciseTableTableAnnotationComposer(
                $db: $db,
                $table: $db.scheduledWorkoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$WorkoutSetTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSetTableTable,
          WorkoutSetTableData,
          $$WorkoutSetTableTableFilterComposer,
          $$WorkoutSetTableTableOrderingComposer,
          $$WorkoutSetTableTableAnnotationComposer,
          $$WorkoutSetTableTableCreateCompanionBuilder,
          $$WorkoutSetTableTableUpdateCompanionBuilder,
          (WorkoutSetTableData, $$WorkoutSetTableTableReferences),
          WorkoutSetTableData,
          PrefetchHooks Function({bool scheduledWorkoutExerciseId})
        > {
  $$WorkoutSetTableTableTableManager(
    _$AppDatabase db,
    $WorkoutSetTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$WorkoutSetTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$WorkoutSetTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$WorkoutSetTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> scheduledWorkoutExerciseId = const Value.absent(),
                Value<int> setNumber = const Value.absent(),
                Value<int?> reps = const Value.absent(),
                Value<double?> weight = const Value.absent(),
                Value<String?> weightUnit = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int?> rpe = const Value.absent(),
                Value<int> setType = const Value.absent(),
                Value<int> side = const Value.absent(),
              }) => WorkoutSetTableCompanion(
                id: id,
                scheduledWorkoutExerciseId: scheduledWorkoutExerciseId,
                setNumber: setNumber,
                reps: reps,
                weight: weight,
                weightUnit: weightUnit,
                durationSeconds: durationSeconds,
                isCompleted: isCompleted,
                notes: notes,
                serverId: serverId,
                syncStatus: syncStatus,
                rpe: rpe,
                setType: setType,
                side: side,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int scheduledWorkoutExerciseId,
                required int setNumber,
                Value<int?> reps = const Value.absent(),
                Value<double?> weight = const Value.absent(),
                Value<String?> weightUnit = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
                Value<int?> rpe = const Value.absent(),
                Value<int> setType = const Value.absent(),
                Value<int> side = const Value.absent(),
              }) => WorkoutSetTableCompanion.insert(
                id: id,
                scheduledWorkoutExerciseId: scheduledWorkoutExerciseId,
                setNumber: setNumber,
                reps: reps,
                weight: weight,
                weightUnit: weightUnit,
                durationSeconds: durationSeconds,
                isCompleted: isCompleted,
                notes: notes,
                serverId: serverId,
                syncStatus: syncStatus,
                rpe: rpe,
                setType: setType,
                side: side,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$WorkoutSetTableTableReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({scheduledWorkoutExerciseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (scheduledWorkoutExerciseId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.scheduledWorkoutExerciseId,
                            referencedTable: $$WorkoutSetTableTableReferences
                                ._scheduledWorkoutExerciseIdTable(db),
                            referencedColumn:
                                $$WorkoutSetTableTableReferences
                                    ._scheduledWorkoutExerciseIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutSetTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSetTableTable,
      WorkoutSetTableData,
      $$WorkoutSetTableTableFilterComposer,
      $$WorkoutSetTableTableOrderingComposer,
      $$WorkoutSetTableTableAnnotationComposer,
      $$WorkoutSetTableTableCreateCompanionBuilder,
      $$WorkoutSetTableTableUpdateCompanionBuilder,
      (WorkoutSetTableData, $$WorkoutSetTableTableReferences),
      WorkoutSetTableData,
      PrefetchHooks Function({bool scheduledWorkoutExerciseId})
    >;
typedef $$WorkoutPlanWorkoutTableTableCreateCompanionBuilder =
    WorkoutPlanWorkoutTableCompanion Function({
      Value<int> id,
      required int planId,
      required int workoutId,
      Value<String?> serverId,
      Value<int> syncStatus,
    });
typedef $$WorkoutPlanWorkoutTableTableUpdateCompanionBuilder =
    WorkoutPlanWorkoutTableCompanion Function({
      Value<int> id,
      Value<int> planId,
      Value<int> workoutId,
      Value<String?> serverId,
      Value<int> syncStatus,
    });

final class $$WorkoutPlanWorkoutTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorkoutPlanWorkoutTableTable,
          WorkoutPlanWorkoutTableData
        > {
  $$WorkoutPlanWorkoutTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkoutPlanTableTable _planIdTable(_$AppDatabase db) =>
      db.workoutPlanTable.createAlias(
        $_aliasNameGenerator(
          db.workoutPlanWorkoutTable.planId,
          db.workoutPlanTable.id,
        ),
      );

  $$WorkoutPlanTableTableProcessedTableManager get planId {
    final $_column = $_itemColumn<int>('plan_id')!;

    final manager = $$WorkoutPlanTableTableTableManager(
      $_db,
      $_db.workoutPlanTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $WorkoutTableTable _workoutIdTable(_$AppDatabase db) =>
      db.workoutTable.createAlias(
        $_aliasNameGenerator(
          db.workoutPlanWorkoutTable.workoutId,
          db.workoutTable.id,
        ),
      );

  $$WorkoutTableTableProcessedTableManager get workoutId {
    final $_column = $_itemColumn<int>('workout_id')!;

    final manager = $$WorkoutTableTableTableManager(
      $_db,
      $_db.workoutTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workoutIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkoutPlanWorkoutTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutPlanWorkoutTableTable> {
  $$WorkoutPlanWorkoutTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutPlanTableTableFilterComposer get planId {
    final $$WorkoutPlanTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.workoutPlanTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutPlanTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutPlanTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkoutTableTableFilterComposer get workoutId {
    final $$WorkoutTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workoutTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutPlanWorkoutTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutPlanWorkoutTableTable> {
  $$WorkoutPlanWorkoutTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutPlanTableTableOrderingComposer get planId {
    final $$WorkoutPlanTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.workoutPlanTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutPlanTableTableOrderingComposer(
            $db: $db,
            $table: $db.workoutPlanTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkoutTableTableOrderingComposer get workoutId {
    final $$WorkoutTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workoutTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutTableTableOrderingComposer(
            $db: $db,
            $table: $db.workoutTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutPlanWorkoutTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutPlanWorkoutTableTable> {
  $$WorkoutPlanWorkoutTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$WorkoutPlanTableTableAnnotationComposer get planId {
    final $$WorkoutPlanTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.workoutPlanTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutPlanTableTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutPlanTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$WorkoutTableTableAnnotationComposer get workoutId {
    final $$WorkoutTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutId,
      referencedTable: $db.workoutTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutTableTableAnnotationComposer(
            $db: $db,
            $table: $db.workoutTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutPlanWorkoutTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutPlanWorkoutTableTable,
          WorkoutPlanWorkoutTableData,
          $$WorkoutPlanWorkoutTableTableFilterComposer,
          $$WorkoutPlanWorkoutTableTableOrderingComposer,
          $$WorkoutPlanWorkoutTableTableAnnotationComposer,
          $$WorkoutPlanWorkoutTableTableCreateCompanionBuilder,
          $$WorkoutPlanWorkoutTableTableUpdateCompanionBuilder,
          (
            WorkoutPlanWorkoutTableData,
            $$WorkoutPlanWorkoutTableTableReferences,
          ),
          WorkoutPlanWorkoutTableData,
          PrefetchHooks Function({bool planId, bool workoutId})
        > {
  $$WorkoutPlanWorkoutTableTableTableManager(
    _$AppDatabase db,
    $WorkoutPlanWorkoutTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$WorkoutPlanWorkoutTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$WorkoutPlanWorkoutTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$WorkoutPlanWorkoutTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> planId = const Value.absent(),
                Value<int> workoutId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => WorkoutPlanWorkoutTableCompanion(
                id: id,
                planId: planId,
                workoutId: workoutId,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int planId,
                required int workoutId,
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => WorkoutPlanWorkoutTableCompanion.insert(
                id: id,
                planId: planId,
                workoutId: workoutId,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$WorkoutPlanWorkoutTableTableReferences(
                            db,
                            table,
                            e,
                          ),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({planId = false, workoutId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (planId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.planId,
                            referencedTable:
                                $$WorkoutPlanWorkoutTableTableReferences
                                    ._planIdTable(db),
                            referencedColumn:
                                $$WorkoutPlanWorkoutTableTableReferences
                                    ._planIdTable(db)
                                    .id,
                          )
                          as T;
                }
                if (workoutId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.workoutId,
                            referencedTable:
                                $$WorkoutPlanWorkoutTableTableReferences
                                    ._workoutIdTable(db),
                            referencedColumn:
                                $$WorkoutPlanWorkoutTableTableReferences
                                    ._workoutIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutPlanWorkoutTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutPlanWorkoutTableTable,
      WorkoutPlanWorkoutTableData,
      $$WorkoutPlanWorkoutTableTableFilterComposer,
      $$WorkoutPlanWorkoutTableTableOrderingComposer,
      $$WorkoutPlanWorkoutTableTableAnnotationComposer,
      $$WorkoutPlanWorkoutTableTableCreateCompanionBuilder,
      $$WorkoutPlanWorkoutTableTableUpdateCompanionBuilder,
      (WorkoutPlanWorkoutTableData, $$WorkoutPlanWorkoutTableTableReferences),
      WorkoutPlanWorkoutTableData,
      PrefetchHooks Function({bool planId, bool workoutId})
    >;
typedef $$WorkoutSetTemplateTableTableCreateCompanionBuilder =
    WorkoutSetTemplateTableCompanion Function({
      Value<int> id,
      required int workoutExerciseId,
      required int setNumber,
      required String targetReps,
      required int orderPosition,
      Value<String?> serverId,
      Value<int> syncStatus,
    });
typedef $$WorkoutSetTemplateTableTableUpdateCompanionBuilder =
    WorkoutSetTemplateTableCompanion Function({
      Value<int> id,
      Value<int> workoutExerciseId,
      Value<int> setNumber,
      Value<String> targetReps,
      Value<int> orderPosition,
      Value<String?> serverId,
      Value<int> syncStatus,
    });

final class $$WorkoutSetTemplateTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $WorkoutSetTemplateTableTable,
          WorkoutSetTemplateData
        > {
  $$WorkoutSetTemplateTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $WorkoutExerciseTableTable _workoutExerciseIdTable(_$AppDatabase db) =>
      db.workoutExerciseTable.createAlias(
        $_aliasNameGenerator(
          db.workoutSetTemplateTable.workoutExerciseId,
          db.workoutExerciseTable.id,
        ),
      );

  $$WorkoutExerciseTableTableProcessedTableManager get workoutExerciseId {
    final $_column = $_itemColumn<int>('workout_exercise_id')!;

    final manager = $$WorkoutExerciseTableTableTableManager(
      $_db,
      $_db.workoutExerciseTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_workoutExerciseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$WorkoutSetTemplateTableTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutSetTemplateTableTable> {
  $$WorkoutSetTemplateTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get setNumber => $composableBuilder(
    column: $table.setNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderPosition => $composableBuilder(
    column: $table.orderPosition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$WorkoutExerciseTableTableFilterComposer get workoutExerciseId {
    final $$WorkoutExerciseTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.workoutExerciseId,
      referencedTable: $db.workoutExerciseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$WorkoutExerciseTableTableFilterComposer(
            $db: $db,
            $table: $db.workoutExerciseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$WorkoutSetTemplateTableTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutSetTemplateTableTable> {
  $$WorkoutSetTemplateTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get setNumber => $composableBuilder(
    column: $table.setNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderPosition => $composableBuilder(
    column: $table.orderPosition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$WorkoutExerciseTableTableOrderingComposer get workoutExerciseId {
    final $$WorkoutExerciseTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.workoutExerciseId,
          referencedTable: $db.workoutExerciseTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExerciseTableTableOrderingComposer(
                $db: $db,
                $table: $db.workoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$WorkoutSetTemplateTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutSetTemplateTableTable> {
  $$WorkoutSetTemplateTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get setNumber =>
      $composableBuilder(column: $table.setNumber, builder: (column) => column);

  GeneratedColumn<String> get targetReps => $composableBuilder(
    column: $table.targetReps,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderPosition => $composableBuilder(
    column: $table.orderPosition,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<int> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$WorkoutExerciseTableTableAnnotationComposer get workoutExerciseId {
    final $$WorkoutExerciseTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.workoutExerciseId,
          referencedTable: $db.workoutExerciseTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$WorkoutExerciseTableTableAnnotationComposer(
                $db: $db,
                $table: $db.workoutExerciseTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$WorkoutSetTemplateTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WorkoutSetTemplateTableTable,
          WorkoutSetTemplateData,
          $$WorkoutSetTemplateTableTableFilterComposer,
          $$WorkoutSetTemplateTableTableOrderingComposer,
          $$WorkoutSetTemplateTableTableAnnotationComposer,
          $$WorkoutSetTemplateTableTableCreateCompanionBuilder,
          $$WorkoutSetTemplateTableTableUpdateCompanionBuilder,
          (WorkoutSetTemplateData, $$WorkoutSetTemplateTableTableReferences),
          WorkoutSetTemplateData,
          PrefetchHooks Function({bool workoutExerciseId})
        > {
  $$WorkoutSetTemplateTableTableTableManager(
    _$AppDatabase db,
    $WorkoutSetTemplateTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () => $$WorkoutSetTemplateTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer:
              () => $$WorkoutSetTemplateTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$WorkoutSetTemplateTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> workoutExerciseId = const Value.absent(),
                Value<int> setNumber = const Value.absent(),
                Value<String> targetReps = const Value.absent(),
                Value<int> orderPosition = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => WorkoutSetTemplateTableCompanion(
                id: id,
                workoutExerciseId: workoutExerciseId,
                setNumber: setNumber,
                targetReps: targetReps,
                orderPosition: orderPosition,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int workoutExerciseId,
                required int setNumber,
                required String targetReps,
                required int orderPosition,
                Value<String?> serverId = const Value.absent(),
                Value<int> syncStatus = const Value.absent(),
              }) => WorkoutSetTemplateTableCompanion.insert(
                id: id,
                workoutExerciseId: workoutExerciseId,
                setNumber: setNumber,
                targetReps: targetReps,
                orderPosition: orderPosition,
                serverId: serverId,
                syncStatus: syncStatus,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          $$WorkoutSetTemplateTableTableReferences(
                            db,
                            table,
                            e,
                          ),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: ({workoutExerciseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                T extends TableManagerState<
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic,
                  dynamic
                >
              >(state) {
                if (workoutExerciseId) {
                  state =
                      state.withJoin(
                            currentTable: table,
                            currentColumn: table.workoutExerciseId,
                            referencedTable:
                                $$WorkoutSetTemplateTableTableReferences
                                    ._workoutExerciseIdTable(db),
                            referencedColumn:
                                $$WorkoutSetTemplateTableTableReferences
                                    ._workoutExerciseIdTable(db)
                                    .id,
                          )
                          as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$WorkoutSetTemplateTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WorkoutSetTemplateTableTable,
      WorkoutSetTemplateData,
      $$WorkoutSetTemplateTableTableFilterComposer,
      $$WorkoutSetTemplateTableTableOrderingComposer,
      $$WorkoutSetTemplateTableTableAnnotationComposer,
      $$WorkoutSetTemplateTableTableCreateCompanionBuilder,
      $$WorkoutSetTemplateTableTableUpdateCompanionBuilder,
      (WorkoutSetTemplateData, $$WorkoutSetTemplateTableTableReferences),
      WorkoutSetTemplateData,
      PrefetchHooks Function({bool workoutExerciseId})
    >;
typedef $$ChatOutBoxTableTableCreateCompanionBuilder =
    ChatOutBoxTableCompanion Function({
      required String messageId,
      required String otherPartyId,
      required String body,
      required DateTime createdAt,
      Value<int> chatMessageStatus,
      Value<int> rowid,
    });
typedef $$ChatOutBoxTableTableUpdateCompanionBuilder =
    ChatOutBoxTableCompanion Function({
      Value<String> messageId,
      Value<String> otherPartyId,
      Value<String> body,
      Value<DateTime> createdAt,
      Value<int> chatMessageStatus,
      Value<int> rowid,
    });

class $$ChatOutBoxTableTableFilterComposer
    extends Composer<_$AppDatabase, $ChatOutBoxTableTable> {
  $$ChatOutBoxTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get otherPartyId => $composableBuilder(
    column: $table.otherPartyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chatMessageStatus => $composableBuilder(
    column: $table.chatMessageStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatOutBoxTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatOutBoxTableTable> {
  $$ChatOutBoxTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get otherPartyId => $composableBuilder(
    column: $table.otherPartyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chatMessageStatus => $composableBuilder(
    column: $table.chatMessageStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatOutBoxTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatOutBoxTableTable> {
  $$ChatOutBoxTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get otherPartyId => $composableBuilder(
    column: $table.otherPartyId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get chatMessageStatus => $composableBuilder(
    column: $table.chatMessageStatus,
    builder: (column) => column,
  );
}

class $$ChatOutBoxTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatOutBoxTableTable,
          ChatOutBoxTableData,
          $$ChatOutBoxTableTableFilterComposer,
          $$ChatOutBoxTableTableOrderingComposer,
          $$ChatOutBoxTableTableAnnotationComposer,
          $$ChatOutBoxTableTableCreateCompanionBuilder,
          $$ChatOutBoxTableTableUpdateCompanionBuilder,
          (
            ChatOutBoxTableData,
            BaseReferences<
              _$AppDatabase,
              $ChatOutBoxTableTable,
              ChatOutBoxTableData
            >,
          ),
          ChatOutBoxTableData,
          PrefetchHooks Function()
        > {
  $$ChatOutBoxTableTableTableManager(
    _$AppDatabase db,
    $ChatOutBoxTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$ChatOutBoxTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$ChatOutBoxTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$ChatOutBoxTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> otherPartyId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> chatMessageStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatOutBoxTableCompanion(
                messageId: messageId,
                otherPartyId: otherPartyId,
                body: body,
                createdAt: createdAt,
                chatMessageStatus: chatMessageStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String otherPartyId,
                required String body,
                required DateTime createdAt,
                Value<int> chatMessageStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatOutBoxTableCompanion.insert(
                messageId: messageId,
                otherPartyId: otherPartyId,
                body: body,
                createdAt: createdAt,
                chatMessageStatus: chatMessageStatus,
                rowid: rowid,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatOutBoxTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatOutBoxTableTable,
      ChatOutBoxTableData,
      $$ChatOutBoxTableTableFilterComposer,
      $$ChatOutBoxTableTableOrderingComposer,
      $$ChatOutBoxTableTableAnnotationComposer,
      $$ChatOutBoxTableTableCreateCompanionBuilder,
      $$ChatOutBoxTableTableUpdateCompanionBuilder,
      (
        ChatOutBoxTableData,
        BaseReferences<
          _$AppDatabase,
          $ChatOutBoxTableTable,
          ChatOutBoxTableData
        >,
      ),
      ChatOutBoxTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoodItemTableTableManager get foodItem =>
      $$FoodItemTableTableManager(_db, _db.foodItem);
  $$VerifiedFoodTableTableTableManager get verifiedFoodTable =>
      $$VerifiedFoodTableTableTableManager(_db, _db.verifiedFoodTable);
  $$UserSettingsTableTableManager get userSettings =>
      $$UserSettingsTableTableManager(_db, _db.userSettings);
  $$MealTableTableTableManager get mealTable =>
      $$MealTableTableTableManager(_db, _db.mealTable);
  $$MealFoodTableTableTableManager get mealFoodTable =>
      $$MealFoodTableTableTableManager(_db, _db.mealFoodTable);
  $$SearchCacheTableTableTableManager get searchCacheTable =>
      $$SearchCacheTableTableTableManager(_db, _db.searchCacheTable);
  $$WeightRecordTableTableManager get weightRecord =>
      $$WeightRecordTableTableManager(_db, _db.weightRecord);
  $$ExerciseTableTableTableManager get exerciseTable =>
      $$ExerciseTableTableTableManager(_db, _db.exerciseTable);
  $$WorkoutTableTableTableManager get workoutTable =>
      $$WorkoutTableTableTableManager(_db, _db.workoutTable);
  $$WorkoutPlanTableTableTableManager get workoutPlanTable =>
      $$WorkoutPlanTableTableTableManager(_db, _db.workoutPlanTable);
  $$WorkoutExerciseTableTableTableManager get workoutExerciseTable =>
      $$WorkoutExerciseTableTableTableManager(_db, _db.workoutExerciseTable);
  $$ScheduledWorkoutTableTableTableManager get scheduledWorkoutTable =>
      $$ScheduledWorkoutTableTableTableManager(_db, _db.scheduledWorkoutTable);
  $$ScheduledWorkoutExerciseTableTableTableManager
  get scheduledWorkoutExerciseTable =>
      $$ScheduledWorkoutExerciseTableTableTableManager(
        _db,
        _db.scheduledWorkoutExerciseTable,
      );
  $$WorkoutSetTableTableTableManager get workoutSetTable =>
      $$WorkoutSetTableTableTableManager(_db, _db.workoutSetTable);
  $$WorkoutPlanWorkoutTableTableTableManager get workoutPlanWorkoutTable =>
      $$WorkoutPlanWorkoutTableTableTableManager(
        _db,
        _db.workoutPlanWorkoutTable,
      );
  $$WorkoutSetTemplateTableTableTableManager get workoutSetTemplateTable =>
      $$WorkoutSetTemplateTableTableTableManager(
        _db,
        _db.workoutSetTemplateTable,
      );
  $$ChatOutBoxTableTableTableManager get chatOutBoxTable =>
      $$ChatOutBoxTableTableTableManager(_db, _db.chatOutBoxTable);
}
