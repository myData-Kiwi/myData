//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SourcesOut {
  /// Returns a new [SourcesOut] instance.
  SourcesOut({
    this.sources = const [],
  });

  List<SourceOut> sources;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourcesOut && _deepEquality.equals(other.sources, sources);

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (sources.hashCode);

  @override
  String toString() => 'SourcesOut[sources=$sources]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'sources'] = this.sources;
    return json;
  }

  /// Returns a new [SourcesOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SourcesOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'sources'),
            'Required key "SourcesOut[sources]" is missing from JSON.');
        assert(json[r'sources'] != null,
            'Required key "SourcesOut[sources]" has a null value in JSON.');
        return true;
      }());

      return SourcesOut(
        sources: SourceOut.listFromJson(json[r'sources']),
      );
    }
    return null;
  }

  static List<SourcesOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <SourcesOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SourcesOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SourcesOut> mapFromJson(dynamic json) {
    final map = <String, SourcesOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SourcesOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SourcesOut-objects as value to a dart map
  static Map<String, List<SourcesOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<SourcesOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SourcesOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'sources',
  };
}
