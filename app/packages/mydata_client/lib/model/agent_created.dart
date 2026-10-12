//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class AgentCreated {
  /// Returns a new [AgentCreated] instance.
  AgentCreated({
    required this.connected,
    required this.createdAt,
    required this.id,
    this.lastSeenAt,
    required this.name,
    required this.revoked,
    this.revokedAt,
    required this.token,
  });

  bool connected;

  String createdAt;

  String id;

  String? lastSeenAt;

  String name;

  bool revoked;

  String? revokedAt;

  /// shown once; give it to the agent as its bearer token for /mcp
  String token;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentCreated &&
          other.connected == connected &&
          other.createdAt == createdAt &&
          other.id == id &&
          other.lastSeenAt == lastSeenAt &&
          other.name == name &&
          other.revoked == revoked &&
          other.revokedAt == revokedAt &&
          other.token == token;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (connected.hashCode) +
      (createdAt.hashCode) +
      (id.hashCode) +
      (lastSeenAt == null ? 0 : lastSeenAt!.hashCode) +
      (name.hashCode) +
      (revoked.hashCode) +
      (revokedAt == null ? 0 : revokedAt!.hashCode) +
      (token.hashCode);

  @override
  String toString() =>
      'AgentCreated[connected=$connected, createdAt=$createdAt, id=$id, lastSeenAt=$lastSeenAt, name=$name, revoked=$revoked, revokedAt=$revokedAt, token=$token]';

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
    json[r'token'] = this.token;
    return json;
  }

  /// Returns a new [AgentCreated] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static AgentCreated? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'connected'),
            'Required key "AgentCreated[connected]" is missing from JSON.');
        assert(json[r'connected'] != null,
            'Required key "AgentCreated[connected]" has a null value in JSON.');
        assert(json.containsKey(r'created_at'),
            'Required key "AgentCreated[created_at]" is missing from JSON.');
        assert(json[r'created_at'] != null,
            'Required key "AgentCreated[created_at]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "AgentCreated[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "AgentCreated[id]" has a null value in JSON.');
        assert(json.containsKey(r'name'),
            'Required key "AgentCreated[name]" is missing from JSON.');
        assert(json[r'name'] != null,
            'Required key "AgentCreated[name]" has a null value in JSON.');
        assert(json.containsKey(r'revoked'),
            'Required key "AgentCreated[revoked]" is missing from JSON.');
        assert(json[r'revoked'] != null,
            'Required key "AgentCreated[revoked]" has a null value in JSON.');
        assert(json.containsKey(r'token'),
            'Required key "AgentCreated[token]" is missing from JSON.');
        assert(json[r'token'] != null,
            'Required key "AgentCreated[token]" has a null value in JSON.');
        return true;
      }());

      return AgentCreated(
        connected: mapValueOfType<bool>(json, r'connected')!,
        createdAt: mapValueOfType<String>(json, r'created_at')!,
        id: mapValueOfType<String>(json, r'id')!,
        lastSeenAt: mapValueOfType<String>(json, r'last_seen_at'),
        name: mapValueOfType<String>(json, r'name')!,
        revoked: mapValueOfType<bool>(json, r'revoked')!,
        revokedAt: mapValueOfType<String>(json, r'revoked_at'),
        token: mapValueOfType<String>(json, r'token')!,
      );
    }
    return null;
  }

  static List<AgentCreated> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <AgentCreated>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = AgentCreated.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, AgentCreated> mapFromJson(dynamic json) {
    final map = <String, AgentCreated>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = AgentCreated.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of AgentCreated-objects as value to a dart map
  static Map<String, List<AgentCreated>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<AgentCreated>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = AgentCreated.listFromJson(
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
    'token',
  };
}
