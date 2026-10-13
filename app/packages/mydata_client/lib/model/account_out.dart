//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AccountOut {
  /// Returns a new [AccountOut] instance.
  AccountOut({
    required this.createdAt,
    required this.email,
    required this.id,
    required this.label,
    required this.provider,
  });

  String createdAt;

  String email;

  String id;

  String label;

  String provider;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountOut &&
          other.createdAt == createdAt &&
          other.email == email &&
          other.id == id &&
          other.label == label &&
          other.provider == provider;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (createdAt.hashCode) +
      (email.hashCode) +
      (id.hashCode) +
      (label.hashCode) +
      (provider.hashCode);

  @override
  String toString() =>
      'AccountOut[createdAt=$createdAt, email=$email, id=$id, label=$label, provider=$provider]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'created_at'] = this.createdAt;
    json[r'email'] = this.email;
    json[r'id'] = this.id;
    json[r'label'] = this.label;
    json[r'provider'] = this.provider;
    return json;
  }

  /// Returns a new [AccountOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AccountOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'created_at'),
            'Required key "AccountOut[created_at]" is missing from JSON.');
        assert(json[r'created_at'] != null,
            'Required key "AccountOut[created_at]" has a null value in JSON.');
        assert(json.containsKey(r'email'),
            'Required key "AccountOut[email]" is missing from JSON.');
        assert(json[r'email'] != null,
            'Required key "AccountOut[email]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "AccountOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "AccountOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'label'),
            'Required key "AccountOut[label]" is missing from JSON.');
        assert(json[r'label'] != null,
            'Required key "AccountOut[label]" has a null value in JSON.');
        assert(json.containsKey(r'provider'),
            'Required key "AccountOut[provider]" is missing from JSON.');
        assert(json[r'provider'] != null,
            'Required key "AccountOut[provider]" has a null value in JSON.');
        return true;
      }());

      return AccountOut(
        createdAt: mapValueOfType<String>(json, r'created_at')!,
        email: mapValueOfType<String>(json, r'email')!,
        id: mapValueOfType<String>(json, r'id')!,
        label: mapValueOfType<String>(json, r'label')!,
        provider: mapValueOfType<String>(json, r'provider')!,
      );
    }
    return null;
  }

  static List<AccountOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AccountOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AccountOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AccountOut> mapFromJson(dynamic json) {
    final map = <String, AccountOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AccountOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AccountOut-objects as value to a dart map
  static Map<String, List<AccountOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AccountOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AccountOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'created_at',
    'email',
    'id',
    'label',
    'provider',
  };
}
