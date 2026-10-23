import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'contact_form.dart';
import 'contacts_controller.dart';
import 'mac_contact_page.dart';

part 'contact_editor_mac.dart';

/// The contact editor: an [Inspector] ("New contact", "Edit contact") holding the contact's form
/// (design/components/Inspector and FormRow). From 600px it takes the contact pane's place; under 600px it
/// is the editor sheet ([showContactEditorSheet]).
///
/// - The form, straight on the panel: Name (First name, Last name, Company, Job title), then Phone, Email
///   and Address as repeatable rows with a label picker (Mobile, Home, Work, Other, Custom label…), Birthday
///   (the year optional), Links and Notes. Every group shows even when empty, holding its Add button.
/// - A field is checked when focus leaves it and when Save is pressed; the form-wide rule ("A contact needs
///   a name, a company, a phone number or an email.") only on Save. The host's field errors show on their
///   fields, in the app's words.
/// - Save sends the whole form with the etag the inspector opened on (If-Match). When the contact changed
///   elsewhere since, nothing is written: the failure line says so and offers Reload, which opens the host's
///   version and drops the user's changes. Nothing is ever overwritten.
class ContactEditor extends StatefulWidget {
  const ContactEditor({
    super.key,
    required this.edit,
    required this.onSave,
    required this.onClosed,
    required this.onReload,
    this.today,
  });

  /// The record and its inspector key.
  final ContactEdit edit;

  /// Sends the form; null when the host has it, else why not.
  final Future<WriteFailure?> Function(ContactIn form) onSave;

  /// The inspector closed: [saved] after a successful save.
  final void Function(bool saved) onClosed;

  /// Reload, after the host refused the save because the contact changed elsewhere: null when the host's
  /// version is open now, else why it could not be read.
  final Future<WriteFailure?> Function() onReload;

  /// The date the birthday's calendar opens on; null is today.
  final DateTime? today;

  static const newTitle = 'New contact';
  static const editTitle = 'Edit contact';
  static const newDiscard = 'This new contact is not saved.';
  static const reloadLabel = 'Reload';
  static const nameHeading = 'Name';
  static const birthdayHeading = 'Birthday';
  static const notesHeading = 'Notes';
  static const addBirthdayLabel = 'Add birthday';
  static const removeBirthdayLabel = 'Remove birthday';
  static const notesPlaceholder = 'Add notes';

  /// The Mac form's labels in the label column, in lower case as Contacts and the contact's page write them.
  static const macBirthdayLabel = 'birthday';
  static const macNoteLabel = 'note';

  /// "Custom label…" in the Mac form: a Dialog with one field.
  static const customLabelTitle = 'Custom label';
  static const customLabelField = 'Label';
  static const customLabelConfirm = 'Use label';

  /// The failure lines (design/components/Inspector, "Save failed"), for the contact called [name].
  static String noAnswer(String name) =>
      '$name could not be saved. The host did not answer. Your changes are still here; check that the host is '
      'running, then press Save again.';
  static String changedElsewhere(String name) =>
      '$name changed since you opened it, so nothing was saved. Your changes are still here. Reload shows the '
      'other change and drops yours.';
  static String gone(String name) =>
      '$name could not be saved. It is no longer on your host: it was deleted for good, or its source was '
      'turned off. Your changes are still here; copy what you need, then press Cancel.';
  static String reloadNoAnswer(String name) =>
      '$name could not be reloaded. The host did not answer. Your changes are still here; check that the host is '
      'running, then press Reload again.';
  static String refused(String name) =>
      '$name could not be saved. It is in Recently deleted now; restore it there, then edit it again.';
  static String fieldsWrong(String name, int n) =>
      '$name could not be saved. ${n == 1 ? 'One field needs' : '$n fields need'} attention; it is marked '
      'above.';

  @override
  State<ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends State<ContactEditor> {
  late final ContactDraft _draft = ContactDraft(widget.edit.original);
  final _checks = FormChecks();
  final _addBirthdayFocus = FocusNode(debugLabel: 'Add birthday');

  /// The Mac form's Add buttons, where focus goes when the last row of a kind is removed.
  final _macAddFocus = {for (final k in ValueKind.values) k: FocusNode(debugLabel: k.addLabel)};

  /// The host's field errors, by the form's field id, until that field changes.
  final _hostErrors = <String, String>{};

  /// The host refused the save because the contact changed elsewhere: Reload is offered.
  bool _stale = false;

  @override
  void initState() {
    super.initState();
    _draft.addListener(_changed);
    _checks.addListener(_changed);
    _register();
  }

  @override
  void dispose() {
    _draft.removeListener(_changed);
    _checks.dispose();
    _draft.dispose();
    _addBirthdayFocus.dispose();
    for (final n in _macAddFocus.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------------------------------------------
  // Checks: one id per field, registered in reading order.
  // ---------------------------------------------------------------------------------------------------

  static String _rowId(ValueKind kind, ValueRow row, [String part = 'value']) => '${kind.name}:${row.key}:$part';

  void _register() {
    for (final id in _registered) {
      _checks.unregister(id);
    }
    _registered.clear();
    void add(String id, FocusNode node, String? Function() check) {
      _checks.register(id, focusNode: node, check: () => check() ?? _hostErrors[id]);
      _registered.add(id);
    }

    add('given_name', _draft.givenFocus, () => null);
    add('family_name', _draft.familyFocus, () => null);
    add('company', _draft.companyFocus, () => null);
    add('job_title', _draft.jobTitleFocus, () => null);
    for (final kind in [ValueKind.phone, ValueKind.email, ValueKind.address]) {
      for (final r in _draft.rows[kind]!) {
        if (kind == ValueKind.address) {
          add(_rowId(kind, r, 'street'), r.streetFocus, () => null);
        } else {
          add(_rowId(kind, r), r.valueFocus, () => checkValue(kind, r.value.text));
        }
      }
    }
    if (_draft.hasBirthday) add('birthday', _draft.birthdayFocus, () => null);
    for (final r in _draft.rows[ValueKind.url]!) {
      add(_rowId(ValueKind.url, r), r.valueFocus, () => checkValue(ValueKind.url, r.value.text));
    }
    add('note', _draft.noteFocus, () => null);
  }

  final _registered = <String>[];

  /// A field's value changed: its host error goes, and it is checked again if it shows an error.
  void _edited(String id) {
    _hostErrors.remove(id);
    _checks.changed(id);
  }

  String? _error(String id) => _checks.errorOf(id) ?? _hostErrors[id];

  /// Inspector's check: nothing is sent while a field is wrong or the form-wide rule fails.
  List<FocusNode> _check() {
    if (_checks.save(context, formRule: _draft.formRule)) return const [];
    for (final id in _registered) {
      if (_checks.errorOf(id) != null) return [_focusOf(id)];
    }
    return [_checks.formErrorFocus];
  }

  FocusNode _focusOf(String id) {
    switch (id) {
      case 'given_name':
        return _draft.givenFocus;
      case 'family_name':
        return _draft.familyFocus;
      case 'company':
        return _draft.companyFocus;
      case 'job_title':
        return _draft.jobTitleFocus;
      case 'birthday':
        return _draft.birthdayFocus;
      case 'note':
        return _draft.noteFocus;
    }
    final parts = id.split(':');
    final kind = ValueKind.values.byName(parts[0]);
    final row = _draft.rows[kind]!.firstWhere((r) => '${r.key}' == parts[1]);
    return row.focusFor(kind);
  }

  // ---------------------------------------------------------------------------------------------------
  // Saving.
  // ---------------------------------------------------------------------------------------------------

  Future<String?> _save() async {
    setState(() {
      _stale = false;
      _hostErrors.clear();
    });
    final name = _draft.shownName;
    final failure = await widget.onSave(_draft.toContactIn());
    if (!mounted) return null;
    switch (failure) {
      case null:
        return null;
      case FieldErrors(:final fields):
        final mapped = _mapHostErrors(fields);
        setState(() => _hostErrors.addAll(mapped));
        if (mapped.isNotEmpty) {
          // After the inspector has put focus on Save: the first wrong field.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            for (final id in _registered) {
              if (_hostErrors.containsKey(id)) {
                _focusOf(id).requestFocus();
                break;
              }
            }
          });
        }
        return ContactEditor.fieldsWrong(name, mapped.isEmpty ? fields.length : mapped.length);
      case ChangedElsewhere():
        setState(() => _stale = true);
        return ContactEditor.changedElsewhere(name);
      case Gone():
        return ContactEditor.gone(name);
      case Refused():
        return ContactEditor.refused(name);
      case NoAnswer():
        return ContactEditor.noAnswer(name);
    }
  }

  /// Reload: the host's version opens in a new inspector; when it cannot be read, the failure line says why
  /// and what to do next (Reload stays only when trying again can help).
  Future<void> _reload() async {
    final name = _draft.shownName;
    final failure = await widget.onReload();
    if (!mounted || failure == null) return;
    final message = switch (failure) {
      Gone() => ContactEditor.gone(name),
      Refused() => ContactEditor.refused(name),
      _ => ContactEditor.reloadNoAnswer(name),
    };
    setState(() => _stale = failure is NoAnswer);
    widget.edit.inspector.currentState?.showFailure(message);
  }

  /// The host's errors ("phones[1].value") as the form's field ids, in the app's words.
  Map<String, String> _mapHostErrors(Map<String, String> fields) {
    final out = <String, String>{};
    final listPath = RegExp(r'^(phones|emails|urls|addresses)\[(\d+)\](?:\.(\w+))?$');
    for (final e in fields.entries) {
      final message = hostFieldError(e.key, e.value);
      if (const {'given_name', 'family_name', 'company', 'job_title', 'birthday', 'note'}.contains(e.key)) {
        out[e.key] = message;
        continue;
      }
      if (const {'middle_name', 'name_prefix', 'name_suffix', 'nickname', 'department'}.contains(e.key)) {
        out['given_name'] = message; // Not in the form: said on the name.
        continue;
      }
      final m = listPath.firstMatch(e.key);
      if (m == null) continue;
      final kind = ValueKind.values.firstWhere((k) => k.field == m.group(1));
      final rows = _draft.rows[kind]!;
      final i = int.parse(m.group(2)!);
      if (i >= rows.length) continue;
      final part = kind == ValueKind.address ? 'street' : 'value';
      out[_rowId(kind, rows[i], part)] = message;
    }
    return out;
  }

  // ---------------------------------------------------------------------------------------------------
  // The form.
  // ---------------------------------------------------------------------------------------------------

  Widget _text(String id, String label, TextEditingController c, FocusNode node) => MyDataTextField(
        label: label,
        controller: c,
        focusNode: node,
        error: _error(id),
        onChanged: (_) => _edited(id),
      );

  Widget _group(ValueKind kind) {
    final rows = _draft.rows[kind]!;
    return FormGroup(heading: kind.heading, children: [
      RepeatableFormGroup<int>(
        keys: [for (final r in rows) r.key],
        addLabel: kind.addLabel,
        addedAnnouncement: kind.addedAnnouncement,
        removedAnnouncement: (key) => '${kind.noun(_removedLabels[key] ?? '', capital: true)} removed',
        valueFocusOf: (key) => rows.where((r) => r.key == key).firstOrNull?.focusFor(kind),
        onAdd: () {
          _draft.add(kind);
          _register();
        },
        rowBuilder: (context, key, index) => _row(kind, rows.firstWhere((r) => r.key == key), index),
      ),
    ]);
  }

  /// The labels of removed rows, for their announcement.
  final _removedLabels = <int, String>{};

  Widget _row(ValueKind kind, ValueRow r, int index) {
    final picker = MyDataSelect<String>(
      label: kind.labelName(index),
      showLabel: false,
      fitToItems: true,
      items: [for (final p in kind.presets) SelectItem(value: p, title: p)],
      value: r.shownLabel(kind),
      titleOf: (v) => v,
      onChanged: (v) => _draft.setLabel(r, v),
      onCustomLabel: (v) {
        if (v.trim().isNotEmpty) _draft.setLabel(r, v.trim());
      },
    );
    void remove() {
      _removedLabels[r.key] = r.shownLabel(kind);
      _draft.remove(kind, r);
      for (final part in ['value', 'street']) {
        _hostErrors.remove(_rowId(kind, r, part));
      }
      _register();
    }

    final removeLabel = 'Remove ${kind.noun(r.shownLabel(kind))}';
    if (kind == ValueKind.address) {
      final id = _rowId(kind, r, 'street');
      Widget part(String placeholder, TextEditingController c, {FocusNode? node, String? error}) => MyDataTextField(
            label: '${r.shownLabel(kind)}, address, ${placeholder.toLowerCase()}',
            showLabel: false,
            placeholder: placeholder,
            controller: c,
            focusNode: node,
            error: error,
            onChanged: (_) => _edited(id),
          );
      return RepeatableFormRow.stacked(
        labelPicker: picker,
        values: [
          part('Street', r.street, node: r.streetFocus, error: _error(id)),
          part('City', r.locality),
          part('Region', r.region),
          part('Postcode', r.postalCode),
          part('Country', r.country),
        ],
        removeLabel: removeLabel,
        onRemove: remove,
      );
    }
    final id = _rowId(kind, r);
    return RepeatableFormRow(
      labelPicker: picker,
      value: MyDataTextField(
        label: kind.valueName(r.shownLabel(kind)),
        showLabel: false,
        controller: r.value,
        focusNode: r.valueFocus,
        error: _error(id),
        keyboardType: switch (kind) {
          ValueKind.phone => TextInputType.phone,
          ValueKind.email => TextInputType.emailAddress,
          ValueKind.url => TextInputType.url,
          ValueKind.address => TextInputType.text,
        },
        onChanged: (_) => _edited(id),
      ),
      removeLabel: removeLabel,
      onRemove: remove,
    );
  }

  Widget _birthday() {
    if (!_draft.hasBirthday) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: Button(
          label: ContactEditor.addBirthdayLabel,
          icon: Icons.add_rounded,
          variant: ButtonVariant.plain,
          focusNode: _addBirthdayFocus,
          onPressed: () {
            _draft.addBirthday();
            _register();
            WidgetsBinding.instance.addPostFrameCallback((_) => _draft.birthdayFocus.requestFocus());
          },
        ),
      );
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: DatePicker.birthday(
          showLabel: false,
          value: _draft.birthday,
          onChanged: (b) {
            _draft.setBirthday(b);
            _edited('birthday');
          },
          today: widget.today ?? DateTime.now(),
          focusNode: _draft.birthdayFocus,
          error: _hostErrors['birthday'],
        ),
      ),
      const SizedBox(width: RepeatableFormRow.gap),
      FormRemoveButton(
        label: ContactEditor.removeBirthdayLabel,
        onPressed: () {
          _draft.removeBirthday();
          _hostErrors.remove('birthday');
          _register();
          WidgetsBinding.instance.addPostFrameCallback((_) => _addBirthdayFocus.requestFocus());
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final d = _draft;
    final form = MacLook.of(context) ? _macForm() : MyDataForm(
      error: _checks.formError,
      errorFocusNode: _checks.formErrorFocus,
      groups: [
        FormGroup(heading: ContactEditor.nameHeading, children: [
          _text('given_name', 'First name', d.given, d.givenFocus),
          _text('family_name', 'Last name', d.family, d.familyFocus),
          _text('company', 'Company', d.company, d.companyFocus),
          _text('job_title', 'Job title', d.jobTitle, d.jobTitleFocus),
        ]),
        _group(ValueKind.phone),
        _group(ValueKind.email),
        _group(ValueKind.address),
        FormGroup(heading: ContactEditor.birthdayHeading, children: [_birthday()]),
        _group(ValueKind.url),
        FormGroup(heading: ContactEditor.notesHeading, children: [
          MyDataTextField.multiline(
            label: ContactEditor.notesHeading,
            showLabel: false,
            controller: d.note,
            focusNode: d.noteFocus,
            placeholder: ContactEditor.notesPlaceholder,
            error: _error('note'),
            onChanged: (_) => _edited('note'),
          ),
        ]),
      ],
    );
    final original = widget.edit.original;
    return Inspector(
      key: widget.edit.inspector,
      title: original == null ? ContactEditor.newTitle : ContactEditor.editTitle,
      form: form,
      changed: d.changed,
      check: _check,
      onSave: _save,
      onClosed: widget.onClosed,
      discardMessage:
          original == null ? ContactEditor.newDiscard : 'Your changes to ${original.displayName} are not saved.',
      savingAnnouncement: 'Saving ${d.shownName}',
      failureAction: _stale
          ? InspectorFailureAction(label: ContactEditor.reloadLabel, onPressed: () => unawaited(_reload()))
          : null,
    );
  }
}
