//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class MemoryOut {
  /// Returns a new [MemoryOut] instance.
  MemoryOut({
    required this.hostBytes,
    this.modelBytes,
  });

  /// memory the host process uses
  int hostBytes;

  /// memory the loaded model uses in Ollama
  int? modelBytes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryOut &&
          other.hostBytes == hostBytes &&
          other.modelBytes == modelBytes;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (hostBytes.hashCode) + (modelBytes == null ? 0 : modelBytes!.hashCode);

  @override
  String toString() =>
      'MemoryOut[hostBytes=$hostBytes, modelBytes=$modelBytes]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'host_bytes'] = this.hostBytes;
    if (this.modelBytes != null) {
      json[r'model_bytes'] = this.modelBytes;
    } else {
      json[r'model_bytes'] = null;
    }
    return json;
  }

  /// Returns a new [MemoryOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static MemoryOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'host_bytes'),
            'Required key "MemoryOut[host_bytes]" is missing from JSON.');
        assert(json[r'host_bytes'] != null,
            'Required key "MemoryOut[host_bytes]" has a null value in JSON.');
        return true;
      }());

      return MemoryOut(
        hostBytes: mapValueOfType<int>(json, r'host_bytes')!,
        modelBytes: mapValueOfType<int>(json, r'model_bytes'),
      );
    }
    return null;
  }

  static List<MemoryOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <MemoryOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = MemoryOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, MemoryOut> mapFromJson(dynamic json) {
    final map = <String, MemoryOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = MemoryOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of MemoryOut-objects as value to a dart map
  static Map<String, List<MemoryOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<MemoryOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = MemoryOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'host_bytes',
  };
}
