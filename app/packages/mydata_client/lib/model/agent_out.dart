//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AgentOut {
  /// Returns a new [AgentOut] instance.
  AgentOut({
    required this.connected,
    required this.createdAt,
    required this.id,
    this.lastSeenAt,
    required this.name,
    required this.revoked,
    this.revokedAt,
  });

  bool connected;

  String createdAt;

  String id;

  String? lastSeenAt;

  String name;

  bool revoked;

  String? revokedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentOut &&
          other.connected == connected &&
          other.createdAt == createdAt &&
          other.id == id &&
          other.lastSeenAt == lastSeenAt &&
          other.name == name &&
          other.revoked == revoked &&
          other.revokedAt == revokedAt;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (connected.hashCode) +
      (createdAt.hashCode) +
      (id.hashCode) +
      (lastSeenAt == null ? 0 : lastSeenAt!.hashCode) +
      (name.hashCode) +
      (revoked.hashCode) +
      (revokedAt == null ? 0 : revokedAt!.hashCode);

  @override
  String toString() =>
      'AgentOut[connected=$connected, createdAt=$createdAt, id=$id, lastSeenAt=$lastSeenAt, name=$name, revoked=$revoked, revokedAt=$revokedAt]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json[r'connected'] = this.connected;
    json[r'created_at'] = this.createdAt;
    json[r'id'] = this.id;
    if (this.lastSeenAt != null) {
      json[r'last_seen_at'] = this.lastSeenAt;
    } else {
      json[r'last_seen_at'] = null;
    }
    json[r'name'] = this.name;
    json[r'revoked'] = this.revoked;
    if (this.revokedAt != null) {
      json[r'revoked_at'] = this.revokedAt;
    } else {
      json[r'revoked_at'] = null;
    }
    return json;
  }

  /// Returns a new [AgentOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AgentOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'connected'),
            'Required key "AgentOut[connected]" is missing from JSON.');
        assert(json[r'connected'] != null,
            'Required key "AgentOut[connected]" has a null value in JSON.');
        assert(json.containsKey(r'created_at'),
            'Required key "AgentOut[created_at]" is missing from JSON.');
        assert(json[r'created_at'] != null,
            'Required key "AgentOut[created_at]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "AgentOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "AgentOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'name'),
            'Required key "AgentOut[name]" is missing from JSON.');
        assert(json[r'name'] != null,
            'Required key "AgentOut[name]" has a null value in JSON.');
        assert(json.containsKey(r'revoked'),
            'Required key "AgentOut[revoked]" is missing from JSON.');
        assert(json[r'revoked'] != null,
            'Required key "AgentOut[revoked]" has a null value in JSON.');
        return true;
      }());

      return AgentOut(
        connected: mapValueOfType<bool>(json, r'connected')!,
        createdAt: mapValueOfType<String>(json, r'created_at')!,
        id: mapValueOfType<String>(json, r'id')!,
        lastSeenAt: mapValueOfType<String>(json, r'last_seen_at'),
        name: mapValueOfType<String>(json, r'name')!,
        revoked: mapValueOfType<bool>(json, r'revoked')!,
        revokedAt: mapValueOfType<String>(json, r'revoked_at'),
      );
    }
    return null;
  }

  static List<AgentOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AgentOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AgentOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AgentOut> mapFromJson(dynamic json) {
    final map = <String, AgentOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AgentOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AgentOut-objects as value to a dart map
  static Map<String, List<AgentOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AgentOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AgentOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'connected',
    'created_at',
    'id',
    'name',
    'revoked',
  };
}
