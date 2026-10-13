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
    required this.apiVersion,
    required this.assistantEnabled,
    required this.conversationEpoch,
    required this.demoDate,
    this.lastError,
    this.macAvailable = false,
    required this.memory,
    required this.mode,
    required this.model,
    required this.ready,
    this.stale = false,
    required this.theme,
    required this.today,
    required this.uptimeSeconds,
    required this.version,
  });

  /// agent tokens used in the last five minutes
  int agentsConnected;

  /// a hash of this host's API (its routes and schemas); an app built against another API version replaces the host
  String apiVersion;

  /// false when the user switched the assistant off
  bool assistantEnabled;

  /// moves on by one at every switch between demo and real mode, which ends every conversation: an app that sees it change starts a new conversation and says why
  ///
  /// Minimum value: 0
  int conversationEpoch;

  /// true while today is pinned to the demo data's date
  bool demoDate;

  ErrorOut? lastError;

  /// true on a Mac host: the This Mac source exists
  bool macAvailable;

  MemoryOut memory;

  /// demo: no source on, the tools serve fake data and the date is pinned; real: a source is on (an account is linked, or This Mac is turned on) and the tools serve the mirrored data, with the real date
  StatusOutModeEnum mode;

  ModelOut model;

  /// true when the assistant can answer
  bool ready;

  /// true when the host's code on disk changed since it started; an app replaces it when the code on disk is the API it was built against
  bool stale;

  /// the theme every app uses; mode is per device and not stored here
  String theme;

  /// the date the host treats as today
  String today;

  num uptimeSeconds;

  String version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatusOut &&
          other.agentsConnected == agentsConnected &&
          other.apiVersion == apiVersion &&
          other.assistantEnabled == assistantEnabled &&
          other.conversationEpoch == conversationEpoch &&
          other.demoDate == demoDate &&
          other.lastError == lastError &&
          other.macAvailable == macAvailable &&
          other.memory == memory &&
          other.mode == mode &&
          other.model == model &&
          other.ready == ready &&
          other.stale == stale &&
          other.theme == theme &&
          other.today == today &&
          other.uptimeSeconds == uptimeSeconds &&
          other.version == version;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (agentsConnected.hashCode) +
      (apiVersion.hashCode) +
      (assistantEnabled.hashCode) +
      (conversationEpoch.hashCode) +
      (demoDate.hashCode) +
      (lastError == null ? 0 : lastError!.hashCode) +
      (macAvailable.hashCode) +
      (memory.hashCode) +
      (mode.hashCode) +
      (model.hashCode) +
      (ready.hashCode) +
      (stale.hashCode) +
      (theme.hashCode) +
      (today.hashCode) +
      (uptimeSeconds.hashCode) +
      (version.hashCode);

  @override
  String toString() =>
      'StatusOut[agentsConnected=$agentsConnected, apiVersion=$apiVersion, assistantEnabled=$assistantEnabled, conversationEpoch=$conversationEpoch, demoDate=$demoDate, lastError=$lastError, macAvailable=$macAvailable, memory=$memory, mode=$mode, model=$model, ready=$ready, stale=$stale, theme=$theme, today=$today, uptimeSeconds=$uptimeSeconds, version=$version]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'agents_connected'] = this.agentsConnected;
    json[r'api_version'] = this.apiVersion;
    json[r'assistant_enabled'] = this.assistantEnabled;
    json[r'conversation_epoch'] = this.conversationEpoch;
    json[r'demo_date'] = this.demoDate;
    if (this.lastError != null) {
      json[r'last_error'] = this.lastError;
    } else {
      json[r'last_error'] = null;
    }
    json[r'mac_available'] = this.macAvailable;
    json[r'memory'] = this.memory;
    json[r'mode'] = this.mode;
    json[r'model'] = this.model;
    json[r'ready'] = this.ready;
    json[r'stale'] = this.stale;
    json[r'theme'] = this.theme;
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
        assert(json.containsKey(r'api_version'),
            'Required key "StatusOut[api_version]" is missing from JSON.');
        assert(json[r'api_version'] != null,
            'Required key "StatusOut[api_version]" has a null value in JSON.');
        assert(json.containsKey(r'assistant_enabled'),
            'Required key "StatusOut[assistant_enabled]" is missing from JSON.');
        assert(json[r'assistant_enabled'] != null,
            'Required key "StatusOut[assistant_enabled]" has a null value in JSON.');
        assert(json.containsKey(r'conversation_epoch'),
            'Required key "StatusOut[conversation_epoch]" is missing from JSON.');
        assert(json[r'conversation_epoch'] != null,
            'Required key "StatusOut[conversation_epoch]" has a null value in JSON.');
        assert(json.containsKey(r'demo_date'),
            'Required key "StatusOut[demo_date]" is missing from JSON.');
        assert(json[r'demo_date'] != null,
            'Required key "StatusOut[demo_date]" has a null value in JSON.');
        assert(json.containsKey(r'memory'),
            'Required key "StatusOut[memory]" is missing from JSON.');
        assert(json[r'memory'] != null,
            'Required key "StatusOut[memory]" has a null value in JSON.');
        assert(json.containsKey(r'mode'),
            'Required key "StatusOut[mode]" is missing from JSON.');
        assert(json[r'mode'] != null,
            'Required key "StatusOut[mode]" has a null value in JSON.');
        assert(json.containsKey(r'model'),
            'Required key "StatusOut[model]" is missing from JSON.');
        assert(json[r'model'] != null,
            'Required key "StatusOut[model]" has a null value in JSON.');
        assert(json.containsKey(r'ready'),
            'Required key "StatusOut[ready]" is missing from JSON.');
        assert(json[r'ready'] != null,
            'Required key "StatusOut[ready]" has a null value in JSON.');
        assert(json.containsKey(r'theme'),
            'Required key "StatusOut[theme]" is missing from JSON.');
        assert(json[r'theme'] != null,
            'Required key "StatusOut[theme]" has a null value in JSON.');
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
        apiVersion: mapValueOfType<String>(json, r'api_version')!,
        assistantEnabled: mapValueOfType<bool>(json, r'assistant_enabled')!,
        conversationEpoch: mapValueOfType<int>(json, r'conversation_epoch')!,
        demoDate: mapValueOfType<bool>(json, r'demo_date')!,
        lastError: ErrorOut.fromJson(json[r'last_error']),
        macAvailable: mapValueOfType<bool>(json, r'mac_available') ?? false,
        memory: MemoryOut.fromJson(json[r'memory'])!,
        mode: StatusOutModeEnum.fromJson(json[r'mode'])!,
        model: ModelOut.fromJson(json[r'model'])!,
        ready: mapValueOfType<bool>(json, r'ready')!,
        stale: mapValueOfType<bool>(json, r'stale') ?? false,
        theme: mapValueOfType<String>(json, r'theme')!,
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
    'api_version',
    'assistant_enabled',
    'conversation_epoch',
    'demo_date',
    'memory',
    'mode',
    'model',
    'ready',
    'theme',
    'today',
    'uptime_seconds',
    'version',
  };
}

/// demo: no source on, the tools serve fake data and the date is pinned; real: a source is on (an account is linked, or This Mac is turned on) and the tools serve the mirrored data, with the real date
enum StatusOutModeEnum {
  demo._(r'demo'),
  real._(r'real'),
  ;

  /// Instantiate a new enum with the provided value.
  const StatusOutModeEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [StatusOutModeEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static StatusOutModeEnum? fromJson(dynamic value) =>
      StatusOutModeEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [StatusOutModeEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<StatusOutModeEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <StatusOutModeEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = StatusOutModeEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [StatusOutModeEnum] to String,
/// and [decode] dynamic data back to [StatusOutModeEnum].
class StatusOutModeEnumTypeTransformer {
  factory StatusOutModeEnumTypeTransformer() =>
      _instance ??= const StatusOutModeEnumTypeTransformer._();

  const StatusOutModeEnumTypeTransformer._();

  String encode(StatusOutModeEnum data) => data._value;

  /// Returns the instance of [StatusOutModeEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  StatusOutModeEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is StatusOutModeEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'demo':
          return StatusOutModeEnum.demo;
        case r'real':
          return StatusOutModeEnum.real;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static StatusOutModeEnumTypeTransformer? _instance;
}
