//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AccountSyncOut {
  /// Returns a new [AccountSyncOut] instance.
  AccountSyncOut({
    required this.accountId,
    required this.counts,
    this.lastAttempt,
    this.lastError,
    this.lastSuccess,
    this.nextAttempt,
    required this.state,
  });

  String accountId;

  SyncCounts counts;

  String? lastAttempt;

  /// a short message for the user; never a secret
  String? lastError;

  String? lastSuccess;

  String? nextAttempt;

  AccountSyncOutStateEnum state;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountSyncOut &&
          other.accountId == accountId &&
          other.counts == counts &&
          other.lastAttempt == lastAttempt &&
          other.lastError == lastError &&
          other.lastSuccess == lastSuccess &&
          other.nextAttempt == nextAttempt &&
          other.state == state;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accountId.hashCode) +
      (counts.hashCode) +
      (lastAttempt == null ? 0 : lastAttempt!.hashCode) +
      (lastError == null ? 0 : lastError!.hashCode) +
      (lastSuccess == null ? 0 : lastSuccess!.hashCode) +
      (nextAttempt == null ? 0 : nextAttempt!.hashCode) +
      (state.hashCode);

  @override
  String toString() =>
      'AccountSyncOut[accountId=$accountId, counts=$counts, lastAttempt=$lastAttempt, lastError=$lastError, lastSuccess=$lastSuccess, nextAttempt=$nextAttempt, state=$state]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'account_id'] = this.accountId;
    json[r'counts'] = this.counts;
    if (this.lastAttempt != null) {
      json[r'last_attempt'] = this.lastAttempt;
    } else {
      json[r'last_attempt'] = null;
    }
    if (this.lastError != null) {
      json[r'last_error'] = this.lastError;
    } else {
      json[r'last_error'] = null;
    }
    if (this.lastSuccess != null) {
      json[r'last_success'] = this.lastSuccess;
    } else {
      json[r'last_success'] = null;
    }
    if (this.nextAttempt != null) {
      json[r'next_attempt'] = this.nextAttempt;
    } else {
      json[r'next_attempt'] = null;
    }
    json[r'state'] = this.state;
    return json;
  }

  /// Returns a new [AccountSyncOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AccountSyncOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'account_id'),
            'Required key "AccountSyncOut[account_id]" is missing from JSON.');
        assert(json[r'account_id'] != null,
            'Required key "AccountSyncOut[account_id]" has a null value in JSON.');
        assert(json.containsKey(r'counts'),
            'Required key "AccountSyncOut[counts]" is missing from JSON.');
        assert(json[r'counts'] != null,
            'Required key "AccountSyncOut[counts]" has a null value in JSON.');
        assert(json.containsKey(r'state'),
            'Required key "AccountSyncOut[state]" is missing from JSON.');
        assert(json[r'state'] != null,
            'Required key "AccountSyncOut[state]" has a null value in JSON.');
        return true;
      }());

      return AccountSyncOut(
        accountId: mapValueOfType<String>(json, r'account_id')!,
        counts: SyncCounts.fromJson(json[r'counts'])!,
        lastAttempt: mapValueOfType<String>(json, r'last_attempt'),
        lastError: mapValueOfType<String>(json, r'last_error'),
        lastSuccess: mapValueOfType<String>(json, r'last_success'),
        nextAttempt: mapValueOfType<String>(json, r'next_attempt'),
        state: AccountSyncOutStateEnum.fromJson(json[r'state'])!,
      );
    }
    return null;
  }

  static List<AccountSyncOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AccountSyncOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AccountSyncOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AccountSyncOut> mapFromJson(dynamic json) {
    final map = <String, AccountSyncOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AccountSyncOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AccountSyncOut-objects as value to a dart map
  static Map<String, List<AccountSyncOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AccountSyncOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AccountSyncOut.listFromJson(
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
    'counts',
    'state',
  };
}

enum AccountSyncOutStateEnum {
  idle._(r'idle'),
  syncing._(r'syncing'),
  error._(r'error'),
  ;

  /// Instantiate a new enum with the provided value.
  const AccountSyncOutStateEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [AccountSyncOutStateEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static AccountSyncOutStateEnum? fromJson(dynamic value) =>
      AccountSyncOutStateEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [AccountSyncOutStateEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<AccountSyncOutStateEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AccountSyncOutStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AccountSyncOutStateEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AccountSyncOutStateEnum] to String,
/// and [decode] dynamic data back to [AccountSyncOutStateEnum].
class AccountSyncOutStateEnumTypeTransformer {
  factory AccountSyncOutStateEnumTypeTransformer() =>
      _instance ??= const AccountSyncOutStateEnumTypeTransformer._();

  const AccountSyncOutStateEnumTypeTransformer._();

  String encode(AccountSyncOutStateEnum data) => data._value;

  /// Returns the instance of [AccountSyncOutStateEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AccountSyncOutStateEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is AccountSyncOutStateEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'idle':
          return AccountSyncOutStateEnum.idle;
        case r'syncing':
          return AccountSyncOutStateEnum.syncing;
        case r'error':
          return AccountSyncOutStateEnum.error;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static AccountSyncOutStateEnumTypeTransformer? _instance;
}
