//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class EventOut {
  /// Returns a new [EventOut] instance.
  EventOut({
    required this.allDay,
    required this.calendarId,
    required this.end,
    required this.eventId,
    this.location = '',
    this.notes = '',
    this.recurrenceId,
    required this.start,
    this.timeZone,
    required this.title,
    required this.uid,
  });

  bool allDay;

  String calendarId;

  /// as start; an all-day event's end is the day after its last day (exclusive)
  String end;

  String eventId;

  String location;

  String notes;

  String? recurrenceId;

  /// ISO date-time in the host's time zone, or YYYY-MM-DD for an all-day event
  String start;

  /// the event's own zone; none for all-day events
  String? timeZone;

  String title;

  String uid;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventOut &&
          other.allDay == allDay &&
          other.calendarId == calendarId &&
          other.end == end &&
          other.eventId == eventId &&
          other.location == location &&
          other.notes == notes &&
          other.recurrenceId == recurrenceId &&
          other.start == start &&
          other.timeZone == timeZone &&
          other.title == title &&
          other.uid == uid;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (allDay.hashCode) +
      (calendarId.hashCode) +
      (end.hashCode) +
      (eventId.hashCode) +
      (location.hashCode) +
      (notes.hashCode) +
      (recurrenceId == null ? 0 : recurrenceId!.hashCode) +
      (start.hashCode) +
      (timeZone == null ? 0 : timeZone!.hashCode) +
      (title.hashCode) +
      (uid.hashCode);

  @override
  String toString() =>
      'EventOut[allDay=$allDay, calendarId=$calendarId, end=$end, eventId=$eventId, location=$location, notes=$notes, recurrenceId=$recurrenceId, start=$start, timeZone=$timeZone, title=$title, uid=$uid]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'all_day'] = this.allDay;
    json[r'calendar_id'] = this.calendarId;
    json[r'end'] = this.end;
    json[r'event_id'] = this.eventId;
    json[r'location'] = this.location;
    json[r'notes'] = this.notes;
    if (this.recurrenceId != null) {
      json[r'recurrence_id'] = this.recurrenceId;
    } else {
      json[r'recurrence_id'] = null;
    }
    json[r'start'] = this.start;
    if (this.timeZone != null) {
      json[r'time_zone'] = this.timeZone;
    } else {
      json[r'time_zone'] = null;
    }
    json[r'title'] = this.title;
    json[r'uid'] = this.uid;
    return json;
  }

  /// Returns a new [EventOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static EventOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'all_day'),
            'Required key "EventOut[all_day]" is missing from JSON.');
        assert(json[r'all_day'] != null,
            'Required key "EventOut[all_day]" has a null value in JSON.');
        assert(json.containsKey(r'calendar_id'),
            'Required key "EventOut[calendar_id]" is missing from JSON.');
        assert(json[r'calendar_id'] != null,
            'Required key "EventOut[calendar_id]" has a null value in JSON.');
        assert(json.containsKey(r'end'),
            'Required key "EventOut[end]" is missing from JSON.');
        assert(json[r'end'] != null,
            'Required key "EventOut[end]" has a null value in JSON.');
        assert(json.containsKey(r'event_id'),
            'Required key "EventOut[event_id]" is missing from JSON.');
        assert(json[r'event_id'] != null,
            'Required key "EventOut[event_id]" has a null value in JSON.');
        assert(json.containsKey(r'start'),
            'Required key "EventOut[start]" is missing from JSON.');
        assert(json[r'start'] != null,
            'Required key "EventOut[start]" has a null value in JSON.');
        assert(json.containsKey(r'title'),
            'Required key "EventOut[title]" is missing from JSON.');
        assert(json[r'title'] != null,
            'Required key "EventOut[title]" has a null value in JSON.');
        assert(json.containsKey(r'uid'),
            'Required key "EventOut[uid]" is missing from JSON.');
        assert(json[r'uid'] != null,
            'Required key "EventOut[uid]" has a null value in JSON.');
        return true;
      }());

      return EventOut(
        allDay: mapValueOfType<bool>(json, r'all_day')!,
        calendarId: mapValueOfType<String>(json, r'calendar_id')!,
        end: mapValueOfType<String>(json, r'end')!,
        eventId: mapValueOfType<String>(json, r'event_id')!,
        location: mapValueOfType<String>(json, r'location') ?? '',
        notes: mapValueOfType<String>(json, r'notes') ?? '',
        recurrenceId: mapValueOfType<String>(json, r'recurrence_id'),
        start: mapValueOfType<String>(json, r'start')!,
        timeZone: mapValueOfType<String>(json, r'time_zone'),
        title: mapValueOfType<String>(json, r'title')!,
        uid: mapValueOfType<String>(json, r'uid')!,
      );
    }
    return null;
  }

  static List<EventOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <EventOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = EventOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, EventOut> mapFromJson(dynamic json) {
    final map = <String, EventOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = EventOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of EventOut-objects as value to a dart map
  static Map<String, List<EventOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<EventOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = EventOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'all_day',
    'calendar_id',
    'end',
    'event_id',
    'start',
    'title',
    'uid',
  };
}
