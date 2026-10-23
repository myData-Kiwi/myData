import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../mac/mac_overlays.dart' show MacAlert;
import '../mac/mac_window.dart';
import '../theme/motion.dart';
import '../theme/theme.dart';
import 'app_frame.dart' show AppLayout;
import 'button.dart';
import 'form_scope.dart';
import 'pressable.dart';

/// The width under which a window is a phone's: dialogs stack their buttons, an Inspector becomes a Sheet,
/// a Toast spans the screen (design/components, "Under 600px"). The one breakpoint, [AppLayout.railMin].
const double phoneWidth = AppLayout.railMin;

/// Checks a form when its confirming button (or Save) is pressed: returns the focus nodes of the fields
/// that are wrong, in order, after giving each its error; empty when every field is right. Focus then moves
/// to the first wrong field and nothing is sent.
typedef FormCheck = List<FocusNode> Function();

/// Sends a form or confirms an action to the host: completes with null when the host has done it, or with
/// the failure line, a full sentence saying what failed and what to do ("The contacts could not be
/// deleted. The host did not answer. Check that it is running, then try again.").
typedef HostAction = Future<String?> Function();

/// A small window over the app that asks one question before something happens, or takes one or two values
/// to make something new (design/components/Dialog). Show it with [showMyDataDialog].
///
/// - A `scrim` over the whole window; centred on it a `surface-raised` panel, `radius-xl`, `shadow-2`,
///   `space-6` padding, `dialog-width` wide or the window less `space-8` each side. Under 600px it is the
///   screen less `space-4` each side, its buttons stack full width with the confirming one on top, and it
///   moves up above the on-screen keyboard.
/// - Top to bottom: the [title] (`title`, `ink`); `space-2` under it the [message] (`body`), any [content]
///   and the [fields], each `space-4` apart; the failure line; `space-6` under the body, the buttons at the
///   end edge, `space-2` apart: [cancelLabel] (plain), then [confirmLabel]. No close icon. In a window too
///   short for it, the body scrolls and the title and buttons stay.
/// - **The confirming button** is the Danger button when [destructive], else the Filled one. A dialog that
///   only tells ([cancelLabel] null) has one Filled button, "Done".
/// - **Working:** from the press until [onConfirm] completes, the buttons are inert, fields read-only
///   ([FormBusy]), Escape does nothing, and the confirming button shows [workingLabel] at its old width;
///   screen readers hear [workingAnnouncement] politely, once.
/// - **Failed:** [onConfirm] completed with a line: it shows above the buttons in `body` and `danger`, is
///   read at once (assertively), and focus goes to the confirming button, which tries again.
/// - **Keyboard:** focus starts on Cancel when [destructive], else on the first field, else on the
///   confirming button. Tab and Shift-Tab stay inside. Return in a text field presses the confirming button
///   (never a destructive one). Escape, and ⌘. on macOS, is Cancel (the one button of a dialog that only
///   tells). Clicking the scrim does nothing. On closing, focus returns to what opened it.
/// - **Screen readers:** a dialog, or an alert dialog when [destructive], named by its title; the rest of
///   the window is hidden while it is open.
/// - **Motion:** the scrim fades in over `slow`; the panel fades in and grows from 97% over `slow`
///   (`standard`); both fade out over `fast`. With reduced motion, both only fade, over `fast`.
class MyDataDialog extends StatefulWidget {
  const MyDataDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.fields = const [],
    required this.confirmLabel,
    this.cancelLabel = defaultCancelLabel,
    this.destructive = false,
    this.onConfirm,
    this.check,
    this.workingLabel,
    this.workingAnnouncement,
  }) : assert(onConfirm == null || workingLabel != null, 'A dialog that waits for the host names what it does.');

  /// A question naming the action and the object ("Delete 3 contacts?"), or what a form makes ("New
  /// calendar"), in sentence case.
  final String title;

  /// One to three full sentences: what will happen, what else it affects and whether it can be undone.
  final String? message;

  /// Anything else the body shows under [message], such as the agent token's MonoWells.
  final Widget? content;

  /// One or two fields, each with its label above (TextField, ColourPicker).
  final List<Widget> fields;

  /// Names the result, with the count when there is one: "Delete 3 contacts", "Create calendar". Never "OK".
  final String confirmLabel;

  /// "Cancel", or what it keeps when "Cancel" would be unclear ("Keep editing"). Null for a dialog that only
  /// tells, whose one button is [confirmLabel] ("Done").
  final String? cancelLabel;

  /// It deletes, removes, revokes or discards: a Danger confirming button, focus starting on Cancel.
  final bool destructive;

  /// What the confirming button does. Null closes the dialog at once, answering true.
  final HostAction? onConfirm;

  /// Checks the [fields] before [onConfirm] runs.
  final FormCheck? check;

  /// The confirming button's label while the host works: "Deleting…", "Creating…".
  final String? workingLabel;

  /// Heard once when work starts: "Deleting 3 contacts". Defaults to [workingLabel] without its ellipsis.
  final String? workingAnnouncement;

  static const defaultCancelLabel = 'Cancel';

  /// The panel's padding, and the gap above the buttons.
  static double padding(MyDataLook look) => look.space(6);

  /// Between the title and the body.
  static double titleGap(MyDataLook look) => look.space(2);

  /// Between fields, and above the failure line.
  static double fieldGap(MyDataLook look) => look.space(4);

  /// The space kept round the panel on a desktop window, and on a phone.
  static double windowMargin(MyDataLook look) => look.space(8);
  static double phoneMargin(MyDataLook look) => look.space(4);

  /// The panel's width in a window [windowWidth] wide.
  static double widthFor(MyDataLook look, double windowWidth) => windowWidth < phoneWidth
      ? math.max(0, windowWidth - 2 * phoneMargin(look))
      : math.max(0, math.min(MyDataSize.dialogWidth, windowWidth - 2 * windowMargin(look)));

  @override
  State<MyDataDialog> createState() => _MyDataDialogState();
}

/// Shows the dialog [builder] returns (a [MyDataDialog], or a widget of the app's that builds one and keeps
/// its fields' state) over the whole window. Completes with true when the confirming button finished, false
/// when the dialog was cancelled.
Future<bool> showMyDataDialog({required BuildContext context, required WidgetBuilder builder}) async {
  final reduced = MyDataMotion.reduced(context);
  final answer = await Navigator.of(context, rootNavigator: true).push<bool>(_DialogRoute(
    builder: builder,
    scrim: context.colors.scrim,
    reduced: reduced,
    motion: context.motion,
    capturedThemes: InheritedTheme.capture(from: context, to: Navigator.of(context, rootNavigator: true).context),
  ));
  return answer ?? false;
}

/// The Inspector's and the Sheet's question before leaving with changes: "Discard changes?", with [message]
/// ("Your changes to Ava Fictional are not saved.", or "This new contact is not saved."), "Keep editing"
/// (with focus) and "Discard changes" (Danger). Completes with true to discard.
Future<bool> showDiscardChangesDialog(BuildContext context, {required String message}) => showMyDataDialog(
      context: context,
      builder: (_) => MyDataDialog(
        title: discardTitle,
        message: message,
        cancelLabel: keepEditingLabel,
        confirmLabel: discardLabel,
        destructive: true,
      ),
    );

/// The words of [showDiscardChangesDialog].
const discardTitle = 'Discard changes?';
const keepEditingLabel = 'Keep editing';
const discardLabel = 'Discard changes';

class _DialogRoute extends PopupRoute<bool> {
  _DialogRoute({
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

  /// No scrim in the Mac frame: a sheet leaves its window as it is (the barrier still takes the clicks).
  @override
  Color? get barrierColor => MacWindow.of(navigator!.context) ? null : scrim;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => reduced ? motion.fast : motion.slow;

  @override
  Duration get reverseTransitionDuration => motion.fast;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      capturedThemes.wrap(Builder(builder: builder));

  @override
  Widget buildTransitions(
      BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: context.motion.standard);
    final faded = FadeTransition(opacity: curved, child: child);
    if (reduced) return faded;
    // The Mac frame's sheet comes down from the toolbar's edge.
    if (MacWindow.of(context)) {
      return SlideTransition(
        position: Tween(begin: Offset(0, -context.motion.sheetDrop), end: Offset.zero).animate(curved),
        child: faded,
      );
    }
    return ScaleTransition(scale: Tween(begin: context.motion.pressScale, end: 1.0).animate(curved), child: faded);
  }
}

/// The text field that has focus, or null: keys meant for text (Return in a text area, ⌘Z) go to it first
/// (design/platforms.md "Which handler gets a key first").
EditableText? editableTextAtFocus() {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return null;
  final w = focused.widget;
  return w is EditableText ? w : focused.findAncestorWidgetOfExactType<EditableText>();
}

class _ConfirmFromFieldIntent extends Intent {
  const _ConfirmFromFieldIntent();
}

/// Return in a text field confirms; anywhere else the key goes on to whatever has focus.
class _ConfirmFromFieldAction extends Action<_ConfirmFromFieldIntent> {
  _ConfirmFromFieldAction(this.onConfirm, {required this.allowed});
  final VoidCallback onConfirm;
  final bool allowed;

  @override
  bool isEnabled(_ConfirmFromFieldIntent intent) {
    if (!allowed) return false;
    final field = editableTextAtFocus();
    return field != null && field.maxLines == 1;
  }

  @override
  void invoke(_ConfirmFromFieldIntent intent) => onConfirm();
}

/// Holds a button at the width [label] gives it while its own label changes to [shown] ("Deleting…" in the
/// place of "Delete 3 contacts"), so nothing moves.
class SteadyWidthButton extends StatelessWidget {
  const SteadyWidthButton(
      {super.key, required this.label, required this.shown, required this.variant, required this.onPressed, this.focusNode});

  final String label;
  final String shown;
  final ButtonVariant variant;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => _HoldWidth(
        hold: shown != label,
        child: Button(label: shown, variant: variant, onPressed: onPressed, focusNode: focusNode),
      );
}

/// Sizes to its child and remembers the width; while [hold] is true it keeps that width.
class _HoldWidth extends SingleChildRenderObjectWidget {
  const _HoldWidth({required this.hold, required super.child});
  final bool hold;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHoldWidth(hold);

  @override
  void updateRenderObject(BuildContext context, _RenderHoldWidth renderObject) => renderObject.hold = hold;
}

class _RenderHoldWidth extends RenderProxyBox {
  _RenderHoldWidth(this._hold);

  bool _hold;
  set hold(bool value) {
    if (value == _hold) return;
    _hold = value;
    markNeedsLayout();
  }

  double? _width;

  @override
  void performLayout() {
    final child = this.child!;
    final held = _width;
    if (_hold && held != null) {
      final w = held.clamp(constraints.minWidth, constraints.maxWidth);
      child.layout(constraints.tighten(width: w), parentUsesSize: true);
      size = constraints.constrain(child.size);
    } else {
      child.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child.size);
      _width = size.width;
    }
  }
}

class _MyDataDialogState extends State<MyDataDialog> {
  final _cancelNode = FocusNode(debugLabel: 'Dialog cancel');
  final _confirmNode = FocusNode(debugLabel: 'Dialog confirm');
  final _fieldsNode = FocusNode(debugLabel: 'Dialog fields', skipTraversal: true, canRequestFocus: false);
  final _commits = FormCommitScope();
  bool _working = false;
  bool _committing = false;
  String? _failure;

  bool get _onlyTells => widget.cancelLabel == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusFirst());
  }

  void _focusFirst() {
    if (!mounted) return;
    if (widget.destructive && !_onlyTells) return _cancelNode.requestFocus();
    if (widget.fields.isNotEmpty) {
      final first = _fieldsNode.traversalDescendants.firstOrNull;
      if (first != null) return first.requestFocus();
    }
    _confirmNode.requestFocus();
  }

  @override
  void dispose() {
    _cancelNode.dispose();
    _confirmNode.dispose();
    _fieldsNode.dispose();
    super.dispose();
  }

  void _close(bool answer) {
    if (mounted) Navigator.of(context).pop(answer);
  }

  void _cancel() {
    if (_working) return;
    if (_onlyTells) return _confirmNow();
    _close(false);
  }

  void _confirmNow() => unawaited(_confirm());

  Future<void> _confirm() async {
    if (_working || _committing) return;
    // Typing a field holds until Return or leaving it (a date, a time, a token) is committed first, and the
    // dialog checks and sends the values it gives (typing is never lost silently).
    final pending = _commits.commitAll();
    if (pending.wrong != null) {
      setState(() => _failure = null);
      pending.wrong!.requestFocus();
      return;
    }
    if (pending.committed) {
      _committing = true;
      await WidgetsBinding.instance.endOfFrame;
      _committing = false;
      if (!mounted || _working) return;
    }
    final wrong = widget.check?.call() ?? const [];
    if (wrong.isNotEmpty) {
      setState(() => _failure = null);
      wrong.first.requestFocus();
      return;
    }
    final action = widget.onConfirm;
    if (action == null) return _close(true);
    setState(() {
      _working = true;
      _failure = null;
    });
    final view = View.of(context);
    final direction = Directionality.of(context);
    unawaited(SemanticsService.sendAnnouncement(view, _workingAnnouncement, direction));
    String? failure;
    try {
      failure = await action();
    } finally {
      if (mounted) setState(() => _working = false);
    }
    if (!mounted) return;
    if (failure == null) return _close(true);
    setState(() => _failure = failure);
    _confirmNode.requestFocus();
    unawaited(SemanticsService.sendAnnouncement(view, failure, direction, assertiveness: Assertiveness.assertive));
  }

  String get _workingAnnouncement {
    final given = widget.workingAnnouncement;
    if (given != null) return given;
    final label = widget.workingLabel ?? widget.confirmLabel;
    return label.endsWith('…') ? label.substring(0, label.length - 1) : label;
  }

  static void _inert() {}

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = MediaQuery.sizeOf(context);
    final phone = size.width < phoneWidth;
    final variant = _onlyTells
        ? ButtonVariant.filled
        : (widget.destructive ? ButtonVariant.danger : ButtonVariant.filled);

    final confirm = SteadyWidthButton(
      label: widget.confirmLabel,
      shown: _working ? (widget.workingLabel ?? widget.confirmLabel) : widget.confirmLabel,
      variant: variant,
      focusNode: _confirmNode,
      onPressed: _working ? _inert : _confirmNow,
    );
    final cancel = _onlyTells
        ? null
        : Button(
            label: widget.cancelLabel!,
            variant: ButtonVariant.plain,
            focusNode: _cancelNode,
            onPressed: _working ? _inert : _cancel,
          );

    final Widget buttons = phone
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            confirm,
            if (cancel != null) ...[SizedBox(height: ButtonRow.gap(context.look)), cancel],
          ])
        : ButtonRow(alignment: WrapAlignment.end, children: [?cancel, confirm]);

    final bodyChildren = <Widget>[
      if (widget.message != null) Text(widget.message!, style: context.typeScale.body.copyWith(color: c.ink)),
      ?widget.content,
      if (widget.fields.isNotEmpty)
        Focus(
          focusNode: _fieldsNode,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < widget.fields.length; i++) ...[
              if (i > 0) SizedBox(height: MyDataDialog.fieldGap(context.look)),
              widget.fields[i],
            ],
          ]),
        ),
    ];

    // The Mac frame: an alert as macOS 26 draws it (mac/mac_overlays.dart), with the same behaviour; Cancel
    // is a push button there.
    final panel = MacWindow.of(context)
        ? MacAlert.panel(
            context,
            title: widget.title,
            message: widget.message,
            content: widget.content,
            fields: widget.fields.isEmpty ? null : bodyChildren.last,
            failure: _failure,
            // Destructive: Cancel is the default button (the accent, and focus, so Return presses it) and the
            // action a push button with red text (Button's danger variant in the Mac frame).
            cancel: _onlyTells
                ? null
                : Button(
                    label: widget.cancelLabel!,
                    variant: widget.destructive ? ButtonVariant.filled : ButtonVariant.tonal,
                    focusNode: _cancelNode,
                    onPressed: _working ? _inert : _cancel,
                  ),
            confirm: confirm,
            destructive: widget.destructive,
            buttonLabels: [?widget.cancelLabel, widget.confirmLabel, ?widget.workingLabel],
          )
        : Container(
      width: MyDataDialog.widthFor(context.look, size.width),
      padding: EdgeInsets.all(MyDataDialog.padding(context.look)),
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: MyDataRadii.xl(context.look), boxShadow: context.shadows.shadow2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(widget.title, style: context.typeScale.title.copyWith(color: c.ink))),
          if (bodyChildren.isNotEmpty)
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(top: MyDataDialog.titleGap(context.look)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < bodyChildren.length; i++) ...[
                    if (i > 0) SizedBox(height: MyDataDialog.fieldGap(context.look)),
                    bodyChildren[i],
                  ],
                ]),
              ),
            ),
          if (_failure != null) ...[
            SizedBox(height: MyDataDialog.fieldGap(context.look)),
            Text(_failure!, style: context.typeScale.body.copyWith(color: c.danger)),
          ],
          SizedBox(height: MyDataDialog.padding(context.look)),
          buttons,
        ],
      ),
    );

    final apple = defaultTargetPlatform == TargetPlatform.macOS;
    final margin = phone ? MyDataDialog.phoneMargin(context.look) : MyDataDialog.windowMargin(context.look);
    return PopScope(
      canPop: !_working && !_onlyTells,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _onlyTells && !_working) _confirmNow();
      },
      child: Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.enter): const _ConfirmFromFieldIntent(),
          const SingleActivator(LogicalKeyboardKey.numpadEnter): const _ConfirmFromFieldIntent(),
          if (apple) const SingleActivator(LogicalKeyboardKey.period, meta: true): const DismissIntent(),
        },
        child: Actions(
          actions: {
            DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => _cancel()),
            _ConfirmFromFieldIntent: _ConfirmFromFieldAction(_confirmNow, allowed: !widget.destructive),
          },
          child: FormBusy(
            busy: _working,
            child: FormCommit(
              scope: _commits,
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: widget.title,
                role: widget.destructive ? SemanticsRole.alertDialog : SemanticsRole.dialog,
                child: AnimatedPadding(
                  duration: context.motion.base,
                  curve: context.motion.standard,
                  padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
                  child: SafeArea(
                    // The Mac frame: a sheet, hanging from the toolbar's edge at the top of the window.
                    child: MacWindow.of(context)
                        ? Padding(
                            padding: EdgeInsets.only(top: MyDataMacSize.toolbarHeight, bottom: context.space(8)),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: Material(type: MaterialType.transparency, child: panel),
                            ),
                          )
                        : Padding(
                            padding: EdgeInsets.symmetric(vertical: margin),
                            child: Center(child: Material(type: MaterialType.transparency, child: panel)),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
