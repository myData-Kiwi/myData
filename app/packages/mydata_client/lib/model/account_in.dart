//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AccountIn {
  /// Returns a new [AccountIn] instance.
  AccountIn({
    required this.email,
    required this.password,
    required this.provider,
  });

  /// the email of the Apple Account (the sign-in email, which may differ from an address on the user's own domain)
  String email;

  /// an app-specific password. Verified with the provider, then kept only in the Keychain; never returned, logged or written to a file
  String password;

  AccountInProviderEnum provider;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountIn &&
          other.email == email &&
          other.password == password &&
          other.provider == provider;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (email.hashCode) + (password.hashCode) + (provider.hashCode);

  @override
  String toString() =>
      'AccountIn[email=$email, password=$password, provider=$provider]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'email'] = this.email;
    json[r'password'] = this.password;
    json[r'provider'] = this.provider;
    return json;
  }

  /// Returns a new [AccountIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AccountIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'email'),
            'Required key "AccountIn[email]" is missing from JSON.');
        assert(json[r'email'] != null,
            'Required key "AccountIn[email]" has a null value in JSON.');
        assert(json.containsKey(r'password'),
            'Required key "AccountIn[password]" is missing from JSON.');
        assert(json[r'password'] != null,
            'Required key "AccountIn[password]" has a null value in JSON.');
        assert(json.containsKey(r'provider'),
            'Required key "AccountIn[provider]" is missing from JSON.');
        assert(json[r'provider'] != null,
            'Required key "AccountIn[provider]" has a null value in JSON.');
        return true;
      }());

      return AccountIn(
        email: mapValueOfType<String>(json, r'email')!,
        password: mapValueOfType<String>(json, r'password')!,
        provider: AccountInProviderEnum.fromJson(json[r'provider'])!,
      );
    }
    return null;
  }

  static List<AccountIn> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AccountIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AccountIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AccountIn> mapFromJson(dynamic json) {
    final map = <String, AccountIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AccountIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AccountIn-objects as value to a dart map
  static Map<String, List<AccountIn>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AccountIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AccountIn.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'email',
    'password',
    'provider',
  };
}

enum AccountInProviderEnum {
  icloud._(r'icloud'),
  ;

  /// Instantiate a new enum with the provided value.
  const AccountInProviderEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [AccountInProviderEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static AccountInProviderEnum? fromJson(dynamic value) =>
      AccountInProviderEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [AccountInProviderEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<AccountInProviderEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AccountInProviderEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AccountInProviderEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [AccountInProviderEnum] to String,
/// and [decode] dynamic data back to [AccountInProviderEnum].
class AccountInProviderEnumTypeTransformer {
  factory AccountInProviderEnumTypeTransformer() =>
      _instance ??= const AccountInProviderEnumTypeTransformer._();

  const AccountInProviderEnumTypeTransformer._();

  String encode(AccountInProviderEnum data) => data._value;

  /// Returns the instance of [AccountInProviderEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  AccountInProviderEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is AccountInProviderEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'icloud':
          return AccountInProviderEnum.icloud;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static AccountInProviderEnumTypeTransformer? _instance;
}
