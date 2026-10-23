/// The part of JSON Schema 2020-12 that design/themes/theme.schema.json uses, so the schema file itself is the
/// format's one definition (ARCHITECTURE.md 2.1, step 4). Supported: `type`, `enum`, `const`, `pattern`,
/// `minimum`, `maximum`, `multipleOf`, `minLength`, `maxLength`, `minItems`, `maxItems`, `required`,
/// `properties`, `additionalProperties`, `propertyNames`, `items`, local `$ref`, `allOf`, `anyOf`, `oneOf`,
/// `not`, `if`/`then`/`else` and `dependentRequired`. Any other keyword in the schema is an error, so the schema
/// cannot grow a rule this reader would skip (`test/theme_format_test.dart`).
///
/// One departure, from ARCHITECTURE.md 2.1: a key the schema does not allow (`additionalProperties: false`)
/// is dropped from the file with a notice instead of refusing it, so a newer minor version still loads.
library;

/// One finding of the schema check.
class SchemaIssue {
  const SchemaIssue(this.path, this.message, {this.notice = false});

  /// Where in the file, as `palettes/0/light/bg` (empty for the whole file).
  final String path;
  final String message;

  /// A dropped unknown key: reported, never blocking.
  final bool notice;

  @override
  String toString() => path.isEmpty ? message : '$path: $message';
}

/// Keywords that only describe; they never fail a value.
const _annotations = {r'$schema', r'$id', r'$comment', 'title', 'description', r'$defs', 'default', 'examples'};

/// Keywords the checker applies.
const supportedKeywords = {
  'type', 'enum', 'const', 'pattern', 'minimum', 'maximum', 'multipleOf', 'minLength', 'maxLength', 'minItems',
  'maxItems', 'required', 'properties', 'additionalProperties', 'propertyNames', 'items', r'$ref', 'allOf',
  'anyOf', 'oneOf', 'not', 'if', 'then', 'else', 'dependentRequired',
};

/// Friendly descriptions for values that fail a `$ref`'d pattern.
const _refWords = {
  'opaque': 'an opaque colour written #RRGGBB',
  'translucent': 'a colour written #RRGGBB or #RRGGBBAA',
  'paletteId': 'a palette id in lower case with hyphens (ink-blue)',
};

/// Checks [value] against [schema]; returns every issue. Unknown keys under `additionalProperties: false` are
/// removed from [value] (which must then be mutable, as `readStrictJson` returns it) and reported as notices.
List<SchemaIssue> checkSchema(Object? value, Map<String, Object?> schema) {
  final c = _Checker(schema);
  c.check(value, schema, '', collect: true);
  return c.issues;
}

/// The keywords in [schema] (recursively) that [checkSchema] does not apply, for the format test.
Set<String> unsupportedKeywords(Map<String, Object?> schema) {
  final out = <String>{};
  void walk(Object? node, {bool isPropertyMap = false}) {
    if (node is Map<String, Object?>) {
      for (final e in node.entries) {
        if (isPropertyMap) {
          walk(e.value);
          continue;
        }
        if (!_annotations.contains(e.key) && !supportedKeywords.contains(e.key)) out.add(e.key);
        if (e.key == 'properties' || e.key == r'$defs') {
          walk(e.value, isPropertyMap: true);
        } else if (!const {'enum', 'const', 'required', 'dependentRequired'}.contains(e.key)) {
          walk(e.value);
        }
      }
    } else if (node is List) {
      for (final x in node) {
        walk(x);
      }
    }
  }

  walk(schema);
  return out;
}

class _Checker {
  _Checker(this.root);
  final Map<String, Object?> root;
  final issues = <SchemaIssue>[];

  Map<String, Object?> _resolve(String ref) {
    if (!ref.startsWith('#/')) throw ArgumentError('only local \$refs are supported: $ref');
    Object? node = root;
    for (final part in ref.substring(2).split('/')) {
      node = (node as Map<String, Object?>)[part.replaceAll('~1', '/').replaceAll('~0', '~')];
    }
    return node as Map<String, Object?>;
  }

  /// Whether [value] passes [schema], without recording anything or dropping keys.
  bool passes(Object? value, Map<String, Object?> schema) {
    final probe = _Checker(root);
    probe.check(value, schema, '', collect: false);
    return probe.issues.where((i) => !i.notice).isEmpty;
  }

  void fail(String path, String message) => issues.add(SchemaIssue(path, message));

  static String _join(String path, Object key) => path.isEmpty ? '$key' : '$path/$key';

  static String _show(Object? v) {
    if (v is String) return '"${v.length > 40 ? '${v.substring(0, 40)}…' : v}"';
    if (v is Map) return 'an object';
    if (v is List) return 'a list';
    return '$v';
  }

  static bool _isType(Object? v, String type) => switch (type) {
        'string' => v is String,
        'number' => v is num,
        'integer' => v is int || (v is double && v == v.roundToDouble()),
        'boolean' => v is bool,
        'object' => v is Map,
        'array' => v is List,
        'null' => v == null,
        _ => throw ArgumentError('unknown type $type'),
      };

  void check(Object? value, Map<String, Object?> schema, String path, {required bool collect, String? refName}) {
    if (schema[r'$ref'] case final String ref) {
      final name = ref.split('/').last;
      check(value, _resolve(ref), path, collect: collect, refName: name);
    }

    if (schema['type'] case final Object type) {
      final types = type is List ? type.cast<String>() : [type as String];
      if (!types.any((t) => _isType(value, t))) {
        fail(path, 'must be ${_refWords[refName] ?? types.map(_article).join(' or ')}, not ${_show(value)}');
        return;
      }
    }
    if (schema.containsKey('const') && !_equal(schema['const'], value)) {
      fail(path, 'must be ${_show(schema['const'])}, not ${_show(value)}');
    }
    if (schema['enum'] case final List options) {
      if (!options.any((o) => _equal(o, value))) {
        fail(path, '${_show(value)} is not one of ${options.map(_show).join(', ')}');
      }
    }

    if (value is String) {
      final len = value.runes.length;
      if (schema['minLength'] case final num min when len < min) fail(path, 'must be at least $min characters long');
      if (schema['maxLength'] case final num max when len > max) fail(path, 'must be at most $max characters long');
      if (schema['pattern'] case final String p when !RegExp(p).hasMatch(value)) {
        fail(path, '${_show(value)} is not ${_refWords[refName] ?? 'in the expected form'}');
      }
    }
    if (value is num) {
      if (schema['minimum'] case final num min when value < min) fail(path, '$value is below the least allowed, $min');
      if (schema['maximum'] case final num max when value > max) fail(path, '$value is above the most allowed, $max');
      if (schema['multipleOf'] case final num m) {
        final q = value / m;
        if ((q - q.roundToDouble()).abs() > 1e-9) fail(path, '$value is not a multiple of $m');
      }
    }
    if (value is List) {
      if (schema['minItems'] case final num min when value.length < min) fail(path, 'must list at least $min');
      if (schema['maxItems'] case final num max when value.length > max) fail(path, 'must list at most $max');
      if (schema['items'] case final Map<String, Object?> items) {
        for (var i = 0; i < value.length; i++) {
          check(value[i], items, _join(path, i), collect: collect);
        }
      }
    }
    if (value is Map<String, Object?>) _object(value, schema, path, collect: collect);

    if (schema['allOf'] case final List all) {
      for (final s in all.cast<Map<String, Object?>>()) {
        check(value, s, path, collect: collect);
      }
    }
    if (schema['anyOf'] case final List any) {
      if (!any.cast<Map<String, Object?>>().any((s) => passes(value, s))) fail(path, 'matches none of the allowed forms');
    }
    if (schema['oneOf'] case final List one) {
      final n = one.cast<Map<String, Object?>>().where((s) => passes(value, s)).length;
      if (n != 1) fail(path, n == 0 ? '${_show(value)} is not in an allowed form' : 'matches more than one form');
    }
    if (schema['not'] case final Map<String, Object?> not) {
      if (passes(value, not)) fail(path, _notMessage(not));
    }
    if (schema['if'] case final Map<String, Object?> cond) {
      final branch = passes(value, cond) ? schema['then'] : schema['else'];
      if (branch is Map<String, Object?>) check(value, branch, path, collect: collect);
    }
  }

  void _object(Map<String, Object?> value, Map<String, Object?> schema, String path, {required bool collect}) {
    if (schema['required'] case final List req) {
      for (final k in req.cast<String>()) {
        if (!value.containsKey(k)) fail(path, 'needs "$k"');
      }
    }
    if (schema['dependentRequired'] case final Map<String, Object?> dep) {
      for (final e in dep.entries) {
        if (!value.containsKey(e.key)) continue;
        for (final k in (e.value as List).cast<String>()) {
          if (!value.containsKey(k)) fail(path, '"${e.key}" needs "$k" beside it');
        }
      }
    }
    final props = (schema['properties'] as Map<String, Object?>?) ?? const {};
    final names = schema['propertyNames'] as Map<String, Object?>?;
    final additional = schema['additionalProperties'];
    for (final key in value.keys.toList()) {
      final p = _join(path, key);
      if (names != null && !passes(key, names)) {
        fail(p, '"$key" is not allowed here');
        continue;
      }
      if (props[key] case final Map<String, Object?> s) {
        check(value[key], s, p, collect: collect);
      } else if (additional == false) {
        if (collect) {
          value.remove(key);
          issues.add(SchemaIssue(p, '"$key" is not part of the theme format and was left out', notice: true));
        } else {
          fail(p, 'unknown key');
        }
      } else if (additional is Map<String, Object?>) {
        check(value[key], additional, p, collect: collect);
      }
    }
  }

  static String _notMessage(Map<String, Object?> not) {
    final any = not['anyOf'];
    if (any is List) {
      final keys = [
        for (final s in any)
          if (s is Map && s['required'] is List) ...(s['required'] as List).cast<String>(),
      ];
      if (keys.isNotEmpty) return 'may not give ${keys.map((k) => '"$k"').join(', ')}';
    }
    return 'is in a form that is not allowed';
  }

  static String _article(String type) => switch (type) {
        'object' => 'an object',
        'array' => 'a list',
        'integer' => 'a whole number',
        'boolean' => 'true or false',
        _ => 'a $type',
      };

  static bool _equal(Object? a, Object? b) {
    if (a is num && b is num) return a == b;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_equal(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      return a.keys.every((k) => b.containsKey(k) && _equal(a[k], b[k]));
    }
    return a == b;
  }
}
