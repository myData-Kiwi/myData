//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class SourceOut {
  /// Returns a new [SourceOut] instance.
  SourceOut({
    this.allCalendars,
    this.allContactContainers,
    this.available = true,
    this.backupsKeptUntil,
    this.calendars = const [],
    this.calendarsStatus,
    this.contactContainers = const [],
    this.contactsStatus,
    this.counts,
    this.decided,
    this.email,
    required this.enabled,
    required this.id,
    required this.kind,
    this.lastError,
    this.lastUpdate,
    required this.notesIncluded,
    this.readerRunning,
    this.state,
    this.window,
  });

  /// This Mac: as all_contact_containers, for calendars
  bool? allCalendars;

  /// This Mac: true when no choice was made (every account, including ones added later); send contact_containers null to keep it so
  bool? allContactContainers;

  bool available;

  /// YYYY-MM-DD: if it is turned off or removed now, copies of what it mirrored stay in the host's snapshots until this day, while the host keeps running (the turn-off and remove dialogs say so)
  String? backupsKeptUntil;

  List<MacCalendarOut> calendars;

  /// This Mac: notDetermined, restricted, denied, fullAccess, writeOnly, or unknown (as contacts_status)
  String? calendarsStatus;

  List<MacContainerOut> contactContainers;

  /// This Mac: notDetermined, restricted, denied, authorized, or unknown (not reported yet, or a value this host does not know: not readable)
  String? contactsStatus;

  /// what the source holds now: for an iCloud account, as of its last sync; for This Mac while it is on
  SyncCounts? counts;

  /// This Mac: true once the user turned it on or off (the myData app's first-run step is then not shown)
  bool? decided;

  /// iCloud: the account's email
  String? email;

  bool enabled;

  /// \"mac\" for This Mac; the account id for an iCloud account
  String id;

  SourceOutKindEnum kind;

  /// a short message for the user; never a secret
  String? lastError;

  String? lastUpdate;

  /// false for This Mac: contact notes are never read
  bool notesIncluded;

  /// This Mac: the reader helper is connected
  bool? readerRunning;

  SourceOutStateEnum? state;

  /// This Mac: the days of events it holds
  WindowOut? window;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SourceOut &&
          other.allCalendars == allCalendars &&
          other.allContactContainers == allContactContainers &&
          other.available == available &&
          other.backupsKeptUntil == backupsKeptUntil &&
          _deepEquality.equals(other.calendars, calendars) &&
          other.calendarsStatus == calendarsStatus &&
          _deepEquality.equals(other.contactContainers, contactContainers) &&
          other.contactsStatus == contactsStatus &&
          other.counts == counts &&
          other.decided == decided &&
          other.email == email &&
          other.enabled == enabled &&
          other.id == id &&
          other.kind == kind &&
          other.lastError == lastError &&
          other.lastUpdate == lastUpdate &&
          other.notesIncluded == notesIncluded &&
          other.readerRunning == readerRunning &&
          other.state == state &&
          other.window == window;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (allCalendars == null ? 0 : allCalendars!.hashCode) +
      (allContactContainers == null ? 0 : allContactContainers!.hashCode) +
      (available.hashCode) +
      (backupsKeptUntil == null ? 0 : backupsKeptUntil!.hashCode) +
      (calendars.hashCode) +
      (calendarsStatus == null ? 0 : calendarsStatus!.hashCode) +
      (contactContainers.hashCode) +
      (contactsStatus == null ? 0 : contactsStatus!.hashCode) +
      (counts == null ? 0 : counts!.hashCode) +
      (decided == null ? 0 : decided!.hashCode) +
      (email == null ? 0 : email!.hashCode) +
      (enabled.hashCode) +
      (id.hashCode) +
      (kind.hashCode) +
      (lastError == null ? 0 : lastError!.hashCode) +
      (lastUpdate == null ? 0 : lastUpdate!.hashCode) +
      (notesIncluded.hashCode) +
      (readerRunning == null ? 0 : readerRunning!.hashCode) +
      (state == null ? 0 : state!.hashCode) +
      (window == null ? 0 : window!.hashCode);

  @override
  String toString() =>
      'SourceOut[allCalendars=$allCalendars, allContactContainers=$allContactContainers, available=$available, backupsKeptUntil=$backupsKeptUntil, calendars=$calendars, calendarsStatus=$calendarsStatus, contactContainers=$contactContainers, contactsStatus=$contactsStatus, counts=$counts, decided=$decided, email=$email, enabled=$enabled, id=$id, kind=$kind, lastError=$lastError, lastUpdate=$lastUpdate, notesIncluded=$notesIncluded, readerRunning=$readerRunning, state=$state, window=$window]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.allCalendars != null) {
      json[r'all_calendars'] = this.allCalendars;
    } else {
      json[r'all_calendars'] = null;
    }
    if (this.allContactContainers != null) {
      json[r'all_contact_containers'] = this.allContactContainers;
    } else {
      json[r'all_contact_containers'] = null;
    }
    json[r'available'] = this.available;
    if (this.backupsKeptUntil != null) {
      json[r'backups_kept_until'] = this.backupsKeptUntil;
    } else {
      json[r'backups_kept_until'] = null;
    }
    json[r'calendars'] = this.calendars;
    if (this.calendarsStatus != null) {
      json[r'calendars_status'] = this.calendarsStatus;
    } else {
      json[r'calendars_status'] = null;
    }
    json[r'contact_containers'] = this.contactContainers;
    if (this.contactsStatus != null) {
      json[r'contacts_status'] = this.contactsStatus;
    } else {
      json[r'contacts_status'] = null;
    }
    if (this.counts != null) {
      json[r'counts'] = this.counts;
    } else {
      json[r'counts'] = null;
    }
    if (this.decided != null) {
      json[r'decided'] = this.decided;
    } else {
      json[r'decided'] = null;
    }
    if (this.email != null) {
      json[r'email'] = this.email;
    } else {
      json[r'email'] = null;
    }
    json[r'enabled'] = this.enabled;
    json[r'id'] = this.id;
    json[r'kind'] = this.kind;
    if (this.lastError != null) {
      json[r'last_error'] = this.lastError;
    } else {
      json[r'last_error'] = null;
    }
    if (this.lastUpdate != null) {
      json[r'last_update'] = this.lastUpdate;
    } else {
      json[r'last_update'] = null;
    }
    json[r'notes_included'] = this.notesIncluded;
    if (this.readerRunning != null) {
      json[r'reader_running'] = this.readerRunning;
    } else {
      json[r'reader_running'] = null;
    }
    if (this.state != null) {
      json[r'state'] = this.state;
    } else {
      json[r'state'] = null;
    }
    if (this.window != null) {
      json[r'window'] = this.window;
    } else {
      json[r'window'] = null;
    }
    return json;
  }

  /// Returns a new [SourceOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static SourceOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'enabled'),
            'Required key "SourceOut[enabled]" is missing from JSON.');
        assert(json[r'enabled'] != null,
            'Required key "SourceOut[enabled]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "SourceOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "SourceOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'kind'),
            'Required key "SourceOut[kind]" is missing from JSON.');
        assert(json[r'kind'] != null,
            'Required key "SourceOut[kind]" has a null value in JSON.');
        assert(json.containsKey(r'notes_included'),
            'Required key "SourceOut[notes_included]" is missing from JSON.');
        assert(json[r'notes_included'] != null,
            'Required key "SourceOut[notes_included]" has a null value in JSON.');
        return true;
      }());

      return SourceOut(
        allCalendars: mapValueOfType<bool>(json, r'all_calendars'),
        allContactContainers:
            mapValueOfType<bool>(json, r'all_contact_containers'),
        available: mapValueOfType<bool>(json, r'available') ?? true,
        backupsKeptUntil: mapValueOfType<String>(json, r'backups_kept_until'),
        calendars: MacCalendarOut.listFromJson(json[r'calendars']),
        calendarsStatus: mapValueOfType<String>(json, r'calendars_status'),
        contactContainers:
            MacContainerOut.listFromJson(json[r'contact_containers']),
        contactsStatus: mapValueOfType<String>(json, r'contacts_status'),
        counts: SyncCounts.fromJson(json[r'counts']),
        decided: mapValueOfType<bool>(json, r'decided'),
        email: mapValueOfType<String>(json, r'email'),
        enabled: mapValueOfType<bool>(json, r'enabled')!,
        id: mapValueOfType<String>(json, r'id')!,
        kind: SourceOutKindEnum.fromJson(json[r'kind'])!,
        lastError: mapValueOfType<String>(json, r'last_error'),
        lastUpdate: mapValueOfType<String>(json, r'last_update'),
        notesIncluded: mapValueOfType<bool>(json, r'notes_included')!,
        readerRunning: mapValueOfType<bool>(json, r'reader_running'),
        state: SourceOutStateEnum.fromJson(json[r'state']),
        window: WindowOut.fromJson(json[r'window']),
      );
    }
    return null;
  }

  static List<SourceOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <SourceOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SourceOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, SourceOut> mapFromJson(dynamic json) {
    final map = <String, SourceOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = SourceOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of SourceOut-objects as value to a dart map
  static Map<String, List<SourceOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<SourceOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = SourceOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'enabled',
    'id',
    'kind',
    'notes_included',
  };
}

enum SourceOutKindEnum {
  mac._(r'mac'),
  icloud._(r'icloud'),
  ;

  /// Instantiate a new enum with the provided value.
  const SourceOutKindEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [SourceOutKindEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static SourceOutKindEnum? fromJson(dynamic value) =>
      SourceOutKindEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [SourceOutKindEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<SourceOutKindEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <SourceOutKindEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SourceOutKindEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SourceOutKindEnum] to String,
/// and [decode] dynamic data back to [SourceOutKindEnum].
class SourceOutKindEnumTypeTransformer {
  factory SourceOutKindEnumTypeTransformer() =>
      _instance ??= const SourceOutKindEnumTypeTransformer._();

  const SourceOutKindEnumTypeTransformer._();

  String encode(SourceOutKindEnum data) => data._value;

  /// Returns the instance of [SourceOutKindEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SourceOutKindEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is SourceOutKindEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'mac':
          return SourceOutKindEnum.mac;
        case r'icloud':
          return SourceOutKindEnum.icloud;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static SourceOutKindEnumTypeTransformer? _instance;
}

enum SourceOutStateEnum {
  idle._(r'idle'),
  syncing._(r'syncing'),
  error._(r'error'),
  ;

  /// Instantiate a new enum with the provided value.
  const SourceOutStateEnum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [SourceOutStateEnum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static SourceOutStateEnum? fromJson(dynamic value) =>
      SourceOutStateEnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [SourceOutStateEnum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<SourceOutStateEnum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <SourceOutStateEnum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = SourceOutStateEnum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [SourceOutStateEnum] to String,
/// and [decode] dynamic data back to [SourceOutStateEnum].
class SourceOutStateEnumTypeTransformer {
  factory SourceOutStateEnumTypeTransformer() =>
      _instance ??= const SourceOutStateEnumTypeTransformer._();

  const SourceOutStateEnumTypeTransformer._();

  String encode(SourceOutStateEnum data) => data._value;

  /// Returns the instance of [SourceOutStateEnum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  SourceOutStateEnum? decode(dynamic data, {bool allowNull = true}) {
    if (data is SourceOutStateEnum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'idle':
          return SourceOutStateEnum.idle;
        case r'syncing':
          return SourceOutStateEnum.syncing;
        case r'error':
          return SourceOutStateEnum.error;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static SourceOutStateEnumTypeTransformer? _instance;
}
