//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class ModelOut {
  /// Returns a new [ModelOut] instance.
  ModelOut({
    this.error,
    required this.loaded,
    required this.name,
    required this.ollamaReachable,
    required this.ollamaStartedByHost,
    this.progress,
    required this.state,
  });

  String? error;

  bool loaded;

  String name;

  bool ollamaReachable;

  bool ollamaStartedByHost;

  Progress? progress;

  ModelOutStateEnum state;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelOut &&
          other.error == error &&
          other.loaded == loaded &&
          other.name == name &&
          other.ollamaReachable == ollamaReachable &&
          other.ollamaStartedByHost == ollamaStartedByHost &&
          other.progress == progress &&
          other.state == state;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (error == null ? 0 : error!.hashCode) +
      (loaded.hashCode) +
      (name.hashCode) +
      (ollamaReachable.hashCode) +
      (ollamaStartedByHost.hashCode) +
      (progress == null ? 0 : progress!.hashCode) +
      (state.hashCode);

  @override
  String toString() =>
      'ModelOut[error=$error, loaded=$loaded, name=$name, ollamaReachable=$ollamaReachable, ollamaStartedByHost=$ollamaStartedByHost, progress=$progress, state=$state]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.error != null) {
      json[r'error'] = this.error;
    } else {
      json[r'error'] = null;
    }
    json[r'loaded'] = this.loaded;
    json[r'name'] = this.name;
    json[r'ollama_reachable'] = this.ollamaReachable;
    json[r'ollama_started_by_host'] = this.ollamaStartedByHost;
    if (this.progress != null) {
      json[r'progress'] = this.progress;
    } else {
      json[r'progress'] = null;
    }
    json[r'state'] = this.state;
    return json;
  }

  /// Returns a new [ModelOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static ModelOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'loaded'),
            'Required key "ModelOut[loaded]" is missing from JSON.');
        assert(json[r'loaded'] != null,
            'Required key "ModelOut[loaded]" has a null value in JSON.');
        assert(json.containsKey(r'name'),
            'Required key "ModelOut[name]" is missing from JSON.');
        assert(json[r'name'] != null,
            'Required key "ModelOut[name]" has a null value in JSON.');
        assert(json.containsKey(r'ollama_reachable'),
            'Required key "ModelOut[ollama_reachable]" is missing from JSON.');
        assert(json[r'ollama_reachable'] != null,
            'Required key "ModelOut[ollama_reachable]" has a null value in JSON.');
        assert(json.containsKey(r'ollama_started_by_host'),
            'Required key "ModelOut[ollama_started_by_host]" is missing from JSON.');
        assert(json[r'ollama_started_by_host'] != null,
            'Required key "ModelOut[ollama_started_by_host]" has a null value in JSON.');
        assert(json.containsKey(r'state'),
            'Required key "ModelOut[state]" is missing from JSON.');
        assert(json[r'state'] != null,
            'Required key "ModelOut[state]" has a null value in JSON.');
        return true;
      }());

      return ModelOut(
        error: mapValueOfType<String>(json, r'error'),
        loaded: mapValueOfType<bool>(json, r'loaded')!,
        name: mapValueOfType<String>(json, r'name')!,
        ollamaReachable: mapValueOfType<bool>(json, r'ollama_reachable')!,
        ollamaStartedByHost:
            mapValueOfType<bool>(json, r'ollama_started_by_host')!,
        progress: Progress.fromJson(json[r'progress']),
        state: ModelOutStateEnum.fromJson(json[r'state'])!,
      );
    }
    return null;
  }

  static List<ModelOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ModelOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ModelOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, ModelOut> mapFromJson(dynamic json) {
    final map = <String, ModelOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = ModelOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of ModelOut-objects as value to a dart map
  static Map<String, List<ModelOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<ModelOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = ModelOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'loaded',
    'name',
    'ollama_reachable',
    'ollama_started_by_host',
    'state',
  };
}

enum ModelOutStateEnum {
  starting._(r'starting'),
  ollamaStarting._(r'ollama_starting'),
  ollamaMissing._(r'ollama_missing'),
  pulling._(r'pulling'),
  loading._(r'loading'),
  ready._(r'ready'),
  error._(r'error'),
  disabled._(r'disabled'),
  ;

  /// Instantiate a new enum with the provided value.
  const ModelOutStateEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [ModelOutStateEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static ModelOutStateEnum? fromJson(dynamic value) =>
      ModelOutStateEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [ModelOutStateEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<ModelOutStateEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <ModelOutStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = ModelOutStateEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [ModelOutStateEnum] to String,
/// and [decode] dynamic data back to [ModelOutStateEnum].
class ModelOutStateEnumTypeTransformer {
  factory ModelOutStateEnumTypeTransformer() =>
      _instance ??= const ModelOutStateEnumTypeTransformer._();

  const ModelOutStateEnumTypeTransformer._();

  String encode(ModelOutStateEnum data) => data._value;

  /// Returns the instance of [ModelOutStateEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  ModelOutStateEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is ModelOutStateEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'starting':
          return ModelOutStateEnum.starting;
        case r'ollama_starting':
          return ModelOutStateEnum.ollamaStarting;
        case r'ollama_missing':
          return ModelOutStateEnum.ollamaMissing;
        case r'pulling':
          return ModelOutStateEnum.pulling;
        case r'loading':
          return ModelOutStateEnum.loading;
        case r'ready':
          return ModelOutStateEnum.ready;
        case r'error':
          return ModelOutStateEnum.error;
        case r'disabled':
          return ModelOutStateEnum.disabled;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static ModelOutStateEnumTypeTransformer? _instance;
}
