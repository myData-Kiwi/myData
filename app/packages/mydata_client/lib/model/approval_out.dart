//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ApprovalOut {
  /// Returns a new [ApprovalOut] instance.
  ApprovalOut({
    this.args = const {},
    required this.caller,
    this.context = const {},
    required this.createdAt,
    this.decidedAt,
    this.decidedBy,
    this.error,
    required this.id,
    this.result,
    required this.status,
    required this.summary,
    required this.tool,
  });

  /// exactly what will run if approved
  Map<String, Object> args;

  String caller;

  Map<String, Object> context;

  String createdAt;

  String? decidedAt;

  /// which app decided, e.g. app:myassistant
  String? decidedBy;

  String? error;

  String id;

  Object? result;

  ApprovalOutStatusEnum status;

  String summary;

  String tool;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ApprovalOut &&
          _deepEquality.equals(other.args, args) &&
          other.caller == caller &&
          _deepEquality.equals(other.context, context) &&
          other.createdAt == createdAt &&
          other.decidedAt == decidedAt &&
          other.decidedBy == decidedBy &&
          other.error == error &&
          other.id == id &&
          other.result == result &&
          other.status == status &&
          other.summary == summary &&
          other.tool == tool;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (args.hashCode) +
      (caller.hashCode) +
      (context.hashCode) +
      (createdAt.hashCode) +
      (decidedAt == null ? 0 : decidedAt!.hashCode) +
      (decidedBy == null ? 0 : decidedBy!.hashCode) +
      (error == null ? 0 : error!.hashCode) +
      (id.hashCode) +
      (result == null ? 0 : result!.hashCode) +
      (status.hashCode) +
      (summary.hashCode) +
      (tool.hashCode);

  @override
  String toString() =>
      'ApprovalOut[args=$args, caller=$caller, context=$context, createdAt=$createdAt, decidedAt=$decidedAt, decidedBy=$decidedBy, error=$error, id=$id, result=$result, status=$status, summary=$summary, tool=$tool]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'args'] = this.args;
    json[r'caller'] = this.caller;
    json[r'context'] = this.context;
    json[r'created_at'] = this.createdAt;
    if (this.decidedAt != null) {
      json[r'decided_at'] = this.decidedAt;
    } else {
      json[r'decided_at'] = null;
    }
    if (this.decidedBy != null) {
      json[r'decided_by'] = this.decidedBy;
    } else {
      json[r'decided_by'] = null;
    }
    if (this.error != null) {
      json[r'error'] = this.error;
    } else {
      json[r'error'] = null;
    }
    json[r'id'] = this.id;
    if (this.result != null) {
      json[r'result'] = this.result;
    } else {
      json[r'result'] = null;
    }
    json[r'status'] = this.status;
    json[r'summary'] = this.summary;
    json[r'tool'] = this.tool;
    return json;
  }

  /// Returns a new [ApprovalOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ApprovalOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'args'),
            'Required key "ApprovalOut[args]" is missing from JSON.');
        assert(json[r'args'] != null,
            'Required key "ApprovalOut[args]" has a null value in JSON.');
        assert(json.containsKey(r'caller'),
            'Required key "ApprovalOut[caller]" is missing from JSON.');
        assert(json[r'caller'] != null,
            'Required key "ApprovalOut[caller]" has a null value in JSON.');
        assert(json.containsKey(r'created_at'),
            'Required key "ApprovalOut[created_at]" is missing from JSON.');
        assert(json[r'created_at'] != null,
            'Required key "ApprovalOut[created_at]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "ApprovalOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "ApprovalOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'status'),
            'Required key "ApprovalOut[status]" is missing from JSON.');
        assert(json[r'status'] != null,
            'Required key "ApprovalOut[status]" has a null value in JSON.');
        assert(json.containsKey(r'summary'),
            'Required key "ApprovalOut[summary]" is missing from JSON.');
        assert(json[r'summary'] != null,
            'Required key "ApprovalOut[summary]" has a null value in JSON.');
        assert(json.containsKey(r'tool'),
            'Required key "ApprovalOut[tool]" is missing from JSON.');
        assert(json[r'tool'] != null,
            'Required key "ApprovalOut[tool]" has a null value in JSON.');
        return true;
      }());

      return ApprovalOut(
        args: mapCastOfType<String, Object>(json, r'args')!,
        caller: mapValueOfType<String>(json, r'caller')!,
        context: mapCastOfType<String, Object>(json, r'context') ?? const {},
        createdAt: mapValueOfType<String>(json, r'created_at')!,
        decidedAt: mapValueOfType<String>(json, r'decided_at'),
        decidedBy: mapValueOfType<String>(json, r'decided_by'),
        error: mapValueOfType<String>(json, r'error'),
        id: mapValueOfType<String>(json, r'id')!,
        result: mapValueOfType<Object>(json, r'result'),
        status: ApprovalOutStatusEnum.fromJson(json[r'status'])!,
        summary: mapValueOfType<String>(json, r'summary')!,
        tool: mapValueOfType<String>(json, r'tool')!,
      );
    }
    return null;
  }

  static List<ApprovalOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ApprovalOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ApprovalOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ApprovalOut> mapFromJson(dynamic json) {
    final map = <String, ApprovalOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ApprovalOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ApprovalOut-objects as value to a dart map
  static Map<String, List<ApprovalOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ApprovalOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ApprovalOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'args',
    'caller',
    'created_at',
    'id',
    'status',
    'summary',
    'tool',
  };
}

enum ApprovalOutStatusEnum {
  pending._(r'pending'),
  approved._(r'approved'),
  rejected._(r'rejected'),
  failed._(r'failed'),
  ;

  /// Instantiate a new enum with the provided value.
  const ApprovalOutStatusEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ApprovalOutStatusEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ApprovalOutStatusEnum? fromJson(dynamic value) =>
      ApprovalOutStatusEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ApprovalOutStatusEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ApprovalOutStatusEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ApprovalOutStatusEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ApprovalOutStatusEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ApprovalOutStatusEnum] to String,
/// and [decode] dynamic data back to [ApprovalOutStatusEnum].
class ApprovalOutStatusEnumTypeTransformer {
  factory ApprovalOutStatusEnumTypeTransformer() =>
      _instance ??= const ApprovalOutStatusEnumTypeTransformer._();

  const ApprovalOutStatusEnumTypeTransformer._();

  String encode(ApprovalOutStatusEnum data) => data._value;

  /// Returns the instance of [ApprovalOutStatusEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ApprovalOutStatusEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is ApprovalOutStatusEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'pending':
          return ApprovalOutStatusEnum.pending;
        case r'approved':
          return ApprovalOutStatusEnum.approved;
        case r'rejected':
          return ApprovalOutStatusEnum.rejected;
        case r'failed':
          return ApprovalOutStatusEnum.failed;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ApprovalOutStatusEnumTypeTransformer? _instance;
}
