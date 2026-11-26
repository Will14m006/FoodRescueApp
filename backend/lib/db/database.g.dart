// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 3,
      maxTextLength: 254,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _passwordHashMeta = const VerificationMeta(
    'passwordHash',
  );
  @override
  late final GeneratedColumn<String> passwordHash = GeneratedColumn<String>(
    'password_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 120,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<UserRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<UserRole>($UsersTable.$converterrole);
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
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    email,
    passwordHash,
    name,
    role,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(
    Insertable<User> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('password_hash')) {
      context.handle(
        _passwordHashMeta,
        passwordHash.isAcceptableOrUnknown(
          data['password_hash']!,
          _passwordHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordHashMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      passwordHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}password_hash'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      role: $UsersTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<UserRole, String, String> $converterrole =
      const EnumNameConverter<UserRole>(UserRole.values);
}

class User extends DataClass implements Insertable<User> {
  final int id;
  final String email;
  final String passwordHash;
  final String name;
  final UserRole role;
  final DateTime createdAt;
  const User({
    required this.id,
    required this.email,
    required this.passwordHash,
    required this.name,
    required this.role,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['email'] = Variable<String>(email);
    map['password_hash'] = Variable<String>(passwordHash);
    map['name'] = Variable<String>(name);
    {
      map['role'] = Variable<String>($UsersTable.$converterrole.toSql(role));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      email: Value(email),
      passwordHash: Value(passwordHash),
      name: Value(name),
      role: Value(role),
      createdAt: Value(createdAt),
    );
  }

  factory User.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<int>(json['id']),
      email: serializer.fromJson<String>(json['email']),
      passwordHash: serializer.fromJson<String>(json['passwordHash']),
      name: serializer.fromJson<String>(json['name']),
      role: $UsersTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'email': serializer.toJson<String>(email),
      'passwordHash': serializer.toJson<String>(passwordHash),
      'name': serializer.toJson<String>(name),
      'role': serializer.toJson<String>(
        $UsersTable.$converterrole.toJson(role),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  User copyWith({
    int? id,
    String? email,
    String? passwordHash,
    String? name,
    UserRole? role,
    DateTime? createdAt,
  }) => User(
    id: id ?? this.id,
    email: email ?? this.email,
    passwordHash: passwordHash ?? this.passwordHash,
    name: name ?? this.name,
    role: role ?? this.role,
    createdAt: createdAt ?? this.createdAt,
  );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      email: data.email.present ? data.email.value : this.email,
      passwordHash: data.passwordHash.present
          ? data.passwordHash.value
          : this.passwordHash,
      name: data.name.present ? data.name.value : this.name,
      role: data.role.present ? data.role.value : this.role,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('name: $name, ')
          ..write('role: $role, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, email, passwordHash, name, role, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.email == this.email &&
          other.passwordHash == this.passwordHash &&
          other.name == this.name &&
          other.role == this.role &&
          other.createdAt == this.createdAt);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<int> id;
  final Value<String> email;
  final Value<String> passwordHash;
  final Value<String> name;
  final Value<UserRole> role;
  final Value<DateTime> createdAt;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.email = const Value.absent(),
    this.passwordHash = const Value.absent(),
    this.name = const Value.absent(),
    this.role = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UsersCompanion.insert({
    this.id = const Value.absent(),
    required String email,
    required String passwordHash,
    required String name,
    required UserRole role,
    this.createdAt = const Value.absent(),
  }) : email = Value(email),
       passwordHash = Value(passwordHash),
       name = Value(name),
       role = Value(role);
  static Insertable<User> custom({
    Expression<int>? id,
    Expression<String>? email,
    Expression<String>? passwordHash,
    Expression<String>? name,
    Expression<String>? role,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (email != null) 'email': email,
      if (passwordHash != null) 'password_hash': passwordHash,
      if (name != null) 'name': name,
      if (role != null) 'role': role,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UsersCompanion copyWith({
    Value<int>? id,
    Value<String>? email,
    Value<String>? passwordHash,
    Value<String>? name,
    Value<UserRole>? role,
    Value<DateTime>? createdAt,
  }) {
    return UsersCompanion(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      name: name ?? this.name,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (passwordHash.present) {
      map['password_hash'] = Variable<String>(passwordHash.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $UsersTable.$converterrole.toSql(role.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('email: $email, ')
          ..write('passwordHash: $passwordHash, ')
          ..write('name: $name, ')
          ..write('role: $role, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MerchantsTable extends Merchants
    with TableInfo<$MerchantsTable, Merchant> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MerchantsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _storeNameMeta = const VerificationMeta(
    'storeName',
  );
  @override
  late final GeneratedColumn<String> storeName = GeneratedColumn<String>(
    'store_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 160,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownerIdMeta = const VerificationMeta(
    'ownerId',
  );
  @override
  late final GeneratedColumn<int> ownerId = GeneratedColumn<int>(
    'owner_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, storeName, ownerId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'merchants';
  @override
  VerificationContext validateIntegrity(
    Insertable<Merchant> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('store_name')) {
      context.handle(
        _storeNameMeta,
        storeName.isAcceptableOrUnknown(data['store_name']!, _storeNameMeta),
      );
    } else if (isInserting) {
      context.missing(_storeNameMeta);
    }
    if (data.containsKey('owner_id')) {
      context.handle(
        _ownerIdMeta,
        ownerId.isAcceptableOrUnknown(data['owner_id']!, _ownerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ownerIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {ownerId},
  ];
  @override
  Merchant map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Merchant(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      storeName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}store_name'],
      )!,
      ownerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}owner_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MerchantsTable createAlias(String alias) {
    return $MerchantsTable(attachedDatabase, alias);
  }
}

class Merchant extends DataClass implements Insertable<Merchant> {
  final int id;
  final String storeName;
  final int ownerId;
  final DateTime createdAt;
  const Merchant({
    required this.id,
    required this.storeName,
    required this.ownerId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['store_name'] = Variable<String>(storeName);
    map['owner_id'] = Variable<int>(ownerId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MerchantsCompanion toCompanion(bool nullToAbsent) {
    return MerchantsCompanion(
      id: Value(id),
      storeName: Value(storeName),
      ownerId: Value(ownerId),
      createdAt: Value(createdAt),
    );
  }

  factory Merchant.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Merchant(
      id: serializer.fromJson<int>(json['id']),
      storeName: serializer.fromJson<String>(json['storeName']),
      ownerId: serializer.fromJson<int>(json['ownerId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'storeName': serializer.toJson<String>(storeName),
      'ownerId': serializer.toJson<int>(ownerId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Merchant copyWith({
    int? id,
    String? storeName,
    int? ownerId,
    DateTime? createdAt,
  }) => Merchant(
    id: id ?? this.id,
    storeName: storeName ?? this.storeName,
    ownerId: ownerId ?? this.ownerId,
    createdAt: createdAt ?? this.createdAt,
  );
  Merchant copyWithCompanion(MerchantsCompanion data) {
    return Merchant(
      id: data.id.present ? data.id.value : this.id,
      storeName: data.storeName.present ? data.storeName.value : this.storeName,
      ownerId: data.ownerId.present ? data.ownerId.value : this.ownerId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Merchant(')
          ..write('id: $id, ')
          ..write('storeName: $storeName, ')
          ..write('ownerId: $ownerId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, storeName, ownerId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Merchant &&
          other.id == this.id &&
          other.storeName == this.storeName &&
          other.ownerId == this.ownerId &&
          other.createdAt == this.createdAt);
}

class MerchantsCompanion extends UpdateCompanion<Merchant> {
  final Value<int> id;
  final Value<String> storeName;
  final Value<int> ownerId;
  final Value<DateTime> createdAt;
  const MerchantsCompanion({
    this.id = const Value.absent(),
    this.storeName = const Value.absent(),
    this.ownerId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MerchantsCompanion.insert({
    this.id = const Value.absent(),
    required String storeName,
    required int ownerId,
    this.createdAt = const Value.absent(),
  }) : storeName = Value(storeName),
       ownerId = Value(ownerId);
  static Insertable<Merchant> custom({
    Expression<int>? id,
    Expression<String>? storeName,
    Expression<int>? ownerId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (storeName != null) 'store_name': storeName,
      if (ownerId != null) 'owner_id': ownerId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MerchantsCompanion copyWith({
    Value<int>? id,
    Value<String>? storeName,
    Value<int>? ownerId,
    Value<DateTime>? createdAt,
  }) {
    return MerchantsCompanion(
      id: id ?? this.id,
      storeName: storeName ?? this.storeName,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (storeName.present) {
      map['store_name'] = Variable<String>(storeName.value);
    }
    if (ownerId.present) {
      map['owner_id'] = Variable<int>(ownerId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MerchantsCompanion(')
          ..write('id: $id, ')
          ..write('storeName: $storeName, ')
          ..write('ownerId: $ownerId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SurplusFoodsTable extends SurplusFoods
    with TableInfo<$SurplusFoodsTable, SurplusFood> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SurplusFoodsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _merchantIdMeta = const VerificationMeta(
    'merchantId',
  );
  @override
  late final GeneratedColumn<int> merchantId = GeneratedColumn<int>(
    'merchant_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 160,
    ),
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
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _originalPriceMeta = const VerificationMeta(
    'originalPrice',
  );
  @override
  late final GeneratedColumn<int> originalPrice = GeneratedColumn<int>(
    'original_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _discountPriceMeta = const VerificationMeta(
    'discountPrice',
  );
  @override
  late final GeneratedColumn<int> discountPrice = GeneratedColumn<int>(
    'discount_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quotaMeta = const VerificationMeta('quota');
  @override
  late final GeneratedColumn<int> quota = GeneratedColumn<int>(
    'quota',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pickupWindowMeta = const VerificationMeta(
    'pickupWindow',
  );
  @override
  late final GeneratedColumn<String> pickupWindow = GeneratedColumn<String>(
    'pickup_window',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
    defaultValue: const Constant(true),
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
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    merchantId,
    name,
    description,
    originalPrice,
    discountPrice,
    quota,
    pickupWindow,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'surplus_foods';
  @override
  VerificationContext validateIntegrity(
    Insertable<SurplusFood> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('merchant_id')) {
      context.handle(
        _merchantIdMeta,
        merchantId.isAcceptableOrUnknown(data['merchant_id']!, _merchantIdMeta),
      );
    } else if (isInserting) {
      context.missing(_merchantIdMeta);
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
    if (data.containsKey('original_price')) {
      context.handle(
        _originalPriceMeta,
        originalPrice.isAcceptableOrUnknown(
          data['original_price']!,
          _originalPriceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalPriceMeta);
    }
    if (data.containsKey('discount_price')) {
      context.handle(
        _discountPriceMeta,
        discountPrice.isAcceptableOrUnknown(
          data['discount_price']!,
          _discountPriceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_discountPriceMeta);
    }
    if (data.containsKey('quota')) {
      context.handle(
        _quotaMeta,
        quota.isAcceptableOrUnknown(data['quota']!, _quotaMeta),
      );
    } else if (isInserting) {
      context.missing(_quotaMeta);
    }
    if (data.containsKey('pickup_window')) {
      context.handle(
        _pickupWindowMeta,
        pickupWindow.isAcceptableOrUnknown(
          data['pickup_window']!,
          _pickupWindowMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pickupWindowMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SurplusFood map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SurplusFood(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      merchantId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}merchant_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      originalPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}original_price'],
      )!,
      discountPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}discount_price'],
      )!,
      quota: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quota'],
      )!,
      pickupWindow: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pickup_window'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SurplusFoodsTable createAlias(String alias) {
    return $SurplusFoodsTable(attachedDatabase, alias);
  }
}

class SurplusFood extends DataClass implements Insertable<SurplusFood> {
  final int id;
  final int merchantId;
  final String name;
  final String description;
  final int originalPrice;
  final int discountPrice;
  final int quota;
  final String pickupWindow;
  final bool isActive;
  final DateTime createdAt;
  const SurplusFood({
    required this.id,
    required this.merchantId,
    required this.name,
    required this.description,
    required this.originalPrice,
    required this.discountPrice,
    required this.quota,
    required this.pickupWindow,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['merchant_id'] = Variable<int>(merchantId);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['original_price'] = Variable<int>(originalPrice);
    map['discount_price'] = Variable<int>(discountPrice);
    map['quota'] = Variable<int>(quota);
    map['pickup_window'] = Variable<String>(pickupWindow);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SurplusFoodsCompanion toCompanion(bool nullToAbsent) {
    return SurplusFoodsCompanion(
      id: Value(id),
      merchantId: Value(merchantId),
      name: Value(name),
      description: Value(description),
      originalPrice: Value(originalPrice),
      discountPrice: Value(discountPrice),
      quota: Value(quota),
      pickupWindow: Value(pickupWindow),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory SurplusFood.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SurplusFood(
      id: serializer.fromJson<int>(json['id']),
      merchantId: serializer.fromJson<int>(json['merchantId']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      originalPrice: serializer.fromJson<int>(json['originalPrice']),
      discountPrice: serializer.fromJson<int>(json['discountPrice']),
      quota: serializer.fromJson<int>(json['quota']),
      pickupWindow: serializer.fromJson<String>(json['pickupWindow']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'merchantId': serializer.toJson<int>(merchantId),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'originalPrice': serializer.toJson<int>(originalPrice),
      'discountPrice': serializer.toJson<int>(discountPrice),
      'quota': serializer.toJson<int>(quota),
      'pickupWindow': serializer.toJson<String>(pickupWindow),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SurplusFood copyWith({
    int? id,
    int? merchantId,
    String? name,
    String? description,
    int? originalPrice,
    int? discountPrice,
    int? quota,
    String? pickupWindow,
    bool? isActive,
    DateTime? createdAt,
  }) => SurplusFood(
    id: id ?? this.id,
    merchantId: merchantId ?? this.merchantId,
    name: name ?? this.name,
    description: description ?? this.description,
    originalPrice: originalPrice ?? this.originalPrice,
    discountPrice: discountPrice ?? this.discountPrice,
    quota: quota ?? this.quota,
    pickupWindow: pickupWindow ?? this.pickupWindow,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  SurplusFood copyWithCompanion(SurplusFoodsCompanion data) {
    return SurplusFood(
      id: data.id.present ? data.id.value : this.id,
      merchantId: data.merchantId.present
          ? data.merchantId.value
          : this.merchantId,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      originalPrice: data.originalPrice.present
          ? data.originalPrice.value
          : this.originalPrice,
      discountPrice: data.discountPrice.present
          ? data.discountPrice.value
          : this.discountPrice,
      quota: data.quota.present ? data.quota.value : this.quota,
      pickupWindow: data.pickupWindow.present
          ? data.pickupWindow.value
          : this.pickupWindow,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SurplusFood(')
          ..write('id: $id, ')
          ..write('merchantId: $merchantId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('originalPrice: $originalPrice, ')
          ..write('discountPrice: $discountPrice, ')
          ..write('quota: $quota, ')
          ..write('pickupWindow: $pickupWindow, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    merchantId,
    name,
    description,
    originalPrice,
    discountPrice,
    quota,
    pickupWindow,
    isActive,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SurplusFood &&
          other.id == this.id &&
          other.merchantId == this.merchantId &&
          other.name == this.name &&
          other.description == this.description &&
          other.originalPrice == this.originalPrice &&
          other.discountPrice == this.discountPrice &&
          other.quota == this.quota &&
          other.pickupWindow == this.pickupWindow &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class SurplusFoodsCompanion extends UpdateCompanion<SurplusFood> {
  final Value<int> id;
  final Value<int> merchantId;
  final Value<String> name;
  final Value<String> description;
  final Value<int> originalPrice;
  final Value<int> discountPrice;
  final Value<int> quota;
  final Value<String> pickupWindow;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  const SurplusFoodsCompanion({
    this.id = const Value.absent(),
    this.merchantId = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.originalPrice = const Value.absent(),
    this.discountPrice = const Value.absent(),
    this.quota = const Value.absent(),
    this.pickupWindow = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SurplusFoodsCompanion.insert({
    this.id = const Value.absent(),
    required int merchantId,
    required String name,
    this.description = const Value.absent(),
    required int originalPrice,
    required int discountPrice,
    required int quota,
    required String pickupWindow,
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : merchantId = Value(merchantId),
       name = Value(name),
       originalPrice = Value(originalPrice),
       discountPrice = Value(discountPrice),
       quota = Value(quota),
       pickupWindow = Value(pickupWindow);
  static Insertable<SurplusFood> custom({
    Expression<int>? id,
    Expression<int>? merchantId,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? originalPrice,
    Expression<int>? discountPrice,
    Expression<int>? quota,
    Expression<String>? pickupWindow,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (merchantId != null) 'merchant_id': merchantId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (originalPrice != null) 'original_price': originalPrice,
      if (discountPrice != null) 'discount_price': discountPrice,
      if (quota != null) 'quota': quota,
      if (pickupWindow != null) 'pickup_window': pickupWindow,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SurplusFoodsCompanion copyWith({
    Value<int>? id,
    Value<int>? merchantId,
    Value<String>? name,
    Value<String>? description,
    Value<int>? originalPrice,
    Value<int>? discountPrice,
    Value<int>? quota,
    Value<String>? pickupWindow,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
  }) {
    return SurplusFoodsCompanion(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      name: name ?? this.name,
      description: description ?? this.description,
      originalPrice: originalPrice ?? this.originalPrice,
      discountPrice: discountPrice ?? this.discountPrice,
      quota: quota ?? this.quota,
      pickupWindow: pickupWindow ?? this.pickupWindow,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (merchantId.present) {
      map['merchant_id'] = Variable<int>(merchantId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (originalPrice.present) {
      map['original_price'] = Variable<int>(originalPrice.value);
    }
    if (discountPrice.present) {
      map['discount_price'] = Variable<int>(discountPrice.value);
    }
    if (quota.present) {
      map['quota'] = Variable<int>(quota.value);
    }
    if (pickupWindow.present) {
      map['pickup_window'] = Variable<String>(pickupWindow.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SurplusFoodsCompanion(')
          ..write('id: $id, ')
          ..write('merchantId: $merchantId, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('originalPrice: $originalPrice, ')
          ..write('discountPrice: $discountPrice, ')
          ..write('quota: $quota, ')
          ..write('pickupWindow: $pickupWindow, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $OrdersTable extends Orders with TableInfo<$OrdersTable, Order> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OrdersTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _buyerIdMeta = const VerificationMeta(
    'buyerId',
  );
  @override
  late final GeneratedColumn<int> buyerId = GeneratedColumn<int>(
    'buyer_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<int> foodId = GeneratedColumn<int>(
    'food_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPriceMeta = const VerificationMeta(
    'totalPrice',
  );
  @override
  late final GeneratedColumn<int> totalPrice = GeneratedColumn<int>(
    'total_price',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pickupCodeMeta = const VerificationMeta(
    'pickupCode',
  );
  @override
  late final GeneratedColumn<String> pickupCode = GeneratedColumn<String>(
    'pickup_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  late final GeneratedColumnWithTypeConverter<OrderStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('pending'),
      ).withConverter<OrderStatus>($OrdersTable.$converterstatus);
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
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    buyerId,
    foodId,
    quantity,
    totalPrice,
    pickupCode,
    status,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Order> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('buyer_id')) {
      context.handle(
        _buyerIdMeta,
        buyerId.isAcceptableOrUnknown(data['buyer_id']!, _buyerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_buyerIdMeta);
    }
    if (data.containsKey('food_id')) {
      context.handle(
        _foodIdMeta,
        foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_foodIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('total_price')) {
      context.handle(
        _totalPriceMeta,
        totalPrice.isAcceptableOrUnknown(data['total_price']!, _totalPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_totalPriceMeta);
    }
    if (data.containsKey('pickup_code')) {
      context.handle(
        _pickupCodeMeta,
        pickupCode.isAcceptableOrUnknown(data['pickup_code']!, _pickupCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_pickupCodeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Order map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Order(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      buyerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}buyer_id'],
      )!,
      foodId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}food_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      totalPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_price'],
      )!,
      pickupCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pickup_code'],
      )!,
      status: $OrdersTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OrdersTable createAlias(String alias) {
    return $OrdersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<OrderStatus, String, String> $converterstatus =
      const EnumNameConverter<OrderStatus>(OrderStatus.values);
}

class Order extends DataClass implements Insertable<Order> {
  final int id;
  final int buyerId;
  final int foodId;
  final int quantity;
  final int totalPrice;
  final String pickupCode;
  final OrderStatus status;
  final DateTime createdAt;
  const Order({
    required this.id,
    required this.buyerId,
    required this.foodId,
    required this.quantity,
    required this.totalPrice,
    required this.pickupCode,
    required this.status,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['buyer_id'] = Variable<int>(buyerId);
    map['food_id'] = Variable<int>(foodId);
    map['quantity'] = Variable<int>(quantity);
    map['total_price'] = Variable<int>(totalPrice);
    map['pickup_code'] = Variable<String>(pickupCode);
    {
      map['status'] = Variable<String>(
        $OrdersTable.$converterstatus.toSql(status),
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OrdersCompanion toCompanion(bool nullToAbsent) {
    return OrdersCompanion(
      id: Value(id),
      buyerId: Value(buyerId),
      foodId: Value(foodId),
      quantity: Value(quantity),
      totalPrice: Value(totalPrice),
      pickupCode: Value(pickupCode),
      status: Value(status),
      createdAt: Value(createdAt),
    );
  }

  factory Order.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Order(
      id: serializer.fromJson<int>(json['id']),
      buyerId: serializer.fromJson<int>(json['buyerId']),
      foodId: serializer.fromJson<int>(json['foodId']),
      quantity: serializer.fromJson<int>(json['quantity']),
      totalPrice: serializer.fromJson<int>(json['totalPrice']),
      pickupCode: serializer.fromJson<String>(json['pickupCode']),
      status: $OrdersTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'buyerId': serializer.toJson<int>(buyerId),
      'foodId': serializer.toJson<int>(foodId),
      'quantity': serializer.toJson<int>(quantity),
      'totalPrice': serializer.toJson<int>(totalPrice),
      'pickupCode': serializer.toJson<String>(pickupCode),
      'status': serializer.toJson<String>(
        $OrdersTable.$converterstatus.toJson(status),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Order copyWith({
    int? id,
    int? buyerId,
    int? foodId,
    int? quantity,
    int? totalPrice,
    String? pickupCode,
    OrderStatus? status,
    DateTime? createdAt,
  }) => Order(
    id: id ?? this.id,
    buyerId: buyerId ?? this.buyerId,
    foodId: foodId ?? this.foodId,
    quantity: quantity ?? this.quantity,
    totalPrice: totalPrice ?? this.totalPrice,
    pickupCode: pickupCode ?? this.pickupCode,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
  );
  Order copyWithCompanion(OrdersCompanion data) {
    return Order(
      id: data.id.present ? data.id.value : this.id,
      buyerId: data.buyerId.present ? data.buyerId.value : this.buyerId,
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      totalPrice: data.totalPrice.present
          ? data.totalPrice.value
          : this.totalPrice,
      pickupCode: data.pickupCode.present
          ? data.pickupCode.value
          : this.pickupCode,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Order(')
          ..write('id: $id, ')
          ..write('buyerId: $buyerId, ')
          ..write('foodId: $foodId, ')
          ..write('quantity: $quantity, ')
          ..write('totalPrice: $totalPrice, ')
          ..write('pickupCode: $pickupCode, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    buyerId,
    foodId,
    quantity,
    totalPrice,
    pickupCode,
    status,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Order &&
          other.id == this.id &&
          other.buyerId == this.buyerId &&
          other.foodId == this.foodId &&
          other.quantity == this.quantity &&
          other.totalPrice == this.totalPrice &&
          other.pickupCode == this.pickupCode &&
          other.status == this.status &&
          other.createdAt == this.createdAt);
}

class OrdersCompanion extends UpdateCompanion<Order> {
  final Value<int> id;
  final Value<int> buyerId;
  final Value<int> foodId;
  final Value<int> quantity;
  final Value<int> totalPrice;
  final Value<String> pickupCode;
  final Value<OrderStatus> status;
  final Value<DateTime> createdAt;
  const OrdersCompanion({
    this.id = const Value.absent(),
    this.buyerId = const Value.absent(),
    this.foodId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.totalPrice = const Value.absent(),
    this.pickupCode = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  OrdersCompanion.insert({
    this.id = const Value.absent(),
    required int buyerId,
    required int foodId,
    required int quantity,
    required int totalPrice,
    required String pickupCode,
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : buyerId = Value(buyerId),
       foodId = Value(foodId),
       quantity = Value(quantity),
       totalPrice = Value(totalPrice),
       pickupCode = Value(pickupCode);
  static Insertable<Order> custom({
    Expression<int>? id,
    Expression<int>? buyerId,
    Expression<int>? foodId,
    Expression<int>? quantity,
    Expression<int>? totalPrice,
    Expression<String>? pickupCode,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (buyerId != null) 'buyer_id': buyerId,
      if (foodId != null) 'food_id': foodId,
      if (quantity != null) 'quantity': quantity,
      if (totalPrice != null) 'total_price': totalPrice,
      if (pickupCode != null) 'pickup_code': pickupCode,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  OrdersCompanion copyWith({
    Value<int>? id,
    Value<int>? buyerId,
    Value<int>? foodId,
    Value<int>? quantity,
    Value<int>? totalPrice,
    Value<String>? pickupCode,
    Value<OrderStatus>? status,
    Value<DateTime>? createdAt,
  }) {
    return OrdersCompanion(
      id: id ?? this.id,
      buyerId: buyerId ?? this.buyerId,
      foodId: foodId ?? this.foodId,
      quantity: quantity ?? this.quantity,
      totalPrice: totalPrice ?? this.totalPrice,
      pickupCode: pickupCode ?? this.pickupCode,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (buyerId.present) {
      map['buyer_id'] = Variable<int>(buyerId.value);
    }
    if (foodId.present) {
      map['food_id'] = Variable<int>(foodId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (totalPrice.present) {
      map['total_price'] = Variable<int>(totalPrice.value);
    }
    if (pickupCode.present) {
      map['pickup_code'] = Variable<String>(pickupCode.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $OrdersTable.$converterstatus.toSql(status.value),
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OrdersCompanion(')
          ..write('id: $id, ')
          ..write('buyerId: $buyerId, ')
          ..write('foodId: $foodId, ')
          ..write('quantity: $quantity, ')
          ..write('totalPrice: $totalPrice, ')
          ..write('pickupCode: $pickupCode, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $MerchantsTable merchants = $MerchantsTable(this);
  late final $SurplusFoodsTable surplusFoods = $SurplusFoodsTable(this);
  late final $OrdersTable orders = $OrdersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    users,
    merchants,
    surplusFoods,
    orders,
  ];
}

typedef $$UsersTableCreateCompanionBuilder =
    UsersCompanion Function({
      Value<int> id,
      required String email,
      required String passwordHash,
      required String name,
      required UserRole role,
      Value<DateTime> createdAt,
    });
typedef $$UsersTableUpdateCompanionBuilder =
    UsersCompanion Function({
      Value<int> id,
      Value<String> email,
      Value<String> passwordHash,
      Value<String> name,
      Value<UserRole> role,
      Value<DateTime> createdAt,
    });

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
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

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<UserRole, UserRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
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

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get passwordHash => $composableBuilder(
    column: $table.passwordHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumnWithTypeConverter<UserRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UsersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UsersTable,
          User,
          $$UsersTableFilterComposer,
          $$UsersTableOrderingComposer,
          $$UsersTableAnnotationComposer,
          $$UsersTableCreateCompanionBuilder,
          $$UsersTableUpdateCompanionBuilder,
          (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
          User,
          PrefetchHooks Function()
        > {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<String> passwordHash = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<UserRole> role = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => UsersCompanion(
                id: id,
                email: email,
                passwordHash: passwordHash,
                name: name,
                role: role,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String email,
                required String passwordHash,
                required String name,
                required UserRole role,
                Value<DateTime> createdAt = const Value.absent(),
              }) => UsersCompanion.insert(
                id: id,
                email: email,
                passwordHash: passwordHash,
                name: name,
                role: role,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UsersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UsersTable,
      User,
      $$UsersTableFilterComposer,
      $$UsersTableOrderingComposer,
      $$UsersTableAnnotationComposer,
      $$UsersTableCreateCompanionBuilder,
      $$UsersTableUpdateCompanionBuilder,
      (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
      User,
      PrefetchHooks Function()
    >;
typedef $$MerchantsTableCreateCompanionBuilder =
    MerchantsCompanion Function({
      Value<int> id,
      required String storeName,
      required int ownerId,
      Value<DateTime> createdAt,
    });
typedef $$MerchantsTableUpdateCompanionBuilder =
    MerchantsCompanion Function({
      Value<int> id,
      Value<String> storeName,
      Value<int> ownerId,
      Value<DateTime> createdAt,
    });

class $$MerchantsTableFilterComposer
    extends Composer<_$AppDatabase, $MerchantsTable> {
  $$MerchantsTableFilterComposer({
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

  ColumnFilters<String> get storeName => $composableBuilder(
    column: $table.storeName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MerchantsTableOrderingComposer
    extends Composer<_$AppDatabase, $MerchantsTable> {
  $$MerchantsTableOrderingComposer({
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

  ColumnOrderings<String> get storeName => $composableBuilder(
    column: $table.storeName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ownerId => $composableBuilder(
    column: $table.ownerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MerchantsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MerchantsTable> {
  $$MerchantsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get storeName =>
      $composableBuilder(column: $table.storeName, builder: (column) => column);

  GeneratedColumn<int> get ownerId =>
      $composableBuilder(column: $table.ownerId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MerchantsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MerchantsTable,
          Merchant,
          $$MerchantsTableFilterComposer,
          $$MerchantsTableOrderingComposer,
          $$MerchantsTableAnnotationComposer,
          $$MerchantsTableCreateCompanionBuilder,
          $$MerchantsTableUpdateCompanionBuilder,
          (Merchant, BaseReferences<_$AppDatabase, $MerchantsTable, Merchant>),
          Merchant,
          PrefetchHooks Function()
        > {
  $$MerchantsTableTableManager(_$AppDatabase db, $MerchantsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MerchantsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MerchantsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MerchantsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> storeName = const Value.absent(),
                Value<int> ownerId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MerchantsCompanion(
                id: id,
                storeName: storeName,
                ownerId: ownerId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String storeName,
                required int ownerId,
                Value<DateTime> createdAt = const Value.absent(),
              }) => MerchantsCompanion.insert(
                id: id,
                storeName: storeName,
                ownerId: ownerId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MerchantsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MerchantsTable,
      Merchant,
      $$MerchantsTableFilterComposer,
      $$MerchantsTableOrderingComposer,
      $$MerchantsTableAnnotationComposer,
      $$MerchantsTableCreateCompanionBuilder,
      $$MerchantsTableUpdateCompanionBuilder,
      (Merchant, BaseReferences<_$AppDatabase, $MerchantsTable, Merchant>),
      Merchant,
      PrefetchHooks Function()
    >;
typedef $$SurplusFoodsTableCreateCompanionBuilder =
    SurplusFoodsCompanion Function({
      Value<int> id,
      required int merchantId,
      required String name,
      Value<String> description,
      required int originalPrice,
      required int discountPrice,
      required int quota,
      required String pickupWindow,
      Value<bool> isActive,
      Value<DateTime> createdAt,
    });
typedef $$SurplusFoodsTableUpdateCompanionBuilder =
    SurplusFoodsCompanion Function({
      Value<int> id,
      Value<int> merchantId,
      Value<String> name,
      Value<String> description,
      Value<int> originalPrice,
      Value<int> discountPrice,
      Value<int> quota,
      Value<String> pickupWindow,
      Value<bool> isActive,
      Value<DateTime> createdAt,
    });

class $$SurplusFoodsTableFilterComposer
    extends Composer<_$AppDatabase, $SurplusFoodsTable> {
  $$SurplusFoodsTableFilterComposer({
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

  ColumnFilters<int> get merchantId => $composableBuilder(
    column: $table.merchantId,
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

  ColumnFilters<int> get originalPrice => $composableBuilder(
    column: $table.originalPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discountPrice => $composableBuilder(
    column: $table.discountPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quota => $composableBuilder(
    column: $table.quota,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pickupWindow => $composableBuilder(
    column: $table.pickupWindow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SurplusFoodsTableOrderingComposer
    extends Composer<_$AppDatabase, $SurplusFoodsTable> {
  $$SurplusFoodsTableOrderingComposer({
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

  ColumnOrderings<int> get merchantId => $composableBuilder(
    column: $table.merchantId,
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

  ColumnOrderings<int> get originalPrice => $composableBuilder(
    column: $table.originalPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discountPrice => $composableBuilder(
    column: $table.discountPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quota => $composableBuilder(
    column: $table.quota,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pickupWindow => $composableBuilder(
    column: $table.pickupWindow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SurplusFoodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SurplusFoodsTable> {
  $$SurplusFoodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get merchantId => $composableBuilder(
    column: $table.merchantId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get originalPrice => $composableBuilder(
    column: $table.originalPrice,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discountPrice => $composableBuilder(
    column: $table.discountPrice,
    builder: (column) => column,
  );

  GeneratedColumn<int> get quota =>
      $composableBuilder(column: $table.quota, builder: (column) => column);

  GeneratedColumn<String> get pickupWindow => $composableBuilder(
    column: $table.pickupWindow,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SurplusFoodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SurplusFoodsTable,
          SurplusFood,
          $$SurplusFoodsTableFilterComposer,
          $$SurplusFoodsTableOrderingComposer,
          $$SurplusFoodsTableAnnotationComposer,
          $$SurplusFoodsTableCreateCompanionBuilder,
          $$SurplusFoodsTableUpdateCompanionBuilder,
          (
            SurplusFood,
            BaseReferences<_$AppDatabase, $SurplusFoodsTable, SurplusFood>,
          ),
          SurplusFood,
          PrefetchHooks Function()
        > {
  $$SurplusFoodsTableTableManager(_$AppDatabase db, $SurplusFoodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SurplusFoodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SurplusFoodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SurplusFoodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> merchantId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> originalPrice = const Value.absent(),
                Value<int> discountPrice = const Value.absent(),
                Value<int> quota = const Value.absent(),
                Value<String> pickupWindow = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SurplusFoodsCompanion(
                id: id,
                merchantId: merchantId,
                name: name,
                description: description,
                originalPrice: originalPrice,
                discountPrice: discountPrice,
                quota: quota,
                pickupWindow: pickupWindow,
                isActive: isActive,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int merchantId,
                required String name,
                Value<String> description = const Value.absent(),
                required int originalPrice,
                required int discountPrice,
                required int quota,
                required String pickupWindow,
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SurplusFoodsCompanion.insert(
                id: id,
                merchantId: merchantId,
                name: name,
                description: description,
                originalPrice: originalPrice,
                discountPrice: discountPrice,
                quota: quota,
                pickupWindow: pickupWindow,
                isActive: isActive,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SurplusFoodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SurplusFoodsTable,
      SurplusFood,
      $$SurplusFoodsTableFilterComposer,
      $$SurplusFoodsTableOrderingComposer,
      $$SurplusFoodsTableAnnotationComposer,
      $$SurplusFoodsTableCreateCompanionBuilder,
      $$SurplusFoodsTableUpdateCompanionBuilder,
      (
        SurplusFood,
        BaseReferences<_$AppDatabase, $SurplusFoodsTable, SurplusFood>,
      ),
      SurplusFood,
      PrefetchHooks Function()
    >;
typedef $$OrdersTableCreateCompanionBuilder =
    OrdersCompanion Function({
      Value<int> id,
      required int buyerId,
      required int foodId,
      required int quantity,
      required int totalPrice,
      required String pickupCode,
      Value<OrderStatus> status,
      Value<DateTime> createdAt,
    });
typedef $$OrdersTableUpdateCompanionBuilder =
    OrdersCompanion Function({
      Value<int> id,
      Value<int> buyerId,
      Value<int> foodId,
      Value<int> quantity,
      Value<int> totalPrice,
      Value<String> pickupCode,
      Value<OrderStatus> status,
      Value<DateTime> createdAt,
    });

class $$OrdersTableFilterComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableFilterComposer({
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

  ColumnFilters<int> get buyerId => $composableBuilder(
    column: $table.buyerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get foodId => $composableBuilder(
    column: $table.foodId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPrice => $composableBuilder(
    column: $table.totalPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pickupCode => $composableBuilder(
    column: $table.pickupCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<OrderStatus, OrderStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableOrderingComposer({
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

  ColumnOrderings<int> get buyerId => $composableBuilder(
    column: $table.buyerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get foodId => $composableBuilder(
    column: $table.foodId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPrice => $composableBuilder(
    column: $table.totalPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pickupCode => $composableBuilder(
    column: $table.pickupCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $OrdersTable> {
  $$OrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get buyerId =>
      $composableBuilder(column: $table.buyerId, builder: (column) => column);

  GeneratedColumn<int> get foodId =>
      $composableBuilder(column: $table.foodId, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get totalPrice => $composableBuilder(
    column: $table.totalPrice,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pickupCode => $composableBuilder(
    column: $table.pickupCode,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<OrderStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OrdersTable,
          Order,
          $$OrdersTableFilterComposer,
          $$OrdersTableOrderingComposer,
          $$OrdersTableAnnotationComposer,
          $$OrdersTableCreateCompanionBuilder,
          $$OrdersTableUpdateCompanionBuilder,
          (Order, BaseReferences<_$AppDatabase, $OrdersTable, Order>),
          Order,
          PrefetchHooks Function()
        > {
  $$OrdersTableTableManager(_$AppDatabase db, $OrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> buyerId = const Value.absent(),
                Value<int> foodId = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<int> totalPrice = const Value.absent(),
                Value<String> pickupCode = const Value.absent(),
                Value<OrderStatus> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OrdersCompanion(
                id: id,
                buyerId: buyerId,
                foodId: foodId,
                quantity: quantity,
                totalPrice: totalPrice,
                pickupCode: pickupCode,
                status: status,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int buyerId,
                required int foodId,
                required int quantity,
                required int totalPrice,
                required String pickupCode,
                Value<OrderStatus> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => OrdersCompanion.insert(
                id: id,
                buyerId: buyerId,
                foodId: foodId,
                quantity: quantity,
                totalPrice: totalPrice,
                pickupCode: pickupCode,
                status: status,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OrdersTable,
      Order,
      $$OrdersTableFilterComposer,
      $$OrdersTableOrderingComposer,
      $$OrdersTableAnnotationComposer,
      $$OrdersTableCreateCompanionBuilder,
      $$OrdersTableUpdateCompanionBuilder,
      (Order, BaseReferences<_$AppDatabase, $OrdersTable, Order>),
      Order,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$MerchantsTableTableManager get merchants =>
      $$MerchantsTableTableManager(_db, _db.merchants);
  $$SurplusFoodsTableTableManager get surplusFoods =>
      $$SurplusFoodsTableTableManager(_db, _db.surplusFoods);
  $$OrdersTableTableManager get orders =>
      $$OrdersTableTableManager(_db, _db.orders);
}
