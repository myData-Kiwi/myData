import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The two system settings the design system follows, reduced motion and reduced transparency, and whether
/// the last pointer was coarse (a finger on a touch screen), which raises every target to 44
/// (design/themes/ARCHITECTURE.md 1.4; `context.density`).
///
/// Flutter reports reduced motion through MediaQuery but has no reduced-transparency flag, so on macOS both
/// are also read from the app's Runner over the `mydata/accessibility` channel (NSWorkspace). The web build
/// always uses solid bars (design/README.md, "Floating bars").
class MyDataAccessibility extends InheritedWidget {
  const MyDataAccessibility({
    super.key,
    required this.reduceMotion,
    required this.reduceTransparency,
    this.coarsePointer = false,
    required super.child,
  });

  final bool reduceMotion;
  final bool reduceTransparency;

  /// The last press came from a finger (`PointerDeviceKind.touch`); a mouse, trackpad or pen makes it false
  /// again. Phones have their own floor already; this is for a touch screen on a desktop.
  final bool coarsePointer;

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
      old.reduceMotion != reduceMotion ||
      old.reduceTransparency != reduceTransparency ||
      old.coarsePointer != coarsePointer;
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
  bool _coarsePointer = false;

  /// Every press in the app: a finger makes targets coarse, anything else fine. Taken when the press ends,
  /// not when it starts, so the controls do not change size under the finger that is still on them (the
  /// tap itself was hit-tested on the way down and fires before the next layout).
  void _pointer(PointerEvent e) {
    if (e is! PointerUpEvent) return;
    final coarse = e.kind == PointerDeviceKind.touch;
    if (coarse != _coarsePointer && mounted) setState(() => _coarsePointer = coarse);
  }

  @override
  void initState() {
    super.initState();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_pointer);
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
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointer);
    if (!kIsWeb) MyDataAccessibilityScope.channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MyDataAccessibility(
        reduceMotion: _systemReduceMotion || (MediaQuery.maybeDisableAnimationsOf(context) ?? false),
        reduceTransparency: kIsWeb || _systemReduceTransparency,
        coarsePointer: _coarsePointer,
        child: widget.child,
      );
}
