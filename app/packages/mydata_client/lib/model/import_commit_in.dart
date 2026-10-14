//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ImportCommitIn {
  /// Returns a new [ImportCommitIn] instance.
  ImportCommitIn({
    this.acceptLosses = false,
    this.addressBookId,
    this.choices = const [],
  });

  /// needed when the preview has losses
  bool acceptLosses;

  /// an owned address book; default the host's \"myData\" one (made if missing)
  String? addressBookId;

  /// actions other than each card's default
  List<ImportChoiceIn> choices;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportCommitIn &&
          other.acceptLosses == acceptLosses &&
          other.addressBookId == addressBookId &&
          _deepEquality.equals(other.choices, choices);

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (acceptLosses.hashCode) +
      (addressBookId == null ? 0 : addressBookId!.hashCode) +
      (choices.hashCode);

  @override
  String toString() =>
      'ImportCommitIn[acceptLosses=$acceptLosses, addressBookId=$addressBookId, choices=$choices]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'accept_losses'] = this.acceptLosses;
    if (this.addressBookId != null) {
      json[r'address_book_id'] = this.addressBookId;
    } else {
      json[r'address_book_id'] = null;
    }
    json[r'choices'] = this.choices;
    return json;
  }

  /// Returns a new [ImportCommitIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ImportCommitIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        return true;
      }());

      return ImportCommitIn(
        acceptLosses: mapValueOfType<bool>(json, r'accept_losses') ?? false,
        addressBookId: mapValueOfType<String>(json, r'address_book_id'),
        choices: ImportChoiceIn.listFromJson(json[r'choices']),
      );
    }
    return null;
  }

  static List<ImportCommitIn> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ImportCommitIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ImportCommitIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ImportCommitIn> mapFromJson(dynamic json) {
    final map = <String, ImportCommitIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ImportCommitIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ImportCommitIn-objects as value to a dart map
  static Map<String, List<ImportCommitIn>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ImportCommitIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ImportCommitIn.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{};
}
