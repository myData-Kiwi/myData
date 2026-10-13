//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CalendarOut {
  /// Returns a new [CalendarOut] instance.
  CalendarOut({
    this.accountCaption,
    required this.accountId,
    this.color,
    required this.id,
    required this.name,
    required this.source_,
    required this.sourceLabel,
  });

  /// This Mac only: the account the calendar belongs to on the Mac, as macOS names it (\"iCloud\", \"Google\", \"Exchange\"), or \"Only on this Mac\", \"Birthdays from Contacts\", \"Subscribed\". None for an iCloud account's calendars, and when the Mac names no account
  String? accountCaption;

  String accountId;

  /// #RRGGBB as the source gives it (any alpha dropped); none when the calendar has no colour
  String? color;

  String id;

  String name;

  /// the source the calendar is read through
  CalendarOutSource_Enum source_;

  /// the source as the calendar list heads its group: \"This Mac\" or \"iCloud account <email>\"
  String sourceLabel;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarOut &&
          other.accountCaption == accountCaption &&
          other.accountId == accountId &&
          other.color == color &&
          other.id == id &&
          other.name == name &&
          other.source_ == source_ &&
          other.sourceLabel == sourceLabel;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (accountCaption == null ? 0 : accountCaption!.hashCode) +
      (accountId.hashCode) +
      (color == null ? 0 : color!.hashCode) +
      (id.hashCode) +
      (name.hashCode) +
      (source_.hashCode) +
      (sourceLabel.hashCode);

  @override
  String toString() =>
      'CalendarOut[accountCaption=$accountCaption, accountId=$accountId, color=$color, id=$id, name=$name, source_=$source_, sourceLabel=$sourceLabel]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.accountCaption != null) {
      json[r'account_caption'] = this.accountCaption;
    } else {
      json[r'account_caption'] = null;
    }
    json[r'account_id'] = this.accountId;
    if (this.color != null) {
      json[r'color'] = this.color;
    } else {
      json[r'color'] = null;
    }
    json[r'id'] = this.id;
    json[r'name'] = this.name;
    json[r'source'] = this.source_;
    json[r'source_label'] = this.sourceLabel;
    return json;
  }

  /// Returns a new [CalendarOut] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CalendarOut? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        assert(json.containsKey(r'account_id'),
            'Required key "CalendarOut[account_id]" is missing from JSON.');
        assert(json[r'account_id'] != null,
            'Required key "CalendarOut[account_id]" has a null value in JSON.');
        assert(json.containsKey(r'id'),
            'Required key "CalendarOut[id]" is missing from JSON.');
        assert(json[r'id'] != null,
            'Required key "CalendarOut[id]" has a null value in JSON.');
        assert(json.containsKey(r'name'),
            'Required key "CalendarOut[name]" is missing from JSON.');
        assert(json[r'name'] != null,
            'Required key "CalendarOut[name]" has a null value in JSON.');
        assert(json.containsKey(r'source'),
            'Required key "CalendarOut[source]" is missing from JSON.');
        assert(json[r'source'] != null,
            'Required key "CalendarOut[source]" has a null value in JSON.');
        assert(json.containsKey(r'source_label'),
            'Required key "CalendarOut[source_label]" is missing from JSON.');
        assert(json[r'source_label'] != null,
            'Required key "CalendarOut[source_label]" has a null value in JSON.');
        return true;
      }());

      return CalendarOut(
        accountCaption: mapValueOfType<String>(json, r'account_caption'),
        accountId: mapValueOfType<String>(json, r'account_id')!,
        color: mapValueOfType<String>(json, r'color'),
        id: mapValueOfType<String>(json, r'id')!,
        name: mapValueOfType<String>(json, r'name')!,
        source_: CalendarOutSource_Enum.fromJson(json[r'source'])!,
        sourceLabel: mapValueOfType<String>(json, r'source_label')!,
      );
    }
    return null;
  }

  static List<CalendarOut> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <CalendarOut>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CalendarOut.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CalendarOut> mapFromJson(dynamic json) {
    final map = <String, CalendarOut>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CalendarOut.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CalendarOut-objects as value to a dart map
  static Map<String, List<CalendarOut>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<CalendarOut>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = CalendarOut.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'account_id',
    'id',
    'name',
    'source',
    'source_label',
  };
}

/// the source the calendar is read through
enum CalendarOutSource_Enum {
  mac._(r'mac'),
  icloud._(r'icloud'),
  ;

  /// Instantiate a new enum with the provided value.
  const CalendarOutSource_Enum._(this._value);

  /// The underlying value of this enum member.
  final String _value;

  @override
  String toString() => _value;

  /// Encodes this enum as a value suitable for JSON.
  String toJson() => _value;

  /// Returns the instance of [CalendarOutSource_Enum] that was successfully decoded
  /// from the passed [value] on success, null otherwise.
  static CalendarOutSource_Enum? fromJson(dynamic value) =>
      CalendarOutSource_EnumTypeTransformer().decode(value);

  /// Returns a [List] containing instances of [CalendarOutSource_Enum]
  /// that were successfully decoded from the passed [JSON][json].
  static List<CalendarOutSource_Enum> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <CalendarOutSource_Enum>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CalendarOutSource_Enum.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }
}

/// Transformation class that can [encode] an instance of [CalendarOutSource_Enum] to String,
/// and [decode] dynamic data back to [CalendarOutSource_Enum].
class CalendarOutSource_EnumTypeTransformer {
  factory CalendarOutSource_EnumTypeTransformer() =>
      _instance ??= const CalendarOutSource_EnumTypeTransformer._();

  const CalendarOutSource_EnumTypeTransformer._();

  String encode(CalendarOutSource_Enum data) => data._value;

  /// Returns the instance of [CalendarOutSource_Enum] that was successfully decoded
  /// from the passed [data] value on success, null otherwise.
  ///
  /// If [allowNull] is true and the [dynamic value][data] cannot be decoded successfully,
  /// then null is returned. However, if [allowNull] is false and the [dynamic value][data]
  /// cannot be decoded successfully, then an [UnimplementedError] is thrown.
  ///
  /// The [allowNull] is very handy when an API changes and a new enum value is added or removed,
  /// and users are still using an old app with the old code.
  CalendarOutSource_Enum? decode(dynamic data, {bool allowNull = true}) {
    if (data is CalendarOutSource_Enum) {
      return data;
    }
    if (data != null) {
      switch (data) {
        case r'mac':
          return CalendarOutSource_Enum.mac;
        case r'icloud':
          return CalendarOutSource_Enum.icloud;
        default:
          if (!allowNull) {
            throw ArgumentError('Unknown enum value to decode: $data');
          }
      }
    }
    return null;
  }

  /// The singleton instance of this transformer.
  static CalendarOutSource_EnumTypeTransformer? _instance;
}
