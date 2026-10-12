import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The two system settings the design system follows: reduced motion and reduced transparency.
///
/// Flutter reports reduced motion through MediaQuery but has no reduced-transparency flag, so on macOS both
/// are also read from the app's Runner over the `mydata/accessibility` channel (NSWorkspace). The web build
/// always uses solid bars (design/README.md, "Floating bars").
class MyDataAccessibility extends InheritedWidget {
  const MyDataAccessibility(
      {super.key, required this.reduceMotion, required this.reduceTransparency, required super.child});

  final bool reduceMotion;
  final bool reduceTransparency;

  /// The nearest settings; outside a [MyDataAccessibilityScope] only MediaQuery (and the web rule) count.
  static MyDataAccessibility of(BuildContext context) {
    final scoped = context.dependOnInheritedWidgetOfExactType<MyDataAccessibility>();
    if (scoped != null) return scoped;
    return MyDataAccessibility(
        reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
        reduceTransparency: kIsWeb,
        child: const SizedBox.shrink());
  }

  @override
  bool updateShouldNotify(MyDataAccessibility old) =>
      old.reduceMotion != reduceMotion || old.reduceTransparency != reduceTransparency;
}

/// Put once above each app (inside MaterialApp's builder): follows the system settings as they change.
class MyDataAccessibilityScope extends StatefulWidget {
  const MyDataAccessibilityScope({super.key, required this.child});
  final Widget child;

  static const channel = MethodChannel('mydata/accessibility');

  @override
  State<MyDataAccessibilityScope> createState() => _MyDataAccessibilityScopeState();
}

class _MyDataAccessibilityScopeState extends State<MyDataAccessibilityScope> {
  bool _systemReduceMotion = false;
  bool _systemReduceTransparency = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    MyDataAccessibilityScope.channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') _apply(call.arguments);
    });
    MyDataAccessibilityScope.channel
        .invokeMethod<Object?>('get')
        .then(_apply)
        // Platforms without the channel (tests, Windows and Linux so far) keep the MediaQuery value.
        .catchError((Object _) {}, test: (e) => e is MissingPluginException || e is PlatformException);
  }

  void _apply(Object? args) {
    if (!mounted || args is! Map) return;
    setState(() {
      _systemReduceMotion = args['reduceMotion'] == true;
      _systemReduceTransparency = args['reduceTransparency'] == true;
    });
  }

  @override
  void dispose() {
    if (!kIsWeb) MyDataAccessibilityScope.channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MyDataAccessibility(
        reduceMotion: _systemReduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false),
        reduceTransparency: kIsWeb || _systemReduceTransparency,
        child: widget.child,
      );
}
