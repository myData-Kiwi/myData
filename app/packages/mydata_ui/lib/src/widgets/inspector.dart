import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import '../motion.dart';
import '../theme.dart';
import 'app_menu_bar.dart';
import 'button.dart';
import 'dialog.dart';
import 'form_row.dart' show FormGroupHeading;
import 'form_scope.dart';
import 'sheet.dart';
import 'toast.dart' show ToastArea;

/// A panel at the side of the window that creates or edits one record while the list stays in view, ending
/// in Cancel and Save (design/components/Inspector).
///
/// - **From 600px:** a `surface` panel with no border or shadow beside the content ([InspectorLayout]), or
///   in a detail pane's place (put it there directly; it fills the width it is given). Header: the [title]
///   in `title`, `space-5` from the top and `space-4` above the body. Body: the [form], straight on the
///   panel (no cards), scrolling, `space-5` across. Footer: Cancel (plain), then Save (filled), at the end
///   edge, `space-2` apart, `space-4` above and below. A 1px `line` shows under the header while the body is
///   scrolled under it, and above the footer while there is more below.
/// - **Under 600px**, shown with [showSheet], it is the editor [Sheet]: Cancel, the title and Save in the
///   header, no footer.
/// - **Save** is always enabled. With no changes it closes, as Cancel would. With wrong fields ([check]) it
///   sends nothing and focus moves to the first. Otherwise it is **saving** until [onSave] completes: fields
///   read-only ([FormBusy]), buttons inert, "Saving…" at Save's old width and [savingAnnouncement] heard
///   politely. A failure line shows above the footer (under the header on a phone), is read at once, and
///   focus goes to Save.
/// - **Typing a field holds** (a date or time typed but not yet committed, a token not yet made, a custom
///   label: [PendingInput]) is committed before Save decides anything, so ⌘S in the middle of typing saves
///   what was typed; typing that is wrong stops the save with the field's error and focus on it.
/// - **Leaving with changes** ([changed], or typing a field holds): Cancel, Escape and
///   [InspectorState.requestClose] (choosing another record, New, changing section, closing the window) ask
///   "Discard changes?" with [discardMessage] first.
/// - **Keyboard:** opening focuses the first field and announces the title. It is not modal: Tab goes
///   through the fields, Cancel and Save, then on to the rest of the window. ⌘S (Ctrl+S elsewhere) saves
///   wherever focus is in the window (through the [AppMenuBar] when there is one, which then owns the key);
///   ⌘Return saves while focus is inside; Return in a single-line field does not. Escape is Cancel while
///   focus is inside, after anything open inside has closed.
/// - **Screen readers:** a region named by its title.
/// - On closing, [onClosed] runs; the holder removes the inspector and moves focus to the record's row. If
///   it does not, focus goes back to what had it when the inspector opened.
/// - **One inspector per opening:** give it `key: ValueKey(recordId)` (or a key per new record), so opening
///   another record never reuses the state of the one before ([InspectorLayout] also starts afresh whenever
///   it goes from no inspector to one).
class Inspector extends StatefulWidget {
  const Inspector({
    super.key,
    required this.title,
    required this.form,
    required this.changed,
    required this.onSave,
    required this.onClosed,
    required this.discardMessage,
    required this.savingAnnouncement,
    this.check,
    this.failureAction,
  });

  /// What is done to what kind of record: "New contact", "Edit contact", "New event".
  final String title;

  /// The fields, laid out as FormRow says: labels above, `space-4` apart, groups under a `label` heading
  /// (see [InspectorGroupHeading]).
  final Widget form;

  /// Whether any value differs from the one loaded (typing and deleting back is no change).
  final bool changed;

  /// Saves the record: completes with null when the host has it, or the failure line ("Ava Fictional could
  /// not be saved. The host did not answer. Your changes are still here; check that the host is running,
  /// then press Save again.").
  final HostAction onSave;

  /// The inspector is done: [saved] after a successful save, else false. The holder removes it.
  final void Function(bool saved) onClosed;

  /// "Your changes to Ava Fictional are not saved.", or "This new contact is not saved."
  final String discardMessage;

  /// Heard once when saving starts: "Saving Ava Fictional".
  final String savingAnnouncement;

  final FormCheck? check;

  /// A button under the failure line, while one shows, for a failure the user can act on from here: "Reload"
  /// when the record changed elsewhere since the inspector opened (the host refused the save). It is a
  /// Tonal button `space-2` under the line. Null: the line alone.
  final InspectorFailureAction? failureAction;

  static const cancelLabel = 'Cancel';
  static const saveLabel = 'Save';
  static const savingLabel = 'Saving…';

  /// Padding across the panel.
  static const padding = MyDataSpace.s5;

  /// The title's distance from the top, and from the body.
  static const headerTop = MyDataSpace.s5;
  static const headerBottom = MyDataSpace.s4;

  /// Space above and below the footer's buttons.
  static const footerPadding = MyDataSpace.s4;

  @override
  State<Inspector> createState() => InspectorState();
}

/// The state of an [Inspector], for the holder's own ways of leaving and saving (the menu bar's Save, New,
/// another record, another section, closing the window): `GlobalKey<InspectorState>`.
class InspectorState extends State<Inspector> {
  final _bodyNode = FocusNode(debugLabel: 'Inspector body', skipTraversal: true, canRequestFocus: false);
  final _saveNode = FocusNode(debugLabel: 'Inspector save');
  final _scroll = ScrollController();
  final _commits = FormCommitScope();
  FocusNode? _opener;
  bool _saving = false;
  bool _asking = false;
  bool _closed = false;
  bool _committing = false;
  String? _failure;
  bool _hiddenAbove = false;
  bool _hiddenBelow = false;

  /// The menu bar that owns ⌘S, when there is one; null: this inspector listens for it itself.
  AppMenuCommands? _menu;
  bool _listening = false;

  bool get _inSheet => context.getInheritedWidgetOfExactType<SheetScope>() != null;

  /// Whether the holder's Save would act now (the menu bar enables Save while an inspector is open).
  bool get saving => _saving;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_measure);
    _opened();
  }

  /// What opening does: remember what had focus, then focus the first field and announce the title.
  void _opened() {
    _opener = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measure();
      if (_inSheet) return; // The sheet focuses its first field and announces its title.
      _bodyNode.traversalDescendants.firstOrNull?.requestFocus();
      unawaited(SemanticsService.sendAnnouncement(View.of(context), widget.title, Directionality.of(context)));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final menu = AppMenuBar.commandsOf(context);
    if (menu != _menu) {
      _menu?.releaseSave(this);
      _menu = menu;
    }
    // Under a menu bar ⌘S is the menu bar's; without one the inspector listens for it.
    if (_menu != null) {
      _menu!.claimSave(this, _saveFromKey);
      if (_listening) HardwareKeyboard.instance.removeHandler(_globalKey);
      _listening = false;
    } else if (!_listening) {
      HardwareKeyboard.instance.addHandler(_globalKey);
      _listening = true;
    }
  }

  @override
  void didUpdateWidget(Inspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A holder that opens the next record in the same place after this one closed gets a fresh inspector,
    // never a closed one whose Save and Cancel would do nothing.
    if (_closed && !_inSheet) {
      _closed = false;
      _saving = false;
      _asking = false;
      _committing = false;
      _failure = null;
      _opened();
    }
  }

  @override
  void dispose() {
    _menu?.releaseSave(this);
    if (_listening) HardwareKeyboard.instance.removeHandler(_globalKey);
    _bodyNode.dispose();
    _saveNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _measure() {
    if (!_scroll.hasClients || !mounted) return;
    final p = _scroll.position;
    final above = p.pixels > p.minScrollExtent;
    final below = p.pixels < p.maxScrollExtent;
    if (above != _hiddenAbove || below != _hiddenBelow) {
      setState(() {
        _hiddenAbove = above;
        _hiddenBelow = below;
      });
    }
  }

  /// ⌘S (Ctrl+S) saves wherever focus is in the window, while nothing modal is over the inspector.
  bool _globalKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.keyS || !mounted) return false;
    final k = HardwareKeyboard.instance;
    final apple = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    final command = apple ? k.isMetaPressed && !k.isControlPressed : k.isControlPressed && !k.isMetaPressed;
    if (!command || k.isShiftPressed || k.isAltPressed) return false;
    return _saveFromKey();
  }

  /// ⌘S, from this inspector's own handler or the menu bar's: false while something modal is over it.
  bool _saveFromKey() {
    if (!mounted || _closed || !(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    unawaited(save());
    return true;
  }

  /// Save, as the button does.
  Future<void> save() async {
    if (_saving || _closed || _asking || _committing) return;
    // Typing a field still holds is committed first; the holder's values (and [Inspector.changed]) follow
    // on the next frame.
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
      if (!mounted || _closed) return;
    }
    if (!widget.changed) return _close(false);
    final wrong = widget.check?.call() ?? const [];
    if (wrong.isNotEmpty) {
      setState(() => _failure = null);
      wrong.first.requestFocus();
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    final view = View.of(context);
    final direction = Directionality.of(context);
    unawaited(SemanticsService.sendAnnouncement(view, widget.savingAnnouncement, direction));
    String? failure;
    try {
      failure = await widget.onSave();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    if (failure == null) return _close(true);
    setState(() => _failure = failure);
    _saveNode.requestFocus();
    unawaited(SemanticsService.sendAnnouncement(view, failure, direction, assertiveness: Assertiveness.assertive));
  }

  /// Leave: asks "Discard changes?" first when there are changes. Completes with true when the inspector
  /// closed (the holder may go on: open the other record, change section), false when the user kept
  /// editing or a save is in progress.
  Future<bool> requestClose() async {
    if (_closed) return true;
    if (_saving || _asking || _committing) return false;
    if (widget.changed || _commits.hasPendingInput) {
      _asking = true;
      final discard = await showDiscardChangesDialog(context, message: widget.discardMessage);
      _asking = false;
      if (!discard || !mounted) return false;
    }
    _close(false);
    return true;
  }

  void _close(bool saved) {
    if (_closed) return;
    _closed = true;
    if (_inSheet) Navigator.of(context).pop();
    final opener = _opener;
    widget.onClosed(saved);
    // The holder moves focus to the record's row; if it did not, focus goes back to what opened it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = FocusManager.instance.primaryFocus;
      if ((now == null || now is FocusScopeNode) && opener != null && opener.context != null && opener.canRequestFocus) {
        opener.requestFocus();
      }
    });
  }

  static void _inert() {}

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final saveButton = SteadyWidthButton(
      label: Inspector.saveLabel,
      shown: _saving ? Inspector.savingLabel : Inspector.saveLabel,
      variant: ButtonVariant.filled,
      focusNode: _saveNode,
      onPressed: _saving ? _inert : () => unawaited(save()),
    );
    final action = widget.failureAction;
    final failure = _failure == null
        ? null
        : action == null
            ? Text(_failure!, style: MyDataType.body.copyWith(color: c.danger))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_failure!, style: MyDataType.body.copyWith(color: c.danger)),
                const SizedBox(height: MyDataSpace.s2),
                Button(label: action.label, onPressed: _saving ? _inert : action.onPressed),
              ]);
    final form = FormBusy(
      busy: _saving,
      child: Focus(focusNode: _bodyNode, child: FormCommit(scope: _commits, child: widget.form)),
    );

    if (_inSheet) {
      return Shortcuts(
        shortcuts: _saveShortcuts,
        child: Actions(
          actions: {_SaveIntent: CallbackAction<_SaveIntent>(onInvoke: (_) => save())},
          child: Sheet(
            kind: SheetKind.editor,
            title: widget.title,
            pending: widget.changed,
            discardMessage: widget.discardMessage,
            commits: _commits,
            busy: _saving,
            onCancel: () {
              _closed = true;
              widget.onClosed(false);
            },
            trailing: saveButton,
            body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (failure != null) ...[failure, const SizedBox(height: MyDataSpace.s4)],
              form,
            ]),
          ),
        ),
      );
    }

    final line = c.line;
    final none = c.line.withValues(alpha: 0);
    final panel = ColoredBox(
      color: c.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
              Inspector.padding, Inspector.headerTop, Inspector.padding, Inspector.headerBottom),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _hiddenAbove ? line : none))),
          child: Semantics(
            header: true,
            child: Text(widget.title,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: MyDataType.title.copyWith(color: c.ink)),
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
              return false;
            },
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(Inspector.padding, 0, Inspector.padding, Inspector.padding),
              child: form,
            ),
          ),
        ),
        if (failure != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Inspector.padding, MyDataSpace.s4, Inspector.padding, 0),
            child: failure,
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: Inspector.padding, vertical: Inspector.footerPadding),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: _hiddenBelow ? line : none))),
          child: ButtonRow(alignment: WrapAlignment.end, children: [
            Button(
              label: Inspector.cancelLabel,
              variant: ButtonVariant.plain,
              onPressed: _saving ? _inert : () => unawaited(requestClose()),
            ),
            saveButton,
          ]),
        ),
      ]),
    );

    return FocusTraversalGroup(
      child: Shortcuts(
        shortcuts: _saveShortcuts,
        child: Actions(
          actions: {
            _SaveIntent: CallbackAction<_SaveIntent>(onInvoke: (_) => save()),
            DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => requestClose()),
          },
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: widget.title,
            role: SemanticsRole.region,
            child: Material(type: MaterialType.transparency, child: panel),
          ),
        ),
      ),
    );
  }

  /// ⌘Return (Ctrl+Return) saves while focus is inside.
  static final _saveShortcuts = <ShortcutActivator, Intent>{
    const SingleActivator(LogicalKeyboardKey.enter, meta: true): const _SaveIntent(),
    const SingleActivator(LogicalKeyboardKey.enter, control: true): const _SaveIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter, meta: true): const _SaveIntent(),
    const SingleActivator(LogicalKeyboardKey.numpadEnter, control: true): const _SaveIntent(),
  };
}

/// The button under an [Inspector]'s failure line ([Inspector.failureAction]).
@immutable
class InspectorFailureAction {
  const InspectorFailureAction({required this.label, required this.onPressed});

  /// A verb, in sentence case: "Reload".
  final String label;
  final VoidCallback onPressed;
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

/// A group heading inside an [Inspector]'s form: the kind in the singular ("Phone", "Email"), in `label`
/// and `ink-muted`, `space-6` from the group before and `space-2` above its first field. It is FormGroup's
/// heading ([FormGroupHeading]), with no inset on the panel.
class InspectorGroupHeading extends StatelessWidget {
  const InspectorGroupHeading(this.text, {super.key, this.first = false});

  final String text;

  /// The first thing in the form: no space above.
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: first ? 0 : MyDataSpace.s6),
        child: Semantics(header: true, child: FormGroupHeading(text)),
      );
}

/// Places an [inspector] at the end edge of [content], from 600px (design/components/Inspector, "Where it
/// sits"):
///
/// - beside the content, `inspector-width` wide and the full height, the content narrowing to make room,
///   while the content left would be at least `inspector-width`;
/// - otherwise over the end of the content, lifted by `shadow-2`, the content keeping its width.
///
/// Setting [inspector] slides it in from the end edge over `slow` (`standard`), the content narrowing with
/// it; setting it to null slides it out over `base`. With reduced motion it fades over `fast` and the
/// content's width changes at once. The content keeps its state throughout.
///
/// Each opening gets its own inspector state: one set while the last is still sliding out, or one with
/// another key, starts afresh. Under a [ToastHost], toasts sit centred over the content, beside the
/// inspector.
class InspectorLayout extends StatefulWidget {
  const InspectorLayout({super.key, required this.content, this.inspector});

  final Widget content;

  /// Usually an [Inspector]; null when none is open.
  final Widget? inspector;

  /// Whether a window [width] wide fits the inspector beside the content (else it covers the content).
  static bool docksAt(double width) => width - MyDataSize.inspectorWidth >= MyDataSize.inspectorWidth;

  @override
  State<InspectorLayout> createState() => _InspectorLayoutState();
}

class _InspectorLayoutState extends State<InspectorLayout> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: MyDataMotion.slow, reverseDuration: MyDataMotion.base, value: widget.inspector == null ? 0 : 1);
  late final _curved = CurvedAnimation(parent: _c, curve: MyDataMotion.standard);
  Widget? _shown;

  /// Goes up with every opening, so each gets its own state.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _shown = widget.inspector;
    _c.addStatusListener((s) {
      if (s == AnimationStatus.dismissed && widget.inspector == null) setState(() => _shown = null);
    });
  }

  @override
  void didUpdateWidget(InspectorLayout old) {
    super.didUpdateWidget(old);
    final reduced = MyDataAccessibility.of(context).reduceMotion;
    _c.duration = reduced ? MyDataMotion.fast : MyDataMotion.slow;
    _c.reverseDuration = reduced ? MyDataMotion.fast : MyDataMotion.base;
    if (widget.inspector != null) {
      final reopened = old.inspector == null;
      final other = old.inspector != null &&
          (old.inspector!.key != widget.inspector!.key || old.inspector.runtimeType != widget.inspector.runtimeType);
      if (reopened || other) _generation++;
      _shown = widget.inspector;
      if (reopened) _c.forward();
    } else if (old.inspector != null) {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MyDataAccessibility.of(context).reduceMotion;
    const iw = MyDataSize.inspectorWidth;
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final docked = InspectorLayout.docksAt(w);
      return AnimatedBuilder(
        animation: _curved,
        builder: (context, _) {
          final t = _shown == null ? 0.0 : _curved.value;
          final open = widget.inspector != null;
          final double contentWidth;
          if (!docked || _shown == null) {
            contentWidth = w;
          } else {
            contentWidth = reduced ? (open ? w - iw : w) : w - iw * t;
          }
          Widget? panel;
          if (_shown != null) {
            final shown = KeyedSubtree(key: ValueKey(_generation), child: _shown!);
            panel = docked ? shown : DecoratedBox(
                decoration: BoxDecoration(boxShadow: context.shadows.shadow2), child: shown);
            if (reduced) panel = Opacity(opacity: t, child: panel);
          }
          // The part of the content the inspector leaves in view: a toast centres on it.
          final visibleWidth = docked || _shown == null ? contentWidth : (reduced ? (open ? w - iw : w) : w - iw * t);
          return Stack(clipBehavior: Clip.hardEdge, children: [
            PositionedDirectional(start: 0, top: 0, bottom: 0, width: contentWidth, child: widget.content),
            PositionedDirectional(start: 0, top: 0, bottom: 0, width: visibleWidth, child: const ToastArea()),
            if (panel != null)
              PositionedDirectional(
                end: reduced ? 0 : -iw * (1 - t),
                top: 0,
                bottom: 0,
                width: iw,
                child: panel,
              ),
          ]);
        },
      );
    });
  }
}
