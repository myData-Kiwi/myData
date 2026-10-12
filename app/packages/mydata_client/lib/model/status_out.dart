//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class StatusOut {
  /// Returns a new [StatusOut] instance.
  StatusOut({
    required this.agentsConnected,
    required this.assistantEnabled,
    required this.demoDate,
    this.lastError,
    required this.memory,
    required this.model,
    required this.ready,
    required this.today,
    required this.uptimeSeconds,
    required this.version,
  });

  /// agent tokens used in the last five minutes
  int agentsConnected;

  /// false when the user switched the assistant off
  bool assistantEnabled;

  /// true while today is pinned to the demo data's date
  bool demoDate;

  ErrorOut? lastError;

  MemoryOut memory;

  ModelOut model;

  /// true when the assistant can answer
  bool ready;

  /// the date the host treats as today
  String today;

  num uptimeSeconds;

  String version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatusOut &&
          other.agentsConnected == agentsConnected &&
          other.assistantEnabled == assistantEnabled &&
          other.demoDate == demoDate &&
          other.lastError == lastError &&
          other.memory == memory &&
          other.model == model &&
          other.ready == ready &&
          other.today == today &&
          other.uptimeSeconds == uptimeSeconds &&
          other.version == version;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (agentsConnected.hashCode) +
      (assistantEnabled.hashCode) +
      (demoDate.hashCode) +
      (lastError == null ? 0 : lastError!.hashCode) +
      (memory.hashCode) +
      (model.hashCode) +
      (ready.hashCode) +
      (today.hashCode) +
      (uptimeSeconds.hashCode) +
      (version.hashCode);

  @override
  String toString() =>
      'StatusOut[agentsConnected=$agentsConnected, assistantEnabled=$assistantEnabled, demoDate=$demoDate, lastError=$lastError, memory=$memory, model=$model, ready=$ready, today=$today, uptimeSeconds=$uptimeSeconds, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'agents_connected'] = this.agentsConnected;
    json[r'assistant_enabled'] = this.assistantEnabled;
    json[r'demo_date'] = this.demoDate;
    if (this.lastError != null) {
      json[r'last_error'] = this.lastError;
    } else {
      json[r'last_error'] = null;
    }
    json[r'memory'] = this.memory;
    json[r'model'] = this.model;
    json[r'ready'] = this.ready;
    json[r'today'] = this.today;
    json[r'uptime_seconds'] = this.uptimeSeconds;
    json[r'version'] = this.version;
    return json;
  }

  /// Returns a new [StatusOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static StatusOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'agents_connected'),
            'Required key "StatusOut[agents_connected]" is missing from JSON.');
        assert(json[r'agents_connected'] != null,
            'Required key "StatusOut[agents_connected]" has a null value in JSON.');
        assert(json.containsKey(r'assistant_enabled'),
            'Required key "StatusOut[assistant_enabled]" is missing from JSON.');
        assert(json[r'assistant_enabled'] != null,
            'Required key "StatusOut[assistant_enabled]" has a null value in JSON.');
        assert(json.containsKey(r'demo_date'),
            'Required key "StatusOut[demo_date]" is missing from JSON.');
        assert(json[r'demo_date'] != null,
            'Required key "StatusOut[demo_date]" has a null value in JSON.');
        assert(json.containsKey(r'memory'),
            'Required key "StatusOut[memory]" is missing from JSON.');
        assert(json[r'memory'] != null,
            'Required key "StatusOut[memory]" has a null value in JSON.');
        assert(json.containsKey(r'model'),
            'Required key "StatusOut[model]" is missing from JSON.');
        assert(json[r'model'] != null,
            'Required key "StatusOut[model]" has a null value in JSON.');
        assert(json.containsKey(r'ready'),
            'Required key "StatusOut[ready]" is missing from JSON.');
        assert(json[r'ready'] != null,
            'Required key "StatusOut[ready]" has a null value in JSON.');
        assert(json.containsKey(r'today'),
            'Required key "StatusOut[today]" is missing from JSON.');
        assert(json[r'today'] != null,
            'Required key "StatusOut[today]" has a null value in JSON.');
        assert(json.containsKey(r'uptime_seconds'),
            'Required key "StatusOut[uptime_seconds]" is missing from JSON.');
        assert(json[r'uptime_seconds'] != null,
            'Required key "StatusOut[uptime_seconds]" has a null value in JSON.');
        assert(json.containsKey(r'version'),
            'Required key "StatusOut[version]" is missing from JSON.');
        assert(json[r'version'] != null,
            'Required key "StatusOut[version]" has a null value in JSON.');
        return true;
      }());

      return StatusOut(
        agentsConnected: mapValueOfType<int>(json, r'agents_connected')!,
        assistantEnabled: mapValueOfType<bool>(json, r'assistant_enabled')!,
        demoDate: mapValueOfType<bool>(json, r'demo_date')!,
        lastError: ErrorOut.fromJson(json[r'last_error']),
        memory: MemoryOut.fromJson(json[r'memory'])!,
        model: ModelOut.fromJson(json[r'model'])!,
        ready: mapValueOfType<bool>(json, r'ready')!,
        today: mapValueOfType<String>(json, r'today')!,
        uptimeSeconds: num.parse('${json[r'uptime_seconds']}'),
        version: mapValueOfType<String>(json, r'version')!,
      );
    }
    return null;
  }

  static List<StatusOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <StatusOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = StatusOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, StatusOut> mapFromJson(dynamic json) {
    final map = <String, StatusOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = StatusOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of StatusOut-objects as value to a dart map
  static Map<String, List<StatusOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<StatusOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = StatusOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'agents_connected',
    'assistant_enabled',
    'demo_date',
    'memory',
    'model',
    'ready',
    'today',
    'uptime_seconds',
    'version',
  };
}
