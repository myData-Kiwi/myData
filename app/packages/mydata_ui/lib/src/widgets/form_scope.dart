import 'package:flutter/widgets.dart';

// What a form's holder (a Dialog, an Inspector, a Sheet) tells its fields, and what the fields tell it back.

/// Whether the form around [context] is waiting for the host: a MyDataDialog or Inspector between the press of
/// its confirming button or Save and the host's answer.
///
/// While it is, nothing is disabled, so focus stays where it was: buttons are inert and fields are
/// read-only (design/components/Dialog and Inspector, "Working" and "Saving"). Every field reads
/// [FormBusy.of]: a text field takes no typing, a Select, DatePicker or TimePicker does not open or change,
/// and a Checkbox or Switch does not flip.
class FormBusy extends InheritedWidget {
  const FormBusy({super.key, required this.busy, required super.child});

  final bool busy;

  /// False outside any dialog or inspector.
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FormBusy>()?.busy ?? false;

  /// As [of], for an event handler: no rebuild when it changes.
  static bool read(BuildContext context) => context.getInheritedWidgetOfExactType<FormBusy>()?.busy ?? false;

  @override
  bool updateShouldNotify(FormBusy old) => old.busy != busy;
}

/// A field that holds typing of its own until it commits it, on Return or when focus leaves: a DatePicker's
/// or TimePicker's typed text, a TokenField's text that is not a token yet, a Select's custom label.
///
/// A form's holder commits it before it saves, confirms or leaves, so typing is never lost silently
/// ([FormCommit]).
abstract interface class PendingInput {
  /// Whether there is typing the field has not committed.
  bool get hasPendingInput;

  /// Commits the typing: true when it was right or there was none, false when the field now shows its error
  /// (the holder then stops and moves focus to [pendingInputFocus]).
  bool commitPendingInput();

  /// The field's focus.
  FocusNode get pendingInputFocus;
}

/// The [PendingInput] fields of one form, which a holder commits before it saves or confirms, and asks about
/// before it leaves (design/components/Inspector, Dialog and Sheet: typing is never lost silently).
class FormCommitScope {
  final _fields = <PendingInput>[];

  void register(PendingInput field) {
    if (!_fields.contains(field)) _fields.add(field);
  }

  void unregister(PendingInput field) => _fields.remove(field);

  /// Whether any field holds typing it has not committed: the holder asks "Discard changes?" before leaving.
  bool get hasPendingInput => _fields.any((f) => f.hasPendingInput);

  /// Commits every field's typing. [committed] is true when a field had any (its holder's values change on the
  /// next frame, so wait for it before reading them); [wrong] is the focus of the first field whose typing
  /// was wrong, or null.
  ({bool committed, FocusNode? wrong}) commitAll() {
    var committed = false;
    FocusNode? wrong;
    for (final f in [..._fields]) {
      if (!f.hasPendingInput) continue;
      committed = true;
      if (!f.commitPendingInput()) wrong ??= f.pendingInputFocus;
    }
    return (committed: committed, wrong: wrong);
  }
}

/// Gives the fields under it their holder's [FormCommitScope].
class FormCommit extends InheritedWidget {
  const FormCommit({super.key, required this.scope, required super.child});

  final FormCommitScope scope;

  static FormCommitScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FormCommit>()?.scope;

  @override
  bool updateShouldNotify(FormCommit old) => old.scope != scope;
}

/// Registers a field's [PendingInput] with the nearest [FormCommit] while it is in the tree.
mixin PendingInputRegistration<T extends StatefulWidget> on State<T> implements PendingInput {
  FormCommitScope? _commitScope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = FormCommit.maybeOf(context);
    if (scope == _commitScope) return;
    _commitScope?.unregister(this);
    _commitScope = scope?..register(this);
  }

  @override
  void dispose() {
    _commitScope?.unregister(this);
    _commitScope = null;
    super.dispose();
  }
}
