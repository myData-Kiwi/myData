import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';

/// The system's colours for both appearances, as the Mac frame uses them.
@immutable
class MacSystemPalette {
  const MacSystemPalette({required this.light, required this.dark});

  /// The token defaults (macOS's own, with the blue accent).
  static const fallback = MacSystemPalette(light: MyDataMacColors.light, dark: MyDataMacColors.dark);

  final MyDataMacColors light;
  final MyDataMacColors dark;

  /// The palette in the channel's answer: `{"light": {"accent": 0xAARRGGBB, ...}, "dark": {...}}`, by token
  /// name ([MyDataMacColors.tokenNames]); anything missing or malformed keeps its default.
  static MacSystemPalette fromChannel(Object? args) {
    MyDataMacColors read(Object? values, MyDataMacColors base) {
      if (values is! Map) return base;
      return base.withSystem({
        for (final name in MyDataMacColors.tokenNames)
          if (values[name] case final int argb) name: Color(argb),
      });
    }

    if (args is! Map) return fallback;
    return MacSystemPalette(light: read(args['light'], fallback.light), dark: read(args['dark'], fallback.dark));
  }

  @override
  bool operator ==(Object other) => other is MacSystemPalette && other.light == light && other.dark == dark;

  @override
  int get hashCode => Object.hash(light, dark);
}

/// Reads the system's colours (the accent among them) from the app's Runner over the `mydata/system_colors`
/// channel (NSColor, resolved in the light and the dark appearance), and builds [builder] again when the
/// user changes them in System Settings. Put it above the MaterialApp: the theme is made from them.
///
/// Without the channel (tests, Windows, Linux, a Runner that does not answer) the palette stays
/// [MacSystemPalette.fallback].
class MacSystemColorsScope extends StatefulWidget {
  const MacSystemColorsScope({super.key, required this.builder, this.enabled = true});

  final Widget Function(BuildContext context, MacSystemPalette palette) builder;

  /// False: no channel calls, the fallback palette (the Mac frame is off).
  final bool enabled;

  static const channel = MethodChannel('mydata/system_colors');

  @override
  State<MacSystemColorsScope> createState() => _MacSystemColorsScopeState();
}

class _MacSystemColorsScopeState extends State<MacSystemColorsScope> {
  MacSystemPalette _palette = MacSystemPalette.fallback;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled || kIsWeb) return;
    MacSystemColorsScope.channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') _apply(call.arguments);
    });
    MacSystemColorsScope.channel
        .invokeMethod<Object?>('get')
        .then(_apply)
        .catchError((Object _) {}, test: (e) => e is MissingPluginException || e is PlatformException);
  }

  void _apply(Object? args) {
    if (!mounted) return;
    final palette = MacSystemPalette.fromChannel(args);
    if (palette != _palette) setState(() => _palette = palette);
  }

  @override
  void dispose() {
    if (widget.enabled && !kIsWeb) MacSystemColorsScope.channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _palette);
}
