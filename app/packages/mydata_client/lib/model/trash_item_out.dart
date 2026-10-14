//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class TrashItemOut {
  /// Returns a new [TrashItemOut] instance.
  TrashItemOut({
    required this.backupsKeptUntil,
    this.contact,
    required this.deletedAt,
    required this.id,
    required this.kind,
    required this.purgeAfter,
    required this.title,
  });

  /// YYYY-MM-DD: copies of it in the host's snapshots are kept until this day if it is deleted for good now, while the host keeps running (the apps say so before deleting it for good)
  String backupsKeptUntil;

  /// for kind contact
  ContactOut? contact;

  String deletedAt;

  String id;

  /// what the item is (events come later)
  TrashItemOutKindEnum kind;

  /// when it is deleted for good (UTC)
  String purgeAfter;

  /// the item's name as the apps show it
  String title;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrashItemOut &&
          other.backupsKeptUntil == backupsKeptUntil &&
          other.contact == contact &&
          other.deletedAt == deletedAt &&
          other.id == id &&
          other.kind == kind &&
          other.purgeAfter == purgeAfter &&
          other.title == title;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (backupsKeptUntil.hashCode) +
      (contact == null ? 0 : contact!.hashCode) +
      (deletedAt.hashCode) +
      (id.hashCode) +
      (kind.hashCode) +
      (purgeAfter.hashCode) +
      (title.hashCode);

  @override
  String toString() =>
      'TrashItemOut[backupsKeptUntil=$backupsKeptUntil, contact=$contact, deletedAt=$deletedAt, id=$id, kind=$kind, purgeAfter=$purgeAfter, title=$title]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'backups_kept_until'] = this.backupsKeptUntil;
    if (this.contact != null) {
      json[r'contact'] = this.contact;
    } else {
      json[r'contact'] = null;
    }
    json[r'deleted_at'] = this.deletedAt;
    json[r'id'] = this.id;
    json[r'kind'] = this.kind;
    json[r'purge_after'] = this.purgeAfter;
    json[r'title'] = this.title;
    return json;
  }

  /// Returns a new [TrashItemOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static TrashItemOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'backups_kept_until'),
            'Required key "TrashItemOut[backups_kept_until]" is missing from JSON.');
        assert(json[r'backups_kept_until'] != null,
            'Required key "TrashItemOut[backups_kept_until]" has a null value in JSON.');
        assert(json.containsKey(r'deleted_at'),
            'Required key "TrashItemOut[deleted_at]" is missing from JSON.');
        assert(json[r'deleted_at'] != null,
            'Required key "TrashItemOut[deleted_at]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "TrashItemOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "TrashItemOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'kind'),
            'Required key "TrashItemOut[kind]" is missing from JSON.');
        assert(json[r'kind'] != null,
            'Required key "TrashItemOut[kind]" has a null value in JSON.');
        assert(json.containsKey(r'purge_after'),
            'Required key "TrashItemOut[purge_after]" is missing from JSON.');
        assert(json[r'purge_after'] != null,
            'Required key "TrashItemOut[purge_after]" has a null value in JSON.');
        assert(json.containsKey(r'title'),
            'Required key "TrashItemOut[title]" is missing from JSON.');
        assert(json[r'title'] != null,
            'Required key "TrashItemOut[title]" has a null value in JSON.');
        return true;
      }());

      return TrashItemOut(
        backupsKeptUntil: mapValueOfType<String>(json, r'backups_kept_until')!,
        contact: ContactOut.fromJson(json[r'contact']),
        deletedAt: mapValueOfType<String>(json, r'deleted_at')!,
        id: mapValueOfType<String>(json, r'id')!,
        kind: TrashItemOutKindEnum.fromJson(json[r'kind'])!,
        purgeAfter: mapValueOfType<String>(json, r'purge_after')!,
        title: mapValueOfType<String>(json, r'title')!,
      );
    }
    return null;
  }

  static List<TrashItemOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <TrashItemOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TrashItemOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, TrashItemOut> mapFromJson(dynamic json) {
    final map = <String, TrashItemOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = TrashItemOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of TrashItemOut-objects as value to a dart map
  static Map<String, List<TrashItemOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<TrashItemOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = TrashItemOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'backups_kept_until',
    'deleted_at',
    'id',
    'kind',
    'purge_after',
    'title',
  };
}

/// what the item is (events come later)
enum TrashItemOutKindEnum {
  contact._(r'contact'),
  ;

  /// Instantiate a new enum with the provided value.
  const TrashItemOutKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [TrashItemOutKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static TrashItemOutKindEnum? fromJson(dynamic value) =>
      TrashItemOutKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [TrashItemOutKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<TrashItemOutKindEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <TrashItemOutKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = TrashItemOutKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [TrashItemOutKindEnum] to String,
/// and [decode] dynamic data back to [TrashItemOutKindEnum].
class TrashItemOutKindEnumTypeTransformer {
  factory TrashItemOutKindEnumTypeTransformer() =>
      _instance ??= const TrashItemOutKindEnumTypeTransformer._();

  const TrashItemOutKindEnumTypeTransformer._();

  String encode(TrashItemOutKindEnum data) => data._value;

  /// Returns the instance of [TrashItemOutKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  TrashItemOutKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is TrashItemOutKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'contact':
          return TrashItemOutKindEnum.contact;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static TrashItemOutKindEnumTypeTransformer? _instance;
}
