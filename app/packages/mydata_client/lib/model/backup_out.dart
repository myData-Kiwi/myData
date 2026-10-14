//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class BackupOut {
  /// Returns a new [BackupOut] instance.
  BackupOut({
    this.error,
    required this.filevault,
    this.lastSnapshotAt,
    this.lastVerifiedAt,
    this.lastVerifyOk,
  });

  /// why the last hourly snapshot failed; null once one succeeds
  String? error;

  /// whether the disk is encrypted (macOS FileVault); unknown on other systems
  BackupOutFilevaultEnum filevault;

  /// when the newest snapshot of the databases was taken (UTC); none yet: null
  String? lastSnapshotAt;

  /// when a snapshot was last restored into a temporary folder and checked (`mydata backup verify`)
  String? lastVerifiedAt;

  /// whether that restore drill passed
  bool? lastVerifyOk;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupOut &&
          other.error == error &&
          other.filevault == filevault &&
          other.lastSnapshotAt == lastSnapshotAt &&
          other.lastVerifiedAt == lastVerifiedAt &&
          other.lastVerifyOk == lastVerifyOk;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (error == null ? 0 : error!.hashCode) +
      (filevault.hashCode) +
      (lastSnapshotAt == null ? 0 : lastSnapshotAt!.hashCode) +
      (lastVerifiedAt == null ? 0 : lastVerifiedAt!.hashCode) +
      (lastVerifyOk == null ? 0 : lastVerifyOk!.hashCode);

  @override
  String toString() =>
      'BackupOut[error=$error, filevault=$filevault, lastSnapshotAt=$lastSnapshotAt, lastVerifiedAt=$lastVerifiedAt, lastVerifyOk=$lastVerifyOk]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.error != null) {
      json[r'error'] = this.error;
    } else {
      json[r'error'] = null;
    }
    json[r'filevault'] = this.filevault;
    if (this.lastSnapshotAt != null) {
      json[r'last_snapshot_at'] = this.lastSnapshotAt;
    } else {
      json[r'last_snapshot_at'] = null;
    }
    if (this.lastVerifiedAt != null) {
      json[r'last_verified_at'] = this.lastVerifiedAt;
    } else {
      json[r'last_verified_at'] = null;
    }
    if (this.lastVerifyOk != null) {
      json[r'last_verify_ok'] = this.lastVerifyOk;
    } else {
      json[r'last_verify_ok'] = null;
    }
    return json;
  }

  /// Returns a new [BackupOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static BackupOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'filevault'),
            'Required key "BackupOut[filevault]" is missing from JSON.');
        assert(json[r'filevault'] != null,
            'Required key "BackupOut[filevault]" has a null value in JSON.');
        return true;
      }());

      return BackupOut(
        error: mapValueOfType<String>(json, r'error'),
        filevault: BackupOutFilevaultEnum.fromJson(json[r'filevault'])!,
        lastSnapshotAt: mapValueOfType<String>(json, r'last_snapshot_at'),
        lastVerifiedAt: mapValueOfType<String>(json, r'last_verified_at'),
        lastVerifyOk: mapValueOfType<bool>(json, r'last_verify_ok'),
      );
    }
    return null;
  }

  static List<BackupOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <BackupOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BackupOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, BackupOut> mapFromJson(dynamic json) {
    final map = <String, BackupOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = BackupOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of BackupOut-objects as value to a dart map
  static Map<String, List<BackupOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<BackupOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = BackupOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'filevault',
  };
}

/// whether the disk is encrypted (macOS FileVault); unknown on other systems
enum BackupOutFilevaultEnum {
  on_._(r'on'),
  off._(r'off'),
  unknown._(r'unknown'),
  ;

  /// Instantiate a new enum with the provided value.
  const BackupOutFilevaultEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [BackupOutFilevaultEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static BackupOutFilevaultEnum? fromJson(dynamic value) =>
      BackupOutFilevaultEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [BackupOutFilevaultEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<BackupOutFilevaultEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <BackupOutFilevaultEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = BackupOutFilevaultEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [BackupOutFilevaultEnum] to String,
/// and [decode] dynamic data back to [BackupOutFilevaultEnum].
class BackupOutFilevaultEnumTypeTransformer {
  factory BackupOutFilevaultEnumTypeTransformer() =>
      _instance ??= const BackupOutFilevaultEnumTypeTransformer._();

  const BackupOutFilevaultEnumTypeTransformer._();

  String encode(BackupOutFilevaultEnum data) => data._value;

  /// Returns the instance of [BackupOutFilevaultEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  BackupOutFilevaultEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is BackupOutFilevaultEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'on':
          return BackupOutFilevaultEnum.on_;
        case r'off':
          return BackupOutFilevaultEnum.off;
        case r'unknown':
          return BackupOutFilevaultEnum.unknown;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static BackupOutFilevaultEnumTypeTransformer? _instance;
}
