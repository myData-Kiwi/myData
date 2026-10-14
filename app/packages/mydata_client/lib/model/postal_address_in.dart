//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.18

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class PostalAddressIn {
  /// Returns a new [PostalAddressIn] instance.
  PostalAddressIn({
    this.country,
    this.label,
    this.locality,
    this.postalCode,
    this.region,
    this.street,
  });

  String? country;

  String? label;

  /// the city or town
  String? locality;

  String? postalCode;

  String? region;

  /// may hold line breaks
  String? street;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostalAddressIn &&
          other.country == country &&
          other.label == label &&
          other.locality == locality &&
          other.postalCode == postalCode &&
          other.region == region &&
          other.street == street;

  @override
  int get hashCode =>
      // ignore: unnecessary_parenthesis
      (country == null ? 0 : country!.hashCode) +
      (label == null ? 0 : label!.hashCode) +
      (locality == null ? 0 : locality!.hashCode) +
      (postalCode == null ? 0 : postalCode!.hashCode) +
      (region == null ? 0 : region!.hashCode) +
      (street == null ? 0 : street!.hashCode);

  @override
  String toString() =>
      'PostalAddressIn[country=$country, label=$label, locality=$locality, postalCode=$postalCode, region=$region, street=$street]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (this.country != null) {
      json[r'country'] = this.country;
    } else {
      json[r'country'] = null;
    }
    if (this.label != null) {
      json[r'label'] = this.label;
    } else {
      json[r'label'] = null;
    }
    if (this.locality != null) {
      json[r'locality'] = this.locality;
    } else {
      json[r'locality'] = null;
    }
    if (this.postalCode != null) {
      json[r'postal_code'] = this.postalCode;
    } else {
      json[r'postal_code'] = null;
    }
    if (this.region != null) {
      json[r'region'] = this.region;
    } else {
      json[r'region'] = null;
    }
    if (this.street != null) {
      json[r'street'] = this.street;
    } else {
      json[r'street'] = null;
    }
    return json;
  }

  /// Returns a new [PostalAddressIn] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static PostalAddressIn? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        return true;
      }());

      return PostalAddressIn(
        country: mapValueOfType<String>(json, r'country'),
        label: mapValueOfType<String>(json, r'label'),
        locality: mapValueOfType<String>(json, r'locality'),
        postalCode: mapValueOfType<String>(json, r'postal_code'),
        region: mapValueOfType<String>(json, r'region'),
        street: mapValueOfType<String>(json, r'street'),
      );
    }
    return null;
  }

  static List<PostalAddressIn> listFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final result = <PostalAddressIn>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = PostalAddressIn.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, PostalAddressIn> mapFromJson(dynamic json) {
    final map = <String, PostalAddressIn>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = PostalAddressIn.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of PostalAddressIn-objects as value to a dart map
  static Map<String, List<PostalAddressIn>> mapListFromJson(
    dynamic json, {
    bool growable = false,
  }) {
    final map = <String, List<PostalAddressIn>>{};
    if (json is Map && json.isNotEmpty) {
      // ignore: parameter_assignments
      json = json.cast<String, dynamic>();
      for (final entry in json.entries) {
        map[entry.key] = PostalAddressIn.listFromJson(
          entry.value,
          growable: growable,
        );
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{};
}
