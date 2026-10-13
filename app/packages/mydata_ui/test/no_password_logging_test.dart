// No app or package prints or logs an account password. The generated AccountIn's toString() includes the
// password, so an AccountIn may never be interpolated, turned into a string or handed to a logging call; and
// nothing named *password* may be handed to one either. This test scans the source of every app and package
// (lib/ only; mydata_client is generated from the host API and is left out) and fails `flutter test` when it
// finds one. apps/mydata/test/password_not_printed_test.dart checks the same at run time.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every app's and package's lib/, found from the workspace, so a new app or package is scanned too.
Iterable<Directory> libraries() sync* {
  for (final parent in ['../../apps', '..']) {
    final dir = Directory(parent);
    if (!dir.existsSync()) continue;
    for (final d in dir.listSync().whereType<Directory>()) {
      if (d.path.endsWith('/mydata_client')) continue;
      final lib = Directory('${d.path}/lib');
      if (lib.existsSync()) yield lib;
    }
  }
}

Iterable<File> sources() sync* {
  for (final lib in libraries()) {
    yield* lib.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));
  }
}

/// Dart source with its comments blanked and the literal text of its strings blanked, keeping the quotes and
/// every interpolation (`$name`, `${expression}`) as code. Same length and line breaks as the source, so
/// offsets and line numbers carry over.
class CodeOnly {
  CodeOnly(this.s);
  final String s;
  final _out = StringBuffer();

  static bool _identStart(String c) => RegExp(r'[A-Za-z_]').hasMatch(c);
  static bool _ident(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

  String run() {
    _code(0, nested: false);
    return _out.toString();
  }

  void _blank(int from, int to) {
    for (var j = from; j < to; j++) {
      _out.write(s[j] == '\n' ? '\n' : ' ');
    }
  }

  /// Code from [i]; inside an interpolation ([nested]) it stops at the `}` that closes it.
  int _code(int i, {required bool nested}) {
    var depth = 0;
    while (i < s.length) {
      final c = s[i];
      if (s.startsWith('//', i)) {
        final end = s.indexOf('\n', i);
        final e = end < 0 ? s.length : end;
        _blank(i, e);
        i = e;
      } else if (s.startsWith('/*', i)) {
        var d = 0;
        var j = i;
        while (j < s.length) {
          if (s.startsWith('/*', j)) {
            d++;
            j += 2;
          } else if (s.startsWith('*/', j)) {
            d--;
            j += 2;
            if (d == 0) break;
          } else {
            j++;
          }
        }
        _blank(i, j);
        i = j;
      } else if (c == '"' || c == "'") {
        i = _string(i, raw: false);
      } else if ((c == 'r' || c == 'R') &&
          i + 1 < s.length &&
          (s[i + 1] == '"' || s[i + 1] == "'") &&
          (i == 0 || !_ident(s[i - 1]))) {
        _out.write(c);
        i = _string(i + 1, raw: true);
      } else {
        if (nested && c == '{') depth++;
        if (nested && c == '}') {
          if (depth == 0) return i;
          depth--;
        }
        _out.write(c);
        i++;
      }
    }
    return i;
  }

  int _string(int i, {required bool raw}) {
    final triple = s.startsWith("'''", i) || s.startsWith('"""', i);
    final quote = triple ? s.substring(i, i + 3) : s[i];
    _out.write(quote);
    i += quote.length;
    while (i < s.length) {
      if (s.startsWith(quote, i)) {
        _out.write(quote);
        return i + quote.length;
      }
      final c = s[i];
      if (!triple && c == '\n') return i; // unterminated: carry on as code
      if (!raw && c == r'\' && i + 1 < s.length) {
        _blank(i, i + 2);
        i += 2;
      } else if (!raw && c == r'$' && i + 1 < s.length && s[i + 1] == '{') {
        _out.write(r'${');
        i = _code(i + 2, nested: true);
        if (i < s.length) {
          _out.write('}');
          i++;
        }
      } else if (!raw && c == r'$' && i + 1 < s.length && _identStart(s[i + 1])) {
        _out.write(c);
        i++;
        while (i < s.length && _ident(s[i]) && s[i] != r'$') {
          _out.write(s[i]);
          i++;
        }
      } else {
        _blank(i, i + 1);
        i++;
      }
    }
    return i;
  }
}

/// The index after the bracket that closes the one at [open] (`(`, `[` or `{`), in code-only text.
int closing(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(' || c == '[' || c == '{') depth++;
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return code.length;
}

/// A call that prints or logs: print, debugPrint, log and developer.log, a Logger's methods, stdout and stderr.
final loggingCall = RegExp(
  r'(?:\b(?:print|debugPrint|debugPrintSynchronously|debugPrintThrottled|log)\s*\('
  r'|\b\w*(?:logger|Logger|LOGGER|log)\s*\.\s*'
  r'(?:finest|finer|fine|config|info|warning|severe|shout|log|d|i|w|e|v|t|f|wtf|debug|error|warn|trace|fatal)\s*\('
  r'|\bLogger\s*\([^()]*\)\s*\.\s*\w+\s*\('
  r'|\b(?:stdout|stderr)\s*\.\s*(?:write|writeln|writeAll)\s*\()',
);

final passwordName = RegExp(r'\b\w*password\w*\b', caseSensitive: false);
final accountInUse = RegExp(r'\bAccountIn\b(?!ProviderEnum)');
final accountInConstruction = RegExp(r'\bAccountIn(?:\.fromJson)?\s*\(');

/// Names that hold an AccountIn in [code]: declared with the type, or assigned a new one.
Set<String> accountNames(String code) => {
  for (final m in RegExp(r'\bAccountIn\??\s+(?:get\s+)?([A-Za-z_]\w*)').allMatches(code)) m.group(1)!,
  for (final m in RegExp(r'\b([A-Za-z_]\w*)\s*=\s*AccountIn(?:\.fromJson)?\s*\(').allMatches(code)) m.group(1)!,
};

/// Each place in [source] that could print an account password: (offset, rule).
List<(int, String)> findings(String source) {
  final code = CodeOnly(source).run();
  final names = accountNames(code);
  final out = <(int, String)>[];

  for (final m in loggingCall.allMatches(code)) {
    final args = code.substring(m.end - 1, closing(code, m.end - 1));
    if (passwordName.hasMatch(args)) out.add((m.start, 'a password passed to a logging call'));
    // The whole object (or its JSON); one of its other fields (account.email) is fine.
    final whole = names.any(
      (n) => RegExp('\\b${RegExp.escape(n)}\\b(?!\\s*[?!]?\\s*\\??\\.\\s*(?!toString\\b|toJson\\b)\\w)').hasMatch(args),
    );
    if (accountInUse.hasMatch(args) || whole) {
      out.add((m.start, 'an AccountIn passed to a logging call'));
    }
  }
  for (final n in names) {
    final name = RegExp.escape(n);
    for (final m in RegExp('\\\$$name\\b(?!\\\$)|\\\$\\{\\s*(?:[\\w.?!]*\\.)?$name\\s*!?\\s*\\}').allMatches(code)) {
      out.add((m.start, 'an AccountIn interpolated into a string'));
    }
    for (final m in RegExp('\\b$name\\s*[?!]?\\s*\\??\\.\\s*toString\\s*\\(').allMatches(code)) {
      out.add((m.start, 'toString() called on an AccountIn'));
    }
  }
  for (final m in accountInConstruction.allMatches(code)) {
    final end = closing(code, m.end - 1);
    if (RegExp(r'^\s*!?\s*\??\.\s*toString\s*\(').hasMatch(code.substring(end))) {
      out.add((m.start, 'toString() called on an AccountIn'));
    }
  }
  for (final m in RegExp(r'\$\{').allMatches(code)) {
    if (accountInConstruction.hasMatch(code.substring(m.end, closing(code, m.end - 1)))) {
      out.add((m.start, 'an AccountIn interpolated into a string'));
    }
  }
  return out;
}

int lineOf(String source, int offset) => '\n'.allMatches(source.substring(0, offset)).length + 1;

void main() {
  test('no app or package prints or logs an account password', () {
    final found = <String>[];
    var scanned = 0;
    for (final f in sources()) {
      scanned++;
      final source = f.readAsStringSync();
      final lines = source.split('\n');
      for (final (offset, rule) in findings(source)) {
        final n = lineOf(source, offset);
        found.add('${f.path}:$n: $rule: ${lines[n - 1].trim()}');
      }
    }
    expect(scanned, greaterThan(20), reason: 'the scan found too few files; are the roots right?');
    expect(
      libraries().map((d) => d.path),
      containsAll(['../../apps/mydata/lib', '../../apps/myassistant/lib', '../mydata_core/lib', '../mydata_ui/lib']),
    );
    expect(libraries().map((d) => d.path), isNot(contains('../mydata_client/lib')));
    expect(found, isEmpty, reason: 'An account password must never be printed or logged:\n${found.join('\n')}');
  });

  test('the scan finds the ways a password could be printed', () {
    List<String> rules(String snippet) => [for (final (_, r) in findings(snippet)) r];
    const passed = 'a password passed to a logging call';
    const accountLogged = 'an AccountIn passed to a logging call';
    const interpolated = 'an AccountIn interpolated into a string';
    const stringified = 'toString() called on an AccountIn';

    // A field or variable named *password* handed to a logging call.
    expect(rules('debugPrint(_password.text);'), [passed]);
    expect(rules(r"print('sent ${_password.text}');"), [passed]);
    expect(rules(r"debugPrint('sent $password');"), [passed]);
    expect(rules('log(appPassword);'), [passed]);
    expect(rules("developer.log('signing in', error: userPassword);"), [passed]);
    expect(rules("_logger.info('x' + form.password);"), [passed]);
    expect(rules("Logger('accounts').warning(password);"), [passed]);
    expect(rules('stderr.writeln(password);'), [passed]);
    // The word in a message is not the value.
    expect(rules("debugPrint('the password was not accepted');"), isEmpty);
    expect(rules("print('''password'''); // print(password)"), isEmpty);

    // An AccountIn: interpolated, turned into a string, or logged.
    const made = 'final account = AccountIn(provider: p, email: e, password: _password.text);\n';
    expect(rules("$made debugPrint('adding \$account');"), [accountLogged, interpolated]);
    expect(rules("${made}error = 'could not add \${account}';"), [interpolated]);
    expect(rules('${made}final s = account.toString();'), [stringified]);
    expect(rules('${made}log(account.toJson());'), [accountLogged]);
    expect(rules('void add(AccountIn body) { throw StateError("bad \$body"); }'), [interpolated]);
    expect(rules('final s = AccountIn(provider: p, email: e, password: x).toString();'), [stringified]);
    expect(rules(r"final s = '${AccountIn(provider: p, email: e, password: x)}';"), [interpolated]);
    expect(rules("print(AccountIn(provider: p, email: e, password: x));"), [passed, accountLogged]);
    // Sending it, or showing other fields, is fine.
    expect(rules('${made}await api.addAccount(account);'), isEmpty);
    expect(rules("${made}debugPrint('adding \${account.email}');"), isEmpty);
    expect(rules('${made}Text(account.email);'), isEmpty);
  });
}
