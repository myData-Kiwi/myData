//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CoverageOut {
  /// Returns a new [CoverageOut] instance.
  CoverageOut({
    required this.accountId,
    required this.complete,
    this.coveredEnd,
    this.coveredStart,
    this.reason,
    required this.source_,
  });

  String accountId;

  /// true when the source holds every day asked for
  bool complete;

  /// last day the source holds (included); none: no limit
  String? coveredEnd;

  /// first day the source holds; none: no limit
  String? coveredStart;

  /// when the source holds no days at all: why
  CoverageOutReasonEnum? reason;

  CoverageOutSource_Enum source_;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoverageOut &&
          other.accountId == accountId &&
          other.complete == complete &&
          other.coveredEnd == coveredEnd &&
          other.coveredStart == coveredStart &&
          other.reason == reason &&
          other.source_ == source_;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accountId.hashCode) +
      (complete.hashCode) +
      (coveredEnd == null ? 0 : coveredEnd!.hashCode) +
      (coveredStart == null ? 0 : coveredStart!.hashCode) +
      (reason == null ? 0 : reason!.hashCode) +
      (source_.hashCode);

  @override
  String toString() =>
      'CoverageOut[accountId=$accountId, complete=$complete, coveredEnd=$coveredEnd, coveredStart=$coveredStart, reason=$reason, source_=$source_]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'account_id'] = this.accountId;
    json[r'complete'] = this.complete;
    if (this.coveredEnd != null) {
      json[r'covered_end'] = this.coveredEnd;
    } else {
      json[r'covered_end'] = null;
    }
    if (this.coveredStart != null) {
      json[r'covered_start'] = this.coveredStart;
    } else {
      json[r'covered_start'] = null;
    }
    if (this.reason != null) {
      json[r'reason'] = this.reason;
    } else {
      json[r'reason'] = null;
    }
    json[r'source'] = this.source_;
    return json;
  }

  /// Returns a new [CoverageOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CoverageOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'account_id'),
            'Required key "CoverageOut[account_id]" is missing from JSON.');
        assert(json[r'account_id'] != null,
            'Required key "CoverageOut[account_id]" has a null value in JSON.');
        assert(json.containsKey(r'complete'),
            'Required key "CoverageOut[complete]" is missing from JSON.');
        assert(json[r'complete'] != null,
            'Required key "CoverageOut[complete]" has a null value in JSON.');
        assert(json.containsKey(r'source'),
            'Required key "CoverageOut[source]" is missing from JSON.');
        assert(json[r'source'] != null,
            'Required key "CoverageOut[source]" has a null value in JSON.');
        return true;
      }());

      return CoverageOut(
        accountId: mapValueOfType<String>(json, r'account_id')!,
        complete: mapValueOfType<bool>(json, r'complete')!,
        coveredEnd: mapValueOfType<String>(json, r'covered_end'),
        coveredStart: mapValueOfType<String>(json, r'covered_start'),
        reason: CoverageOutReasonEnum.fromJson(json[r'reason']),
        source_: CoverageOutSource_Enum.fromJson(json[r'source'])!,
      );
    }
    return null;
  }

  static List<CoverageOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <CoverageOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CoverageOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CoverageOut> mapFromJson(dynamic json) {
    final map = <String, CoverageOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CoverageOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CoverageOut-objects as value to a dart map
  static Map<String, List<CoverageOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<CoverageOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CoverageOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'account_id',
    'complete',
    'source',
  };
}

/// when the source holds no days at all: why
enum CoverageOutReasonEnum {
  noAccess._(r'no_access'),
  notReadYet._(r'not_read_yet'),
  ;

  /// Instantiate a new enum with the provided value.
  const CoverageOutReasonEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CoverageOutReasonEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CoverageOutReasonEnum? fromJson(dynamic value) =>
      CoverageOutReasonEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CoverageOutReasonEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CoverageOutReasonEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <CoverageOutReasonEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CoverageOutReasonEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CoverageOutReasonEnum] to String,
/// and [decode] dynamic data back to [CoverageOutReasonEnum].
class CoverageOutReasonEnumTypeTransformer {
  factory CoverageOutReasonEnumTypeTransformer() =>
      _instance ??= const CoverageOutReasonEnumTypeTransformer._();

  const CoverageOutReasonEnumTypeTransformer._();

  String encode(CoverageOutReasonEnum data) => data._value;

  /// Returns the instance of [CoverageOutReasonEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CoverageOutReasonEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is CoverageOutReasonEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'no_access':
          return CoverageOutReasonEnum.noAccess;
        case r'not_read_yet':
          return CoverageOutReasonEnum.notReadYet;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CoverageOutReasonEnumTypeTransformer? _instance;
}

enum CoverageOutSource_Enum {
  mac._(r'mac'),
  icloud._(r'icloud'),
  ;

  /// Instantiate a new enum with the provided value.
  const CoverageOutSource_Enum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CoverageOutSource_Enum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CoverageOutSource_Enum? fromJson(dynamic value) =>
      CoverageOutSource_EnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CoverageOutSource_Enum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CoverageOutSource_Enum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <CoverageOutSource_Enum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CoverageOutSource_Enum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CoverageOutSource_Enum] to String,
/// and [decode] dynamic data back to [CoverageOutSource_Enum].
class CoverageOutSource_EnumTypeTransformer {
  factory CoverageOutSource_EnumTypeTransformer() =>
      _instance ??= const CoverageOutSource_EnumTypeTransformer._();

  const CoverageOutSource_EnumTypeTransformer._();

  String encode(CoverageOutSource_Enum data) => data._value;

  /// Returns the instance of [CoverageOutSource_Enum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CoverageOutSource_Enum? decode(dynamic data, {bool allowNull = true}) {
    if (data is CoverageOutSource_Enum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'mac':
          return CoverageOutSource_Enum.mac;
        case r'icloud':
          return CoverageOutSource_Enum.icloud;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CoverageOutSource_EnumTypeTransformer? _instance;
}
