import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/semantics.dart';

import '../theme/motion.dart';
import '../theme/theme.dart';
import 'app_frame.dart' show PhoneType;
import 'button.dart';
import 'dialog.dart';
import 'form_scope.dart';
import 'pressable.dart';

/// The two kinds of [Sheet] (design/components/Sheet, "Two kinds, one shape").
enum SheetKind {
  /// The Inspector on a phone: almost the full height, on `surface`, with Cancel, the title and Save.
  editor,

  /// A Select's, DatePicker's or TimePicker's list on a phone: as tall as its content, on `surface-raised`.
  picker,
}

/// Shows the sheet [builder] returns (a [Sheet], or an [Inspector], which becomes the editor sheet) rising
/// from the bottom of a phone screen over a `scrim`. Completes with what the sheet was popped with: null
/// after Cancel, or the value a picker's row chose (`Navigator.pop(context, value)`).
///
/// At most two sheets stack: a picker may open over an editor, never a third.
Future<T?> showSheet<T>({required BuildContext context, required WidgetBuilder builder}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  return navigator.push<T>(_SheetRoute<T>(
    builder: builder,
    scrim: context.colors.scrim,
    reduced: MyDataMotion.reduced(context),
    motion: context.motion,
    capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
  ));
}

/// Marks what a sheet route shows, so an [Inspector] inside one draws itself as the editor sheet.
class SheetScope extends InheritedWidget {
  const SheetScope({super.key, required this.animation, required this.reduced, required super.child});

  /// The route's animation: 0 hidden, 1 risen.
  final Animation<double> animation;

  /// Reduced motion was on when the sheet opened: it fades instead of rising.
  final bool reduced;

  static SheetScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SheetScope>();

  @override
  bool updateShouldNotify(SheetScope old) => old.animation != animation || old.reduced != reduced;
}

class _SheetRoute<T> extends PopupRoute<T> {
  _SheetRoute({
    required this.builder,
    required this.scrim,
    required this.reduced,
    required this.motion,
    required this.capturedThemes,
  });

  final WidgetBuilder builder;
  final Color scrim;
  final bool reduced;
  final MyDataMotionSpec motion;
  final CapturedThemes capturedThemes;

  @override
  Color? get barrierColor => scrim;

  // The scrim's tap is the sheet's Cancel, with the check for changes; the sheet handles it.
  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => reduced ? motion.fast : motion.slow;

  @override
  Duration get reverseTransitionDuration => reduced ? motion.fast : motion.base;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      capturedThemes.wrap(SheetScope(animation: animation, reduced: reduced, child: Builder(builder: builder)));
}

/// A panel that rises from the bottom of a phone screen for a short task that returns to the screen
/// beneath: editing a record ([SheetKind.editor]) or picking one value ([SheetKind.picker])
/// (design/components/Sheet). Phones only; show it with [showSheet].
///
/// - `radius-xl` top corners, `shadow-2`, and a grabber (`icon-tile` by `space-1`, `line-strong`, `space-2`
///   from the top). The header is one `control-height` row: Cancel (plain) at the start, the [title] in
///   `heading` in the middle, and [trailing] at the end (Save, filled; Done, plain; or nothing).
/// - **Editor:** `surface`, from `space-3` under the status bar to the bottom; the [body] scrolls under the
///   header with `space-4` padding across, and a 1px `line` shows under the header while it is scrolled.
///   **Picker:** `surface-raised`, as tall as its content up to the editor's height; the body ends above the
///   home indicator.
/// - **Leaving:** Cancel, a tap on the scrim, Escape, the system back gesture, a screen reader's dismiss, or
///   a drag down past a third of its height (or a flick) are Cancel. With [pending] input, or a field in the
///   body holding typing it has not committed ([PendingInput]), it never closes first: a drag resists (at most
///   `space-8`, springing back), and a drag that would have closed it (held at that limit, or a flick down)
///   asks "Discard changes?" with [discardMessage]; so do Cancel, the scrim and back. Then [onCancel] runs and
///   the sheet closes.
/// - **Busy** ([busy], while the editor saves): the header's buttons are inert, and nothing closes it.
/// - **Focus:** modal. On opening, focus goes to [initialFocus] (a picker's chosen row) or the first field
///   of the body, and the title is announced politely. On closing it returns to what opened the sheet.
/// - **On-screen keyboard:** the body shrinks to the space above it; the header never moves.
/// - **Motion:** rises with `spring` while the scrim fades in over `slow`; follows the finger while dragged;
///   leaves downward over `base`. With reduced motion it fades over `fast`, and a drag still moves it.
class Sheet extends StatefulWidget {
  const Sheet({
    super.key,
    required this.kind,
    required this.title,
    required this.body,
    this.trailing,
    this.onCancel,
    this.pending = false,
    this.discardMessage,
    this.busy = false,
    this.initialFocus,
    this.scrollable = true,
    this.leadingLabel = cancelLabel,
    this.commits,
  }) : assert(!pending || discardMessage != null, 'A sheet with pending input says what would be lost.');

  final SheetKind kind;

  /// What is edited or picked, in sentence case: "Edit contact", "Start date", "Label for phone 1".
  final String title;

  /// The form (editor), or the rows or calendar (picker).
  final Widget body;

  /// The end of the header: Save (a filled [Button]) on an editor, Done (a plain [Button]) on a picker that
  /// holds typing, or null on a picker that picks on a tap.
  final Widget? trailing;

  /// Runs when the user leaves without saving (after "Discard changes" when [pending]), before the sheet
  /// closes.
  final VoidCallback? onCancel;

  /// An editor with changes, or a picker with typed text not yet committed.
  final bool pending;

  /// The "Discard changes?" body: "Your changes to Ava Fictional are not saved."
  final String? discardMessage;

  /// The holder is waiting for the host: the header's buttons are inert and nothing closes the sheet.
  final bool busy;

  /// Where focus goes on opening: a picker's chosen row or day. Null: the first field of the body.
  final FocusNode? initialFocus;

  /// Wraps [body] in a scroll view. A picker that keeps a field above its scrolling rows turns it off.
  final bool scrollable;

  /// The start button's label.
  final String leadingLabel;

  /// The fields' [FormCommitScope], when the holder commits their typing itself (an [Inspector] on a phone).
  /// Null: the sheet keeps its own for the fields of its body.
  final FormCommitScope? commits;

  /// "Discard changes?"'s body when a field holds typing and no [discardMessage] is given.
  static const typedDiscardMessage = 'What you typed is not saved.';

  static const cancelLabel = 'Cancel';
  static const saveLabel = 'Save';
  static const doneLabel = 'Done';

  /// The editor sheet leaves this much of the screen behind showing under the status bar.
  static double topGap(MyDataLook look) => look.space(3);

  /// The grabber: a pill `icon-tile` wide and `space-1` tall, `space-2` from the top.
  static double grabberWidth(MyDataLook look) => look.density.iconTile;
  static double grabberHeight(MyDataLook look) => look.space(1);
  static double grabberTop(MyDataLook look) => look.space(2);

  /// How far a drag moves a sheet with pending input before it resists.
  static double resistance(MyDataLook look) => look.space(8);

  /// Released past this share of its height, a drag is Cancel.
  static const dismissFraction = 1 / 3;

  /// A downward flick faster than this (logical pixels a second) is Cancel.
  static const flickVelocity = 700.0;

  /// Padding across the body.
  static double bodyPadding(MyDataLook look) => look.space(4);

  @override
  State<Sheet> createState() => _SheetState();
}

class _SheetState extends State<Sheet> with SingleTickerProviderStateMixin {
  late final AnimationController _drag = AnimationController.unbounded(vsync: this);
  final _bodyNode = FocusNode(debugLabel: 'Sheet body', skipTraversal: true, canRequestFocus: false);
  final _panelKey = GlobalKey();
  final _ownCommits = FormCommitScope();
  CurvedAnimation? _rise;
  bool _scrolled = false;
  bool _asking = false;
  bool _left = false;

  FormCommitScope get _commits => widget.commits ?? _ownCommits;

  /// Changes, or typing a field has not committed: leaving asks first.
  bool get _pending => widget.pending || _commits.hasPendingInput;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (widget.initialFocus ?? _bodyNode.traversalDescendants.firstOrNull)?.requestFocus();
      unawaited(SemanticsService.sendAnnouncement(View.of(context), widget.title, Directionality.of(context)));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = SheetScope.maybeOf(context)?.animation ?? kAlwaysCompleteAnimation;
    if (_rise?.parent == animation) return;
    _rise?.dispose();
    _rise = CurvedAnimation(
      parent: animation,
      // The spring's share of the sheet's run: all of it when the spring is the longer (a lively theme), and
      // when nothing moves at all (`motion: none`, whose durations are zero).
      curve: Interval(
          0,
          context.motion.slow == Duration.zero
              ? 1
              : (context.motion.springDuration.inMicroseconds / context.motion.slow.inMicroseconds).clamp(0.0, 1.0),
          curve: context.motion.springCurve),
      reverseCurve: context.motion.standard,
    );
  }

  @override
  void dispose() {
    _rise?.dispose();
    _drag.dispose();
    _bodyNode.dispose();
    super.dispose();
  }

  double get _height => (_panelKey.currentContext?.findRenderObject() as RenderBox?)?.size.height ?? 0;

  /// Cancel, from any of its ways: asks first when something is pending.
  Future<void> _requestCancel() async {
    if (widget.busy || _asking || _left) return;
    if (_pending) {
      _asking = true;
      final discard =
          await showDiscardChangesDialog(context, message: widget.discardMessage ?? Sheet.typedDiscardMessage);
      _asking = false;
      if (!discard || !mounted) return;
    }
    _leave();
  }

  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    widget.onCancel?.call();
    Navigator.of(context).pop();
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (widget.busy || _left) return;
    _drag.stop();
    final next = _drag.value + d.delta.dy;
    _drag.value = _pending ? next.clamp(0.0, Sheet.resistance(context.look)) : next.clamp(0.0, double.infinity);
  }

  void _dragEnd(DragEndDetails d) {
    if (widget.busy || _left) return;
    final velocity = d.velocity.pixelsPerSecond.dy;
    if (_pending) {
      // Only a drag that would have closed the sheet asks: held down at the limit, or flicked down. Any other
      // (upward, or a few pixels) just springs back.
      final wouldLeave = _drag.value >= Sheet.resistance(context.look) - 0.5 || velocity > Sheet.flickVelocity;
      _springBack(velocity);
      if (wouldLeave) unawaited(_requestCancel());
      return;
    }
    if (_drag.value > _height * Sheet.dismissFraction || velocity > Sheet.flickVelocity) {
      _leave();
    } else {
      _springBack(velocity);
    }
  }

  void _springBack(double velocity) =>
      _drag.animateWith(SpringSimulation(context.motion.spring, _drag.value, 0, velocity));

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    final scrolled = n.metrics.pixels > n.metrics.minScrollExtent;
    if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    return false;
  }

  static void _inert() {}

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mq = MediaQuery.of(context);
    final scope = SheetScope.maybeOf(context);
    final editor = widget.kind == SheetKind.editor;
    final topLimit = mq.padding.top + Sheet.topGap(context.look);
    final keyboard = mq.viewInsets.bottom;

    final header = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _dragUpdate,
      onVerticalDragEnd: _dragEnd,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _scrolled ? c.line : c.line.withValues(alpha: 0))),
        ),
        padding: EdgeInsets.fromLTRB(context.space(2), Sheet.grabberTop(context.look), context.space(2), context.space(2)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(
            child: Container(
              width: Sheet.grabberWidth(context.look),
              height: Sheet.grabberHeight(context.look),
              decoration: context.radius.decorate(BoxDecoration(color: c.lineStrong, borderRadius: MyDataRadii.pill(context.look))),
            ),
          ),
          SizedBox(height: context.space(1)),
          SizedBox(
            height: context.density.controlHeight,
            // Cancel and the end button share the sides equally, so the title sits in the middle.
            child: LayoutBuilder(
              builder: (context, constraints) => Row(children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Button(
                      label: widget.leadingLabel,
                      variant: ButtonVariant.plain,
                      onPressed: widget.busy ? _inert : () => unawaited(_requestCancel()),
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
                  child: Semantics(
                    header: true,
                    child: Text(widget.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.typeScale.heading.copyWith(color: c.ink)),
                  ),
                ),
                Expanded(
                  child: Align(
                      alignment: AlignmentDirectional.centerEnd, child: widget.trailing ?? const SizedBox()),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );

    Widget body = Focus(focusNode: _bodyNode, child: FormCommit(scope: _commits, child: widget.body));
    if (widget.scrollable) {
      body = SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(Sheet.bodyPadding(context.look), editor ? context.space(2) : 0, Sheet.bodyPadding(context.look),
            Sheet.bodyPadding(context.look) + (keyboard > 0 ? 0 : mq.padding.bottom)),
        child: body,
      );
    } else {
      body = Padding(padding: EdgeInsets.only(bottom: keyboard > 0 ? 0 : mq.padding.bottom), child: body);
    }
    body = NotificationListener<ScrollNotification>(onNotification: _onScroll, child: body);

    Widget panel = Container(
      key: _panelKey,
      decoration: context.radius.decorate(BoxDecoration(
        color: editor ? c.surface : c.surfaceRaised,
        borderRadius: BorderRadius.vertical(top: Radius.circular(context.radius.xl)),
        boxShadow: context.shadows.shadow2,
      )),
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Column(
          mainAxisSize: editor ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, if (editor) Expanded(child: body) else Flexible(child: body)],
        ),
      ),
    );
    panel = Material(type: MaterialType.transparency, child: panel);

    final animation = scope?.animation ?? kAlwaysCompleteAnimation;
    final reduced = scope?.reduced ?? MyDataMotion.reduced(context);
    final rise = _rise!;
    panel = AnimatedBuilder(
      animation: Listenable.merge([_drag, animation]),
      builder: (context, child) {
        // The rise is a share of the panel's own height; the drag is in pixels on top of it.
        Widget moved = Transform.translate(offset: Offset(0, _drag.value), child: child);
        if (reduced) return Opacity(opacity: animation.value.clamp(0.0, 1.0), child: moved);
        return FractionalTranslation(translation: Offset(0, 1 - rise.value), child: moved);
      },
      child: panel,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_requestCancel());
      },
      child: Actions(
        actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => _requestCancel())},
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: widget.title,
          role: SemanticsRole.dialog,
          onDismiss: () => unawaited(_requestCancel()),
          child: Stack(children: [
            // The scrim's tap is Cancel.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTap: () => unawaited(_requestCancel()),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              top: editor ? topLimit : null,
              child: editor
                  ? panel
                  : ConstrainedBox(constraints: BoxConstraints(maxHeight: mq.size.height - topLimit), child: panel),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A picker sheet's row: `row-height`, `body` at 16px ([PhoneType]), with an optional leading mark (a
/// DataColour dot), an optional [caption] under the label in `caption` and `ink-muted`, and the `accent`
/// check mark at the end on the chosen one. Tapping it picks and closes the sheet.
class SheetPickerRow extends StatelessWidget {
  const SheetPickerRow({
    super.key,
    required this.label,
    required this.onPressed,
    this.chosen = false,
    this.leading,
    this.caption,
    this.focusNode,
  });

  final String label;
  final VoidCallback onPressed;
  final bool chosen;
  final Widget? leading;
  final String? caption;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onPressed: onPressed,
      borderRadius: BorderRadius.zero,
      hoverFill: c.surfaceHover,
      scaleOnPress: false,
      focusNode: focusNode,
      semanticLabel: [label, ?caption].join(', '),
      selected: chosen,
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(minHeight: context.density.rowHeight),
          padding: EdgeInsets.symmetric(horizontal: Sheet.bodyPadding(context.look), vertical: context.space(2)),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
          child: Row(children: [
            if (leading != null) ...[
              SizedBox.square(dimension: context.density.iconTile, child: Center(child: leading)),
              SizedBox(width: context.space(3)),
            ],
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: PhoneType.body(context.typeScale.body, phone: true).copyWith(color: c.ink)),
                if (caption != null) Text(caption!, style: context.typeScale.caption.copyWith(color: c.inkMuted)),
              ]),
            ),
            if (chosen) Icon(context.icon(MyDataIcon.check), size: context.density.icon, color: c.accent),
          ]),
        ),
      ),
    );
  }
}
