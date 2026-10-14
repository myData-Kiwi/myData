//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportMatchOut {
  /// Returns a new [ImportMatchOut] instance.
  ImportMatchOut({
    this.accountId,
    this.contactId,
    required this.displayName,
    this.itemIndex,
    this.signals = const [],
    required this.source_,
    required this.strength,
  });

  String? accountId;

  String? contactId;

  String displayName;

  /// for source file: the earlier card's index
  int? itemIndex;

  /// origin, uid, identical, email, phone, name
  List<String> signals;

  /// mydata (owned), icloud, mac, or file (an earlier card in the same input)
  String source_;

  /// same_origin (imported from this card before), strong (same email or phone), suggestion (same name only: never acted on)
  String strength;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportMatchOut &&
          other.accountId == accountId &&
          other.contactId == contactId &&
          other.displayName == displayName &&
          other.itemIndex == itemIndex &&
          _deepEquality.equals(other.signals, signals) &&
          other.source_ == source_ &&
          other.strength == strength;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accountId == null ? 0 : accountId!.hashCode) +
      (contactId == null ? 0 : contactId!.hashCode) +
      (displayName.hashCode) +
      (itemIndex == null ? 0 : itemIndex!.hashCode) +
      (signals.hashCode) +
      (source_.hashCode) +
      (strength.hashCode);

  @override
  String toString() =>
      'ImportMatchOut[accountId=$accountId, contactId=$contactId, displayName=$displayName, itemIndex=$itemIndex, signals=$signals, source_=$source_, strength=$strength]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.accountId != null) {
      json[r'account_id'] = this.accountId;
    } else {
      json[r'account_id'] = null;
    }
    if (this.contactId != null) {
      json[r'contact_id'] = this.contactId;
    } else {
      json[r'contact_id'] = null;
    }
    json[r'display_name'] = this.displayName;
    if (this.itemIndex != null) {
      json[r'item_index'] = this.itemIndex;
    } else {
      json[r'item_index'] = null;
    }
    json[r'signals'] = this.signals;
    json[r'source'] = this.source_;
    json[r'strength'] = this.strength;
    return json;
  }

  /// Returns a new [ImportMatchOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportMatchOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'display_name'),
            'Required key "ImportMatchOut[display_name]" is missing from JSON.');
        assert(json[r'display_name'] != null,
            'Required key "ImportMatchOut[display_name]" has a null value in JSON.');
        assert(json.containsKey(r'signals'),
            'Required key "ImportMatchOut[signals]" is missing from JSON.');
        assert(json[r'signals'] != null,
            'Required key "ImportMatchOut[signals]" has a null value in JSON.');
        assert(json.containsKey(r'source'),
            'Required key "ImportMatchOut[source]" is missing from JSON.');
        assert(json[r'source'] != null,
            'Required key "ImportMatchOut[source]" has a null value in JSON.');
        assert(json.containsKey(r'strength'),
            'Required key "ImportMatchOut[strength]" is missing from JSON.');
        assert(json[r'strength'] != null,
            'Required key "ImportMatchOut[strength]" has a null value in JSON.');
        return true;
      }());

      return ImportMatchOut(
        accountId: mapValueOfType<String>(json, r'account_id'),
        contactId: mapValueOfType<String>(json, r'contact_id'),
        displayName: mapValueOfType<String>(json, r'display_name')!,
        itemIndex: mapValueOfType<int>(json, r'item_index'),
        signals: json[r'signals'] is Iterable
            ? (json[r'signals'] as Iterable)
                .cast<String>()
                .toList(growable: false)
            : const [],
        source_: mapValueOfType<String>(json, r'source')!,
        strength: mapValueOfType<String>(json, r'strength')!,
      );
    }
    return null;
  }

  static List<ImportMatchOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportMatchOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportMatchOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportMatchOut> mapFromJson(dynamic json) {
    final map = <String, ImportMatchOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportMatchOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportMatchOut-objects as value to a dart map
  static Map<String, List<ImportMatchOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportMatchOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportMatchOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'display_name',
    'signals',
    'source',
    'strength',
  };
}
