//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class EventsOut {
  /// Returns a new [EventsOut] instance.
  EventsOut({
    this.coverage = const [],
    this.events = const [],
  });

  /// per source holding calendars, which days it holds. When a source is not complete, events on days outside its range are not known: do not show those days as empty
  List<CoverageOut> coverage;

  List<EventOut> events;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventsOut &&
          _deepEquality.equals(other.coverage, coverage) &&
          _deepEquality.equals(other.events, events);

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (coverage.hashCode) + (events.hashCode);

  @override
  String toString() => 'EventsOut[coverage=$coverage, events=$events]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'coverage'] = this.coverage;
    json[r'events'] = this.events;
    return json;
  }

  /// Returns a new [EventsOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static EventsOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'coverage'),
            'Required key "EventsOut[coverage]" is missing from JSON.');
        assert(json[r'coverage'] != null,
            'Required key "EventsOut[coverage]" has a null value in JSON.');
        assert(json.containsKey(r'events'),
            'Required key "EventsOut[events]" is missing from JSON.');
        assert(json[r'events'] != null,
            'Required key "EventsOut[events]" has a null value in JSON.');
        return true;
      }());

      return EventsOut(
        coverage: CoverageOut.listFromJson(json[r'coverage']),
        events: EventOut.listFromJson(json[r'events']),
      );
    }
    return null;
  }

  static List<EventsOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <EventsOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = EventsOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, EventsOut> mapFromJson(dynamic json) {
    final map = <String, EventsOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = EventsOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of EventsOut-objects as value to a dart map
  static Map<String, List<EventsOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<EventsOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = EventsOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'coverage',
    'events',
  };
}
