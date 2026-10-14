//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class FollowedChangeOut {
  /// Returns a new [FollowedChangeOut] instance.
  FollowedChangeOut({
    required this.accountId,
    this.differences = const [],
    required this.followed,
    required this.sourceLabel,
  });

  /// the followed source (GET /sources): \"mac\" or an iCloud account id
  String accountId;

  /// what differs from the contact of yours, after normalising (case, spacing, emails in lower case, phones in E.164), in a contact page's order: name, nickname, company, job_title, phone, email, address, birthday, url, note (not for This Mac, which reads no notes), photo, other (any other detail)
  List<String> differences;

  /// the followed copy as it is now (hidden from lists while the contact stands for it)
  ContactDetailOut followed;

  /// that source inside a sentence (\"the iCloud account you@example.com\", \"this Mac\")
  String sourceLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FollowedChangeOut &&
          other.accountId == accountId &&
          _deepEquality.equals(other.differences, differences) &&
          other.followed == followed &&
          other.sourceLabel == sourceLabel;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accountId.hashCode) +
      (differences.hashCode) +
      (followed.hashCode) +
      (sourceLabel.hashCode);

  @override
  String toString() =>
      'FollowedChangeOut[accountId=$accountId, differences=$differences, followed=$followed, sourceLabel=$sourceLabel]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'account_id'] = this.accountId;
    json[r'differences'] = this.differences;
    json[r'followed'] = this.followed;
    json[r'source_label'] = this.sourceLabel;
    return json;
  }

  /// Returns a new [FollowedChangeOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static FollowedChangeOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'account_id'),
            'Required key "FollowedChangeOut[account_id]" is missing from JSON.');
        assert(json[r'account_id'] != null,
            'Required key "FollowedChangeOut[account_id]" has a null value in JSON.');
        assert(json.containsKey(r'differences'),
            'Required key "FollowedChangeOut[differences]" is missing from JSON.');
        assert(json[r'differences'] != null,
            'Required key "FollowedChangeOut[differences]" has a null value in JSON.');
        assert(json.containsKey(r'followed'),
            'Required key "FollowedChangeOut[followed]" is missing from JSON.');
        assert(json[r'followed'] != null,
            'Required key "FollowedChangeOut[followed]" has a null value in JSON.');
        assert(json.containsKey(r'source_label'),
            'Required key "FollowedChangeOut[source_label]" is missing from JSON.');
        assert(json[r'source_label'] != null,
            'Required key "FollowedChangeOut[source_label]" has a null value in JSON.');
        return true;
      }());

      return FollowedChangeOut(
        accountId: mapValueOfType<String>(json, r'account_id')!,
        differences: json[r'differences'] is Iterable
            ? (json[r'differences'] as Iterable)
                .cast<String>()
                .toList(growable: false)
            : const [],
        followed: ContactDetailOut.fromJson(json[r'followed'])!,
        sourceLabel: mapValueOfType<String>(json, r'source_label')!,
      );
    }
    return null;
  }

  static List<FollowedChangeOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <FollowedChangeOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = FollowedChangeOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, FollowedChangeOut> mapFromJson(dynamic json) {
    final map = <String, FollowedChangeOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = FollowedChangeOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of FollowedChangeOut-objects as value to a dart map
  static Map<String, List<FollowedChangeOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<FollowedChangeOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = FollowedChangeOut.listFromJson(
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
    'differences',
    'followed',
    'source_label',
  };
}
