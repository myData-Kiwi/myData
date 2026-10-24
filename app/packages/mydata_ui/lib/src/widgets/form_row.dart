import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import '../theme/motion.dart';
import '../theme/theme.dart';
import 'app_frame.dart' show AppLayout;
import 'button.dart';
import 'icon_button.dart';
import 'pressable.dart';
import 'role_label.dart';

/// Where a form sits, which decides its ground and spacing (design/components/FormRow, "The form").
enum FormGround {
  /// In an Inspector, Sheet or Dialog: the groups straight on the panel, with no cards; fields `space-4`
  /// apart.
  panel,

  /// On a page's `bg` (a step of the import flow): each group a GroupedSection with one content part
  /// (`surface`, `radius-lg`, `shadow-1`, `space-5` padding, `space-4` under 600px), at most `content-max`
  /// wide; fields `space-5` apart.
  page;

  /// Between the fields of a group.
  double fieldGap(MyDataLook look) => this == panel ? look.space(4) : look.space(5);
}

/// One labelled field of an editing form (design/components/FormRow), for a control that has no label of
/// its own (a DatePicker, a Checkbox group, a custom control). MyDataTextField, MyDataSelect and
/// TokenField already lay out their label, help and error this way; use them as they are.
///
/// - **Labels are stacked, everywhere:** the [label] above the control in the `label` style and `ink`,
///   `space-2` above it, with no colon. [help] or [error] sit `space-2` under the control, starting where it
///   starts, in `caption`: `ink-muted`, or `danger` for the error, which replaces the help.
/// - A group that holds one field shows no label of its own ([label] null): the group's heading names it.
/// - Screen readers: the label names the control; the help or the error is its hint.
class FormRow extends StatelessWidget {
  const FormRow({super.key, required this.child, this.label, this.holdsName = false, this.help, this.error});

  /// A noun in sentence case with no full stop or colon ("First name", "Starts").
  final String? label;

  /// The [label] is a name and keeps its own case where the theme sets labels in upper case ([RoleLabel]).
  final bool holdsName;

  /// A full sentence with a full stop. Required fields say so here.
  final String? help;

  /// What is wrong and what a correct value looks like ("That email address is incomplete. It looks like
  /// name@example.org."). Replaces [help].
  final String? error;

  final Widget child;

  /// Spec: "`space-2` above it"; help and error `space-2` below.
  static double gap(MyDataLook look) => look.space(2);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final note = error ?? help;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          ExcludeSemantics(child: RoleLabel(label!, color: c.ink, holdsName: holdsName)),
          SizedBox(height: gap(context.look)),
        ],
        Semantics(label: label, hint: note, child: child),
        if (note != null) ...[
          SizedBox(height: gap(context.look)),
          ExcludeSemantics(
            child: Text(note, style: context.typeScale.caption.copyWith(color: error != null ? c.danger : c.inkMuted)),
          ),
        ],
      ],
    );
  }
}

/// An editing form: a column of [FormGroup]s, `space-6` apart, in the read-only view's order
/// (design/components/FormRow). Save and Cancel are not part of it: they belong to the Inspector, Sheet or
/// Dialog that holds it, which also asks "Discard changes?".
///
/// [error] is a rule about the form as a whole ("A contact needs a name, a company, a phone number or an
/// email."), shown once at the top of the first group after Save is pressed ([FormErrorMessage]).
class MyDataForm extends StatelessWidget {
  const MyDataForm({super.key, required this.groups, this.ground = FormGround.panel, this.error, this.errorFocusNode});

  final List<Widget> groups;
  final FormGround ground;

  /// The form-level error; null for none.
  final String? error;

  /// Lets [FormChecks] move focus to the message when it is the only error.
  final FocusNode? errorFocusNode;

  /// Spec: each group "`space-6` from the group before".
  static double groupGap(MyDataLook look) => look.space(6);

  @override
  Widget build(BuildContext context) {
    final form = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) SizedBox(height: groupGap(context.look)),
          if (i == 0 && error != null)
            _FormErrorScope(message: error!, focusNode: errorFocusNode, child: groups[i])
          else
            groups[i],
        ],
      ],
    );
    return _FormGroundScope(ground: ground, child: form);
  }
}

class _FormGroundScope extends InheritedWidget {
  const _FormGroundScope({required this.ground, required super.child});
  final FormGround ground;

  static FormGround of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FormGroundScope>()?.ground ?? FormGround.panel;

  @override
  bool updateShouldNotify(_FormGroundScope old) => old.ground != ground;
}

class _FormErrorScope extends InheritedWidget {
  const _FormErrorScope({required this.message, required this.focusNode, required super.child});
  final String message;
  final FocusNode? focusNode;

  static _FormErrorScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_FormErrorScope>();

  @override
  bool updateShouldNotify(_FormErrorScope old) => old.message != message || old.focusNode != focusNode;
}

/// One group of an editing form: its [heading] in the `label` style and `ink-muted` ("Phone", "When"), then
/// its fields (design/components/FormRow).
///
/// - In a [MyDataForm] on [FormGround.panel] (the default) the fields sit straight on the panel, `space-4`
///   apart; on [FormGround.page] the group is a GroupedSection content part, `space-5` apart.
/// - An editing form shows a group even when it is empty, holding only its Add button.
/// - Screen readers: the group is a group named by its heading.
class FormGroup extends StatelessWidget {
  const FormGroup({super.key, required this.heading, required this.children});

  /// The kind ("Phone", "When"), in sentence case.
  final String heading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ground = _FormGroundScope.of(context);
    final error = _FormErrorScope.of(context);
    final phone = AppLayout.of(context) == AppLayout.phone;
    Widget fields = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) FormErrorMessage(message: error.message, focusNode: error.focusNode),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: ground.fieldGap(context.look)),
          children[i],
        ],
      ],
    );
    if (ground == FormGround.page) {
      fields = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MyDataSize.contentMax),
        child: DecoratedBox(
          decoration:
              context.radius.decorate(BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg(context.look), boxShadow: context.shadows.shadow1)),
          child: Padding(padding: EdgeInsets.all(phone ? context.space(4) : context.space(5)), child: fields),
        ),
      );
    }
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: heading,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(child: FormGroupHeading(heading)),
          fields,
        ],
      ),
    );
  }
}

/// A form group's heading: the kind ("Phone", "When") in the `label` style and `ink-muted`, `space-2` above
/// the group's first field. On a page's `bg` ([FormGround.page], over a GroupedSection) it is inset
/// `space-2` from the start, as GroupedSection's heading; on a panel (an Inspector, Sheet or Dialog) and on a
/// phone it starts where the fields start (preview: `.gh{margin:0 0 8px 8px}`, `.panel .gh` and `.phone .gh`
/// `{margin:0 0 8px}`). [FormGroup], [InspectorGroupHeading] and the event editor's "When" use it.
class FormGroupHeading extends StatelessWidget {
  const FormGroupHeading(this.text, {super.key});

  final String text;

  /// Under the heading, above the first field.
  static double gap(MyDataLook look) => look.space(2);

  /// The inset on a page's `bg`.
  static double pageInset(MyDataLook look) => look.space(2);

  @override
  Widget build(BuildContext context) {
    final inset = _FormGroundScope.of(context) == FormGround.page && !AppLayout.isPhone(context);
    return Padding(
      padding: EdgeInsetsDirectional.only(start: inset ? pageInset(context.look) : 0, bottom: gap(context.look)),
      child: RoleLabel(text, color: context.colors.inkMuted),
    );
  }
}

/// A rule about the form as a whole, shown once at the top of the first group after Save is pressed: an
/// alert icon at `icon` size and the [message] in `caption` and `danger`, `space-2` apart, `space-4` above
/// the first field. It is focusable by script ([focusNode]), not a Tab stop, so focus can move to it when
/// it is the only error.
class FormErrorMessage extends StatelessWidget {
  const FormErrorMessage({super.key, required this.message, this.focusNode});
  final String message;
  final FocusNode? focusNode;

  /// Preview: `.ferr{gap:8px;margin-bottom:16px}`.
  static double gap(MyDataLook look) => look.space(2);
  static double bottom(MyDataLook look) => look.space(4);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom(context.look)),
      child: Focus(
        focusNode: focusNode,
        skipTraversal: true,
        child: Semantics(
          liveRegion: true,
          label: message,
          child: ExcludeSemantics(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(context.icon(MyDataIcon.error), size: context.density.icon, color: c.danger),
              SizedBox(width: gap(context.look)),
              Expanded(child: Text(message, style: context.typeScale.caption.copyWith(color: c.danger))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// One value of a kind that can have several (a phone number, an email, an address), in one line: the
/// [labelPicker] (a MyDataSelect with `showLabel: false` and `fitToItems: true`), the [value] field taking
/// the rest, and the remove button, `space-2` apart (design/components/FormRow, "A repeatable row").
///
/// - An address's value is several fields stacked `space-2` apart ([RepeatableFormRow.stacked]); the label
///   picker and the remove button stay on the first line.
/// - The remove button is the IconButton in its danger tone: a `control-height` circle, a minus-in-a-circle
///   icon in `danger`, `danger-soft` on hover, named and tooltipped by [removeLabel] ("Remove mobile
///   number"). It asks nothing: nothing is removed until Save.
/// - Tab order: the label picker, the value, the remove button.
class RepeatableFormRow extends StatelessWidget {
  const RepeatableFormRow({
    super.key,
    required this.labelPicker,
    required this.value,
    required this.removeLabel,
    required this.onRemove,
  });

  /// An address: several fields, stacked `space-2` apart, in the order the locale writes them.
  RepeatableFormRow.stacked({
    super.key,
    required this.labelPicker,
    required List<Widget> values,
    required this.removeLabel,
    required this.onRemove,
  }) : value = _StackedValues(values);

  final Widget labelPicker;
  final Widget value;

  /// Says which value it removes ("Remove work email").
  final String removeLabel;

  /// Null disables the remove button (a record that cannot be edited opens read-only instead).
  final VoidCallback? onRemove;

  /// Spec: "`space-2` apart".
  static double gap(MyDataLook look) => look.space(2);

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelPicker,
          SizedBox(width: gap(context.look)),
          Expanded(child: value),
          SizedBox(width: gap(context.look)),
          FormRemoveButton(label: removeLabel, onPressed: onRemove),
        ],
      );
}

/// An address's fields, stacked [RepeatableFormRow.gap] apart.
class _StackedValues extends StatelessWidget {
  const _StackedValues(this.values);

  final List<Widget> values;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) SizedBox(height: RepeatableFormRow.gap(context.look)),
            values[i],
          ],
        ],
      );
}

/// The remove button of a repeatable row: the [MyDataIconButton] in its danger tone, a `control-height`
/// circle with a minus-in-a-circle icon in `danger`, `danger-soft` on hover, its [label] as its accessible
/// name and tooltip (shown at once on keyboard focus, hidden by Escape). Its focus ring is `ink`
/// (design/README.md "Focus and danger").
class FormRemoveButton extends StatelessWidget {
  const FormRemoveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.disabledReason = defaultDisabledReason,
    this.focusNode,
  });
  final String label;
  final VoidCallback? onPressed;

  /// Why it cannot be pressed, while [onPressed] is null.
  final String disabledReason;
  final FocusNode? focusNode;

  static const defaultDisabledReason = 'This value cannot be removed here.';

  @override
  Widget build(BuildContext context) => MyDataIconButton(
        icon: MyDataIcon.remove,
        label: label,
        tone: IconButtonTone.danger,
        onPressed: onPressed,
        disabledReason: onPressed == null ? disabledReason : null,
        focusNode: focusNode,
      );
}

/// The repeatable rows of one kind and their Add button (design/components/FormRow): rows `space-3` apart,
/// the Add button (plain, with a plus icon: "Add phone") `space-3` under the last row, aligned with the
/// rows' start.
///
/// - [onAdd] adds a row (with [nextPresetLabel]); focus then moves to its value ([valueFocusOf]). A row
///   that is still empty on Save is dropped by the holder, never reported as an error.
/// - Removing closes the rows up and moves focus to the next row's value, or the previous one's, or the Add
///   button.
/// - Adding and removing are announced politely ([addedAnnouncement], [removedAnnouncement]).
/// - **Motion:** an added row opens from no height and fades in over `base` with the `standard` curve; a
///   removed row fades and closes over `base`. With reduced motion, rows appear and go with a `fast` fade
///   and the form jumps to its new height. Focus moves at once, not after the motion.
/// - Rows cannot be reordered: the order is the order the values were added.
class RepeatableFormGroup<K> extends StatefulWidget {
  const RepeatableFormGroup({
    super.key,
    required this.keys,
    required this.rowBuilder,
    required this.addLabel,
    required this.onAdd,
    required this.valueFocusOf,
    this.addedAnnouncement,
    this.removedAnnouncement,
    this.addFocusNode,
  });

  /// One per row, in order; a row keeps its key while it exists.
  final List<K> keys;

  /// Builds the row of [key]; its remove button calls the holder, which drops the key from [keys].
  final Widget Function(BuildContext context, K key, int index) rowBuilder;

  /// "Add phone", "Add email", "Add address".
  final String addLabel;
  final VoidCallback? onAdd;

  /// The value field's focus node of [key]'s row.
  final FocusNode? Function(K key) valueFocusOf;

  /// "Phone number added".
  final String? addedAnnouncement;

  /// "Mobile number removed", for the row of [key] that went.
  final String Function(K key)? removedAnnouncement;

  final FocusNode? addFocusNode;

  /// Spec: "Rows of one kind are `space-3` apart"; the Add button `space-3` under the last row.
  static double rowGap(MyDataLook look) => look.space(3);

  @override
  State<RepeatableFormGroup<K>> createState() => _RepeatableFormGroupState<K>();
}

class _RepRow<K> {
  _RepRow(this.key, this.controller);
  final K key;
  final AnimationController controller;
  Widget? last;
  bool leaving = false;
}

class _RepeatableFormGroupState<K> extends State<RepeatableFormGroup<K>> with TickerProviderStateMixin {
  final _rows = <_RepRow<K>>[];
  FocusNode? _ownAdd;
  FocusNode get _addFocus => widget.addFocusNode ?? (_ownAdd ??= FocusNode(debugLabel: 'RepeatableFormGroup add'));

  @override
  void initState() {
    super.initState();
    for (final k in widget.keys) {
      _rows.add(_RepRow(k, _controller()..value = 1));
    }
  }

  AnimationController _controller() =>
      AnimationController(vsync: this, duration: context.lookNow.motion.base, reverseDuration: context.lookNow.motion.base);

  @override
  void didUpdateWidget(RepeatableFormGroup<K> old) {
    super.didUpdateWidget(old);
    final now = widget.keys;
    final reduced = MyDataMotion.reduced(context);
    final duration = reduced ? context.motion.fast : context.motion.base;
    // Removed rows fade and close.
    String? removedMessage;
    K? removedKey;
    for (final r in _rows) {
      if (!r.leaving && !now.contains(r.key)) {
        r.leaving = true;
        removedKey = r.key;
        removedMessage = widget.removedAnnouncement?.call(r.key);
        r.controller.reverseDuration = duration;
        r.controller.reverse().whenComplete(() {
          if (!mounted) return;
          setState(() {
            _rows.remove(r);
            r.controller.dispose();
          });
        });
      }
    }
    // New rows open, in their place.
    K? added;
    for (var i = 0; i < now.length; i++) {
      final k = now[i];
      if (_rows.any((r) => r.key == k && !r.leaving)) continue;
      final r = _RepRow(k, _controller()..duration = duration);
      var at = 0, seen = 0;
      while (at < _rows.length && seen < i) {
        if (!_rows[at].leaving) seen++;
        at++;
      }
      _rows.insert(at, r);
      r.controller.forward(from: 0);
      added = k;
    }
    if (added != null) {
      final node = widget.valueFocusOf(added);
      WidgetsBinding.instance.addPostFrameCallback((_) => node?.requestFocus());
      if (widget.addedAnnouncement != null) _announce(widget.addedAnnouncement!);
    } else if (removedKey != null) {
      // Focus: the next row's value, or the previous one's, or the Add button.
      final oldIndex = old.keys.indexOf(removedKey);
      final next = oldIndex < now.length ? now[oldIndex] : (now.isNotEmpty ? now.last : null);
      final node = next == null ? _addFocus : (widget.valueFocusOf(next) ?? _addFocus);
      WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());
      if (removedMessage != null) _announce(removedMessage);
    }
  }

  void _announce(String message) =>
      SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context));

  @override
  void dispose() {
    for (final r in _rows) {
      r.controller.dispose();
    }
    _ownAdd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MyDataAccessibility.of(context).reduceMotion;
    final children = <Widget>[];
    var index = 0;
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      Widget row;
      if (r.leaving) {
        row = IgnorePointer(child: ExcludeFocus(child: ExcludeSemantics(child: r.last ?? const SizedBox.shrink())));
      } else {
        row = widget.rowBuilder(context, r.key, index++);
        r.last = row;
      }
      final curved = CurvedAnimation(parent: r.controller, curve: context.motion.standard);
      Widget item = Padding(
        padding: EdgeInsets.only(top: i == 0 ? 0 : RepeatableFormGroup.rowGap(context.look)),
        child: row,
      );
      item = FadeTransition(opacity: curved, child: item);
      // With reduced motion the rows only fade, and the form jumps to its new height. A row at rest is not
      // clipped, so its fields' focus rings (2px outside them) show whole. The tree keeps one shape
      // throughout, so the row's fields keep their state (and focus) when the motion ends.
      item = AnimatedBuilder(
        animation: curved,
        child: item,
        builder: (context, child) {
          final moving = !reduced && (r.leaving || r.controller.value < 1);
          return ClipRect(
            clipBehavior: moving ? Clip.hardEdge : Clip.none,
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: moving ? curved.value.clamp(0.0, 1.0) : 1,
              child: child,
            ),
          );
        },
      );
      if (reduced && r.leaving) item = const SizedBox.shrink();
      children.add(KeyedSubtree(key: ValueKey<Object?>(r.key), child: item));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...children,
        if (_rows.isNotEmpty) SizedBox(height: RepeatableFormGroup.rowGap(context.look)),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Button(
            label: widget.addLabel,
            onPressed: widget.onAdd,
            variant: ButtonVariant.plain,
            icon: MyDataIcon.add,
            focusNode: _addFocus,
          ),
        ),
      ],
    );
  }
}

/// The label a new repeatable row gets: the first of [presets] not yet in [used], then the last preset
/// again ("Mobile, Home, Work, Other, then Other again").
String nextPresetLabel(List<String> presets, Iterable<String> used) {
  final taken = used.map((u) => u.toLowerCase()).toSet();
  for (final p in presets) {
    if (!taken.contains(p.toLowerCase())) return p;
  }
  return presets.last;
}

/// The checks of one editing form (design/components/FormRow, "Validation").
///
/// - A field is checked when the user leaves it (its focus node loses focus) and when Save is pressed
///   ([save]), never while it is first being typed. Once it shows an error it is checked again on every
///   change ([changed]), and the error goes as soon as the value is right.
/// - [save] with errors saves nothing: focus moves to the first field in error (in registration order,
///   which is reading order), scrolled into view, or to the form's message ([formErrorFocus]) when the form
///   rule is the only error; screen readers hear "Not saved. 1 field needs attention." assertively. The
///   Save button is never disabled for errors.
/// - [formError] is the form-level rule's message, set only by [save]; show it with [MyDataForm.error].
class FormChecks extends ChangeNotifier {
  final _fields = <String, ({FocusNode node, String? Function() check})>{};
  final _errors = <String, String>{};
  String? _formError;

  /// Give it to [MyDataForm.errorFocusNode].
  final formErrorFocus = FocusNode(debugLabel: 'Form error', skipTraversal: true);

  final _listeners = <String, VoidCallback>{};

  /// Registers a field, in reading order. [check] returns the error for its current value, or null.
  void register(String id, {required FocusNode focusNode, required String? Function() check}) {
    unregister(id);
    _fields[id] = (node: focusNode, check: check);
    void left() {
      if (!focusNode.hasFocus) _run(id);
    }

    _listeners[id] = left;
    focusNode.addListener(left);
  }

  void unregister(String id) {
    final f = _fields.remove(id);
    final l = _listeners.remove(id);
    if (f != null && l != null) f.node.removeListener(l);
    if (_errors.remove(id) != null) notifyListeners();
  }

  /// The error [id] shows now, or null.
  String? errorOf(String id) => _errors[id];

  String? get formError => _formError;

  /// How many fields show an error.
  int get errorCount => _errors.length;

  /// Call on every change of [id]'s value: re-checks it only while it shows an error.
  void changed(String id) {
    if (_errors.containsKey(id)) _run(id);
  }

  bool _run(String id) {
    final f = _fields[id];
    if (f == null) return true;
    final e = f.check();
    final had = _errors[id];
    if (e == null) {
      _errors.remove(id);
    } else {
      _errors[id] = e;
    }
    if (had != e) notifyListeners();
    return e == null;
  }

  /// Checks every field and the form-level [formRule]. True when there is nothing wrong: the holder then
  /// saves. Otherwise focus moves to what needs attention and the result is announced.
  bool save(BuildContext context, {String? Function()? formRule}) {
    for (final id in _fields.keys) {
      _run(id);
    }
    final rule = formRule?.call();
    if (rule != _formError) {
      _formError = rule;
      notifyListeners();
    }
    if (_errors.isEmpty && rule == null) return true;
    final n = _errors.length + (rule == null ? 0 : 1);
    FocusNode? target;
    for (final e in _fields.entries) {
      if (_errors.containsKey(e.key)) {
        target = e.value.node;
        break;
      }
    }
    final to = target ?? formErrorFocus;
    // After the frame that shows the errors (the form's message may only now be in the tree).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      to.requestFocus();
      final ctx = to.context;
      if (ctx != null && ctx.mounted) Scrollable.ensureVisible(ctx, alignment: 0.1);
    });
    WidgetsBinding.instance.scheduleFrame();
    SemanticsService.sendAnnouncement(
      View.of(context),
      'Not saved. $n ${n == 1 ? 'field needs' : 'fields need'} attention.',
      Directionality.of(context),
      assertiveness: Assertiveness.assertive,
    );
    return false;
  }

  /// Clears every error (after Cancel, or a successful save).
  void reset() {
    _errors.clear();
    _formError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final id in [..._fields.keys]) {
      final f = _fields[id]!;
      f.node.removeListener(_listeners[id]!);
    }
    formErrorFocus.dispose();
    super.dispose();
  }
}
