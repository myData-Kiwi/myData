import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import '../motion.dart';
import '../theme.dart';
import 'app_menu_bar.dart';
import 'button.dart';
import 'dialog.dart';
import 'floating_bar.dart';
import 'pressable.dart';

/// What Undo brought back, as the toast that replaces the one with Undo says it: "Contact restored",
/// "Changes undone", or "Not undone. Ava Fictional was changed after that.". [focus] is where focus goes
/// when the element that had it before the toast is gone: the restored record's row.
@immutable
class UndoResult {
  const UndoResult(this.message, {this.focus});
  final String message;
  final FocusNode? focus;
}

/// Undoes the change a toast names, and says what came back.
typedef ToastUndo = Future<UndoResult> Function();

/// One toast: its [message] and, when the change can be undone, its [undo].
@immutable
class ToastMessage {
  const ToastMessage(this.message, {this.undo});

  /// What happened, in the past tense, in sentence case with no full stop: "Contact deleted".
  final String message;
  final ToastUndo? undo;
}

/// Shows and replaces the toast of a [ToastHost]. Get it with [ToastHost.of].
class ToastController extends ChangeNotifier {
  ToastMessage? _current;
  int _serial = 0;

  /// The toast showing, or null.
  ToastMessage? get current => _current;

  /// Increases with every [show], so a replacement with the same words still counts as new.
  int get serial => _serial;

  /// Shows [message], replacing any toast showing, at once. With [undo], the toast has the Undo button and
  /// ⌘Z (Ctrl+Z) undoes the change while it shows.
  void show(String message, {ToastUndo? undo}) {
    _current = ToastMessage(message, undo: undo);
    _serial++;
    notifyListeners();
  }

  /// Takes the toast away.
  void hide() {
    if (_current == null) return;
    _current = null;
    _serial++;
    notifyListeners();
  }
}

/// A short message at the bottom of the content area saying that something has just happened, with at
/// most one action, Undo; it goes away by itself (design/components/Toast).
///
/// Put one around each app's content area, beside the sidebar, with any [InspectorLayout] inside it: the
/// toast then sits centred over the part of the content the inspector leaves in view ([ToastArea]), never
/// over the inspector, and its Undo comes after the inspector in the Tab order. Show toasts with
/// `ToastHost.of(context).show(...)`.
///
/// - **The bar:** `surface-raised`, `radius-xl`, `shadow-2`, at least `control-height` plus `space-2` above
///   and below. The message in `body`, `space-5` from the start; Undo, a Tonal button, `space-4` after it and
///   `space-2` from the end (without it, `space-5` both sides). No icon, no close button. Centred `space-6`
///   above the bottom, as wide as its content and at most `content-max`.
/// - **Timing:** `toast-duration` (8 s). The time stops while the pointer is over it or touches it, while
///   Undo has keyboard focus, while its undo is running, and while the window is not active; the full time
///   starts again after.
/// - **One at a time:** a new toast replaces the one showing, at once: the text swaps with a `fast` fade
///   while the bar takes its new width (`standard`).
/// - **Undo:** the button, or ⌘Z (Ctrl+Z) while the toast shows and no text field has focus (text comes
///   first), runs [ToastMessage.undo]; its [UndoResult] replaces the toast, with no action, unless a newer
///   toast came meanwhile. Under an [AppMenuBar] the menu bar owns ⌘Z and runs the toast's undo from it.
/// - **Keyboard:** never takes focus; Undo is the last stop in the Tab order. When Undo goes away or is
///   replaced while it has focus, focus returns to what had it before (or [UndoResult.focus]); Escape on it
///   closes the toast the same way.
/// - **Screen readers:** "Contact deleted. Undo with Command Z." ("Undo is in More actions." on a phone),
///   read once, politely: on a phone through a live region (a new one per toast, so the same words are read
///   again), on desktop as an announcement (and not as a live region too, which would read it twice).
///   On a phone it also offers a "Close" action.
/// - **Under 600px:** the screen less `space-4` each side, `space-4` above the bottom, or `space-2` above the
///   floating tab bar with [aboveFloatingBar]; a downward swipe closes it.
/// - **Motion:** fades in and rises 8px over `base` (`standard`); fades out over `fast`. With reduced
///   motion, it only fades, over `fast`.
class ToastHost extends StatefulWidget {
  const ToastHost({super.key, required this.child, this.controller, this.aboveFloatingBar = false});

  /// The content area.
  final Widget child;

  /// Null: the host keeps its own.
  final ToastController? controller;

  /// The content sits in a [FloatingBarHost] with a phone's tab bar: the toast sits `space-2` above the bar.
  final bool aboveFloatingBar;

  static const undoLabel = 'Undo';
  static const closeLabel = 'Close';

  /// Space under the bar on desktop, on a phone, and above a floating tab bar.
  static const bottomGap = MyDataSpace.s6;
  static const phoneBottomGap = MyDataSpace.s4;
  static const barGap = MyDataSpace.s2;

  /// The rise as it appears.
  static const rise = MyDataMotion.entranceRise;

  /// The controller of the nearest host.
  static ToastController of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<_ToastScope>();
    assert(scope != null, 'No ToastHost above this context.');
    return scope!.controller;
  }

  /// How the toast is read: the message and the way to undo it.
  static String spoken(ToastMessage t, {required bool phone, TargetPlatform? platform}) {
    if (t.undo == null) return t.message;
    final apple = switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.macOS || TargetPlatform.iOS => true,
      _ => false,
    };
    final how = phone ? 'Undo is in More actions.' : 'Undo with ${apple ? 'Command' : 'Control'} Z.';
    return '${t.message}. $how';
  }

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastScope extends InheritedWidget {
  const _ToastScope({required this.controller, required this.host, required super.child});
  final ToastController controller;
  final _ToastHostState host;

  @override
  bool updateShouldNotify(_ToastScope old) => old.controller != controller || old.host != host;
}

/// Marks the part of a [ToastHost]'s content a toast centres on: put it where an Inspector or another panel
/// covers part of the content ([InspectorLayout] does). It draws nothing and takes no pointer.
class ToastArea extends StatefulWidget {
  const ToastArea({super.key});

  @override
  State<ToastArea> createState() => _ToastAreaState();
}

class _ToastAreaState extends State<ToastArea> {
  _ToastHostState? _host;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = context.getInheritedWidgetOfExactType<_ToastScope>()?.host;
    if (host != _host) {
      _host?._setArea(this, null);
      _host = host;
    }
  }

  @override
  void dispose() {
    final host = _host;
    // The tree is locked while an element unmounts: the host forgets the area once this frame is built.
    if (host != null) WidgetsBinding.instance.addPostFrameCallback((_) => host._setArea(this, null));
    super.dispose();
  }

  /// After every paint (the area moves with an inspector sliding in), measures it against the host.
  void _painted() {
    if (_scheduled || _host == null) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final host = _host;
      if (!mounted || host == null || !host.mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final hostBox = host.context.findRenderObject() as RenderBox?;
      if (box == null || hostBox == null || !box.attached || !hostBox.attached) return;
      host._setArea(this, box.localToGlobal(Offset.zero, ancestor: hostBox) & box.size);
    });
  }

  @override
  Widget build(BuildContext context) => _PaintReporter(onPaint: _painted);
}

class _PaintReporter extends SingleChildRenderObjectWidget {
  const _PaintReporter({required this.onPaint});
  final VoidCallback onPaint;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPaintReporter(onPaint);

  @override
  void updateRenderObject(BuildContext context, _RenderPaintReporter renderObject) => renderObject.onPaint = onPaint;
}

class _RenderPaintReporter extends RenderBox {
  _RenderPaintReporter(this.onPaint);
  VoidCallback onPaint;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) => onPaint();
}

class _ToastHostState extends State<ToastHost> with SingleTickerProviderStateMixin {
  ToastController? _own;
  ToastController get _controller => widget.controller ?? (_own ??= ToastController());

  late final AnimationController _entrance = AnimationController(vsync: this);
  late final AppLifecycleListener _lifecycle;
  final _buttonNode = FocusNode(debugLabel: 'Toast undo');

  /// The menu bar that owns ⌘Z, when there is one; null: the host listens for it itself.
  AppMenuCommands? _menu;
  bool _listening = false;

  /// Where a toast centres (a [ToastArea]); null: the whole host.
  Rect? _area;
  State? _areaOwner;

  void _setArea(State owner, Rect? rect) {
    if (rect == null && _areaOwner != owner) return;
    _areaOwner = rect == null ? null : owner;
    if (rect == _area) return;
    if (!mounted) return;
    setState(() => _area = rect);
  }

  /// What shows (it outlives [ToastController.current] while fading out).
  ToastMessage? _shown;
  int _shownSerial = 0;
  Timer? _timer;
  bool _hovered = false;
  bool _touched = false;
  bool _focused = false;
  bool _inactive = false;
  bool _undoing = false;

  /// The last focus outside the toast, and what had it when focus moved into the toast.
  FocusNode? _lastOutside;
  FocusNode? _before;
  FocusNode? _fallback;

  bool get _paused => _hovered || _touched || _focused || _inactive || _undoing;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    FocusManager.instance.addListener(_focusMoved);
    _buttonNode.addListener(_buttonFocus);
    final state = WidgetsBinding.instance.lifecycleState;
    _inactive = state != null && state != AppLifecycleState.resumed;
    _lifecycle = AppLifecycleListener(
      onStateChange: (s) => _setPause(() => _inactive = s != AppLifecycleState.resumed),
    );
    if (_controller.current != null) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _changed() : null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final menu = AppMenuBar.commandsOf(context);
    if (menu != _menu) {
      _menu?.releaseUndo(this);
      _menu = menu;
      _claim();
    }
    // Under a menu bar ⌘Z is the menu bar's; without one the host listens for it.
    if (_menu != null && _listening) {
      HardwareKeyboard.instance.removeHandler(_undoKey);
      _listening = false;
    } else if (_menu == null && !_listening) {
      HardwareKeyboard.instance.addHandler(_undoKey);
      _listening = true;
    }
  }

  /// Claims the menu bar's Undo while a toast with Undo shows.
  void _claim() {
    final menu = _menu;
    if (menu == null) return;
    if (_controller.current?.undo != null) {
      menu.claimUndo(this, _undoFromKey);
    } else {
      menu.releaseUndo(this);
    }
  }

  @override
  void didUpdateWidget(ToastHost old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      (old.controller ?? _own)?.removeListener(_changed);
      _controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_changed);
    FocusManager.instance.removeListener(_focusMoved);
    if (_listening) HardwareKeyboard.instance.removeHandler(_undoKey);
    _menu?.releaseUndo(this);
    _lifecycle.dispose();
    _entrance.dispose();
    _buttonNode.dispose();
    _own?.dispose();
    super.dispose();
  }

  /// ⌘Z (Ctrl+Z) undoes the toast's change wherever focus is in the window, unless a text field has focus
  /// (there it undoes the typing) or something modal is open over the content.
  bool _undoKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.keyZ || !mounted) return false;
    final k = HardwareKeyboard.instance;
    final apple = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    final command = apple ? k.isMetaPressed && !k.isControlPressed : k.isControlPressed && !k.isMetaPressed;
    if (!command || k.isShiftPressed || k.isAltPressed) return false;
    return _undoFromKey();
  }

  /// ⌘Z, from the host's own handler or the menu bar's: false when the toast cannot undo now.
  bool _undoFromKey() {
    if (!mounted) return false;
    final t = _controller.current;
    if (t == null || t.undo == null || _undoing || editableTextAtFocus() != null) return false;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    unawaited(_undo());
    return true;
  }

  void _focusMoved() {
    final now = FocusManager.instance.primaryFocus;
    if (now != null && now != _buttonNode) _lastOutside = now;
  }

  void _buttonFocus() {
    if (_buttonNode.hasFocus && !_focused) _before = _lastOutside;
    _setPause(() => _focused = _buttonNode.hasFocus);
  }

  void _setPause(VoidCallback change) {
    final was = _paused;
    change();
    if (was == _paused || _shown == null || _controller.current == null) return;
    if (_paused) {
      _timer?.cancel();
    } else {
      _restartTimer();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    if (_paused) return;
    _timer = Timer(MyDataMotion.toastDuration, _controller.hide);
  }

  bool get _reduced => MyDataAccessibility.of(context).reduceMotion;

  void _changed() {
    final next = _controller.current;
    final hadFocus = _buttonNode.hasFocus;
    _claim();
    if (next == null) {
      _timer?.cancel();
      // The bar goes, and a MouseRegion that goes says nothing: the pointer is no longer over the toast, and
      // the next toast's time must run.
      _hovered = false;
      _touched = false;
      _entrance.duration = MyDataMotion.fast;
      _entrance.reverse().whenCompleteOrCancel(() {
        if (mounted && _controller.current == null) setState(() => _shown = null);
      });
      setState(() {});
    } else {
      final appearing = _shown == null || _entrance.status == AnimationStatus.reverse;
      setState(() {
        _shown = next;
        _shownSerial = _controller.serial;
        _undoing = false;
      });
      if (appearing) {
        _entrance.duration = _reduced ? MyDataMotion.fast : MyDataMotion.base;
        _entrance.forward();
      }
      _restartTimer();
      _announce(next);
    }
    // The button goes away, or a new toast takes its place, while it has focus: focus goes back, never to
    // the top, and never stays on an Undo that would now undo the newer change.
    if (hadFocus) _returnFocus();
  }

  void _returnFocus() {
    final before = _before;
    final fallback = _fallback;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (before != null && before.context != null && before.canRequestFocus) {
        before.requestFocus();
      } else if (fallback != null && fallback.context != null) {
        fallback.requestFocus();
      }
    });
  }

  /// The desktop embedders are told directly; phones and the web read the live region.
  static bool get _desktop => switch (defaultTargetPlatform) {
        TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => !kIsWeb,
        _ => false,
      };

  void _announce(ToastMessage t) {
    if (!_desktop) return;
    final phone = MediaQuery.sizeOf(context).width < phoneWidth;
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        ToastHost.spoken(t, phone: phone),
        Directionality.of(context),
      ),
    );
  }

  Future<void> _undo() async {
    final t = _controller.current;
    if (t == null || t.undo == null || _undoing) return;
    // The time stops while the host undoes, so the result is not lost to it running out.
    _setPause(() => _undoing = true);
    setState(() {});
    final UndoResult result;
    try {
      result = await t.undo!();
    } catch (_) {
      if (mounted) setState(() => _setPause(() => _undoing = false));
      rethrow;
    }
    if (!mounted) return;
    _fallback = result.focus;
    final now = _controller.current;
    // A newer toast came meanwhile: it stays; the undo's own result is not shown over it. A toast that only
    // went away (its time, Escape) is replaced by the result, which the user is waiting for.
    if (now != null && !identical(now, t)) {
      _setPause(() => _undoing = false);
      return;
    }
    _controller.show(result.message);
  }

  void _close() {
    final hadFocus = _buttonNode.hasFocus;
    _controller.hide();
    if (hadFocus) _returnFocus();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final phone = mq.size.width < phoneWidth;
    final double bottom;
    if (!phone) {
      bottom = mq.padding.bottom + ToastHost.bottomGap;
    } else if (widget.aboveFloatingBar) {
      bottom = mq.padding.bottom - FloatingBarHost.inset + ToastHost.barGap;
    } else {
      bottom = mq.padding.bottom + ToastHost.phoneBottomGap;
    }

    final shown = _shown;
    Widget? toast;
    if (shown != null) {
      toast = _ToastBar(
        key: const ValueKey('toast'),
        message: shown,
        serial: _shownSerial,
        phone: phone,
        buttonNode: _buttonNode,
        undoing: _undoing,
        liveRegion: !_desktop,
        onUndo: () => unawaited(_undo()),
        onClose: _close,
        onHover: (v) => _setPause(() => _hovered = v),
        onTouch: (v) => _setPause(() => _touched = v),
      );
      final reduced = _reduced;
      toast = AnimatedBuilder(
        animation: _entrance,
        builder: (context, child) {
          final t = MyDataMotion.standard.transform(_entrance.value);
          final faded = FadeTransition(opacity: _entrance, child: child);
          if (reduced) return faded;
          return Transform.translate(offset: Offset(0, ToastHost.rise * (1 - t)), child: faded);
        },
        child: toast,
      );
      toast = Padding(
        padding: EdgeInsets.symmetric(horizontal: phone ? MyDataSpace.s4 : MyDataSpace.s6),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: phone ? double.infinity : MyDataSize.contentMax),
          child: toast,
        ),
      );
    }

    // Centred over the part of the content left in view (beside an inspector), on desktop.
    final area = phone ? null : _area;
    return _ToastScope(
      controller: _controller,
      host: this,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: Stack(
          children: [
            Positioned.fill(
              child: FocusTraversalOrder(
                order: const NumericFocusOrder(0),
                child: FocusTraversalGroup(child: widget.child),
              ),
            ),
            if (toast != null)
              Positioned(
                left: area?.left ?? 0,
                width: area?.width,
                right: area == null ? 0 : null,
                bottom: bottom,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: FocusTraversalGroup(child: toast),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToastBar extends StatelessWidget {
  const _ToastBar({
    super.key,
    required this.message,
    required this.serial,
    required this.phone,
    required this.buttonNode,
    required this.undoing,
    required this.liveRegion,
    required this.onUndo,
    required this.onClose,
    required this.onHover,
    required this.onTouch,
  });

  final ToastMessage message;
  final int serial;
  final bool phone;
  final FocusNode buttonNode;
  final bool undoing;

  /// Read through a live region (phones and the web); on desktop the host announces it instead.
  final bool liveRegion;
  final VoidCallback onUndo;
  final VoidCallback onClose;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onTouch;

  static void _inert() {}

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = MyDataAccessibility.of(context).reduceMotion;
    final hasUndo = message.undo != null;
    final text = Text(message.message, style: MyDataType.body.copyWith(color: c.ink));
    final content = Row(
      mainAxisSize: phone ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Flexible(
          fit: phone ? FlexFit.tight : FlexFit.loose,
          child: AnimatedSwitcher(
            duration: MyDataMotion.fast,
            layoutBuilder: (current, previous) =>
                Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
            child: KeyedSubtree(
              key: ValueKey(serial),
              child: ExcludeSemantics(child: text),
            ),
          ),
        ),
        if (hasUndo) ...[
          const SizedBox(width: MyDataSpace.s4),
          Actions(
            actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => onClose())},
            child: Button(
              label: ToastHost.undoLabel,
              variant: ButtonVariant.tonal,
              focusNode: buttonNode,
              onPressed: undoing ? _inert : onUndo,
            ),
          ),
        ],
      ],
    );

    Widget bar = Container(
      constraints: const BoxConstraints(minHeight: MyDataSize.controlHeight + 2 * MyDataSpace.s2),
      padding: EdgeInsetsDirectional.fromSTEB(
        MyDataSpace.s5,
        MyDataSpace.s2,
        hasUndo ? MyDataSpace.s2 : MyDataSpace.s5,
        MyDataSpace.s2,
      ),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: MyDataRadii.xl,
        boxShadow: context.shadows.shadow2,
      ),
      child: AnimatedSize(
        duration: reduced ? Duration.zero : MyDataMotion.fast,
        curve: MyDataMotion.standard,
        alignment: Alignment.center,
        child: content,
      ),
    );

    bar = Semantics(
      container: true,
      liveRegion: liveRegion,
      explicitChildNodes: true,
      label: ToastHost.spoken(message, phone: phone),
      customSemanticsActions: phone ? {const CustomSemanticsAction(label: ToastHost.closeLabel): onClose} : null,
      child: bar,
    );
    // A new live region per toast: a replacement with the same words is still a new toast and is read again.
    if (liveRegion) bar = KeyedSubtree(key: ValueKey('toast-live-$serial'), child: bar);

    bar = MouseRegion(onEnter: (_) => onHover(true), onExit: (_) => onHover(false), child: bar);
    bar = Listener(
      onPointerDown: (e) {
        if (e.kind == PointerDeviceKind.touch) onTouch(true);
      },
      onPointerUp: (_) => onTouch(false),
      onPointerCancel: (_) => onTouch(false),
      child: bar,
    );
    if (phone) {
      bar = GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 0) onClose();
        },
        child: bar,
      );
    }
    // A Material ancestor for the text's selection and the button's tooltip, with no ink of its own.
    return Material(type: MaterialType.transparency, child: bar);
  }
}
