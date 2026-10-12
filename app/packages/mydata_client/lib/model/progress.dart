//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class Progress {
  /// Returns a new [Progress] instance.
  Progress({
    required this.completed,
    required this.percent,
    required this.status,
    required this.total,
  });

  int completed;

  num percent;

  String status;

  int total;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Progress &&
          other.completed == completed &&
          other.percent == percent &&
          other.status == status &&
          other.total == total;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (completed.hashCode) +
      (percent.hashCode) +
      (status.hashCode) +
      (total.hashCode);

  @override
  String toString() =>
      'Progress[completed=$completed, percent=$percent, status=$status, total=$total]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'completed'] = this.completed;
    json[r'percent'] = this.percent;
    json[r'status'] = this.status;
    json[r'total'] = this.total;
    return json;
  }

  /// Returns a new [Progress] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static Progress? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'completed'),
            'Required key "Progress[completed]" is missing from JSON.');
        assert(json[r'completed'] != null,
            'Required key "Progress[completed]" has a null value in JSON.');
        assert(json.containsKey(r'percent'),
            'Required key "Progress[percent]" is missing from JSON.');
        assert(json[r'percent'] != null,
            'Required key "Progress[percent]" has a null value in JSON.');
        assert(json.containsKey(r'status'),
            'Required key "Progress[status]" is missing from JSON.');
        assert(json[r'status'] != null,
            'Required key "Progress[status]" has a null value in JSON.');
        assert(json.containsKey(r'total'),
            'Required key "Progress[total]" is missing from JSON.');
        assert(json[r'total'] != null,
            'Required key "Progress[total]" has a null value in JSON.');
        return true;
      }());

      return Progress(
        completed: mapValueOfType<int>(json, r'completed')!,
        percent: num.parse('${json[r'percent']}'),
        status: mapValueOfType<String>(json, r'status')!,
        total: mapValueOfType<int>(json, r'total')!,
      );
    }
    return null;
  }

  static List<Progress> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <Progress>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = Progress.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, Progress> mapFromJson(dynamic json) {
    final map = <String, Progress>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = Progress.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of Progress-objects as value to a dart map
  static Map<String, List<Progress>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<Progress>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = Progress.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'completed',
    'percent',
    'status',
    'total',
  };
}
