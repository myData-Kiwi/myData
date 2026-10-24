part of 'contact_editor.dart';

/// The contact editor's form in the Mac frame, laid out as Contacts' card in edit mode (plan section 5,
/// "Person page": edit in place): the avatar beside the name fields (First name, Last name, Company, Job
/// title, their names as placeholders), then the values in the record page's two columns: the label column
/// holds each value's label as a borderless pop-up ("mobile ⌄") after its remove button, the value fields sit
/// beside it, and each kind ends with its Add button under the values (a green ⊕ and the label, evenly
/// spaced); every field ends at the same trailing edge. Birthday and Notes follow, as on the
/// page. Mac density throughout ([MacEditField], [MacPopUpButton], [MacRemoveButton]); the checks, host
/// errors, focus moves and announcements are the branded form's, the same ids and focus nodes.
extension _MacContactForm on _ContactEditorState {
  /// The label column grows by this in the editor: its labels are pop-ups with a chevron, after a remove
  /// button.
  static double _labelExtra(MyDataLook look) => look.space(8);

  /// Between the kinds of value, and between the rows of one kind and its Add button: one pitch, so the Add
  /// rows are evenly spaced whether their kind has values or not.
  static double _groupGap(MyDataLook look) => look.space(2);

  /// Between the rows of one kind.
  static double _rowGap(MyDataLook look) => look.space(2);

  Widget _macForm() {
    final d = _draft;
    final mac = context.mac;
    final formError = _checks.formError;
    Widget nameField(String id, String label, TextEditingController c, FocusNode node) => MacEditField(
      label: label,
      placeholder: label,
      controller: c,
      focusNode: node,
      error: _error(id),
      onChanged: (_) => _edited(id),
    );
    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: Avatar(name: d.shownName, givenName: d.given.text, familyName: d.family.text, size: AvatarSize.mac),
        ),
        SizedBox(width: MacRecordHeader.gap(context.look)),
        // The name fields end where the value fields end: one trailing edge for the whole form.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              nameField('given_name', 'First name', d.given, d.givenFocus),
              SizedBox(height: _rowGap(context.look)),
              nameField('family_name', 'Last name', d.family, d.familyFocus),
              SizedBox(height: _rowGap(context.look)),
              nameField('company', 'Company', d.company, d.companyFocus),
              SizedBox(height: _rowGap(context.look)),
              nameField('job_title', 'Job title', d.jobTitle, d.jobTitleFocus),
            ],
          ),
        ),
      ],
    );

    final note = MacEditorRow(
      extra: _labelExtra(context.look),
      label: MacEditorRow.text(context, ContactEditor.macNoteLabel),
      child: MacEditField.multiline(
        label: ContactEditor.notesHeading,
        controller: d.note,
        focusNode: d.noteFocus,
        placeholder: ContactEditor.notesPlaceholder,
        error: _error('note'),
        onChanged: (_) => _edited('note'),
      ),
    );

    final groups = <Widget>[
      _macGroup(ValueKind.phone),
      _macGroup(ValueKind.email),
      _macGroup(ValueKind.address),
      _macBirthday(),
      _macGroup(ValueKind.url),
      note,
    ];
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MacContactPage.maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (formError != null) ...[
              Focus(
                focusNode: _checks.formErrorFocus,
                skipTraversal: true,
                child: Semantics(
                  liveRegion: true,
                  label: formError,
                  child: ExcludeSemantics(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(context.icon(MyDataIcon.error), size: MyDataMacSize.icon, color: context.colors.danger),
                        SizedBox(width: context.space(2)),
                        Expanded(
                          child: Text(formError, style: context.macLook.callout.copyWith(color: context.colors.danger)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.space(4)),
            ],
            header,
            SizedBox(height: context.space(6)),
            Container(height: 1, color: mac.separator),
            SizedBox(height: context.space(4)),
            for (final (i, g) in groups.indexed) ...[if (i > 0) SizedBox(height: _groupGap(context.look)), g],
          ],
        ),
      ),
    );
  }

  /// One kind's rows and its Add button, read as a group named by the kind.
  Widget _macGroup(ValueKind kind) {
    final rows = _draft.rows[kind]!;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: kind.heading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) SizedBox(height: _rowGap(context.look)),
            KeyedSubtree(key: ValueKey(r.key), child: _macRow(kind, r, i)),
          ],
          if (rows.isNotEmpty) SizedBox(height: _rowGap(context.look)),
          MacEditorRow(
            extra: _labelExtra(context.look),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: MacAddButton(label: kind.addLabel, focusNode: _macAddFocus[kind], onPressed: () => _macAdd(kind)),
            ),
          ),
        ],
      ),
    );
  }

  void _macAdd(ValueKind kind) {
    final row = _draft.add(kind);
    _register();
    WidgetsBinding.instance.addPostFrameCallback((_) => row.focusFor(kind).requestFocus());
    _announce(kind.addedAnnouncement);
  }

  /// Removes [r]; focus goes to the next row's value, or the previous one's, or the Add button.
  void _macRemove(ValueKind kind, ValueRow r) {
    final rows = _draft.rows[kind]!;
    final at = rows.indexOf(r);
    final label = r.shownLabel(kind);
    _draft.remove(kind, r);
    for (final part in ['value', 'street']) {
      _hostErrors.remove(_ContactEditorState._rowId(kind, r, part));
    }
    _register();
    final next = at < rows.length ? rows[at] : (rows.isNotEmpty ? rows.last : null);
    final node = next?.focusFor(kind) ?? _macAddFocus[kind]!;
    WidgetsBinding.instance.addPostFrameCallback((_) => node.requestFocus());
    _announce('${kind.noun(label, capital: true)} removed');
  }

  void _announce(String message) =>
      unawaited(SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context)));

  /// A label as Contacts writes it: the presets in lower case ("mobile", "home page"), a custom one as typed.
  static String _shown(ValueKind kind, String label) => kind.presets.contains(label) ? label.toLowerCase() : label;

  Widget _macRow(ValueKind kind, ValueRow r, int index) {
    final shown = r.shownLabel(kind);
    final picker = MacPopUpButton<String>(
      label: kind.labelName(index),
      bordered: false,
      items: [for (final p in kind.presets) MacPopUpItem(value: p, title: _shown(kind, p))],
      value: shown,
      shown: _shown(kind, shown),
      onChanged: (v) => _draft.setLabel(r, v),
      onCustom: () => unawaited(_macCustomLabel(kind, r)),
    );
    final remove = MacRemoveButton(label: 'Remove ${kind.noun(shown)}', onPressed: () => _macRemove(kind, r));
    final Widget value;
    if (kind == ValueKind.address) {
      final id = _ContactEditorState._rowId(kind, r, 'street');
      Widget part(String placeholder, TextEditingController c, {FocusNode? node, String? error}) => MacEditField(
        label: '$shown, address, ${placeholder.toLowerCase()}',
        placeholder: placeholder,
        controller: c,
        focusNode: node,
        error: error,
        onChanged: (_) => _edited(id),
      );
      Widget pair(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          SizedBox(width: _rowGap(context.look)),
          Expanded(child: b),
        ],
      );
      value = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          part('Street', r.street, node: r.streetFocus, error: _error(id)),
          SizedBox(height: _rowGap(context.look)),
          pair(part('City', r.locality), part('Region', r.region)),
          SizedBox(height: _rowGap(context.look)),
          pair(part('Postcode', r.postalCode), part('Country', r.country)),
        ],
      );
    } else {
      final id = _ContactEditorState._rowId(kind, r);
      value = MacEditField(
        label: kind.valueName(shown),
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
      );
    }
    return MacEditorRow(extra: _labelExtra(context.look), leading: remove, label: picker, child: value);
  }

  /// "Custom label…": a Dialog with one field; the label is the row's once confirmed.
  Future<void> _macCustomLabel(ValueKind kind, ValueRow r) async {
    final current = r.shownLabel(kind);
    var label = kind.presets.contains(current) ? '' : current;
    final done = await showMyDataDialog(
      context: context,
      builder: (_) => _CustomLabelDialog(initial: label, onChanged: (v) => label = v),
    );
    if (done && label.trim().isNotEmpty && mounted) _draft.setLabel(r, label.trim());
  }

  Widget _macBirthday() {
    final label = MacEditorRow.text(context, ContactEditor.macBirthdayLabel);
    if (!_draft.hasBirthday) {
      return MacEditorRow(
        extra: _labelExtra(context.look),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: MacAddButton(
            label: ContactEditor.addBirthdayLabel,
            focusNode: _addBirthdayFocus,
            onPressed: () {
              _draft.addBirthday();
              _register();
              WidgetsBinding.instance.addPostFrameCallback((_) => _draft.birthdayFocus.requestFocus());
            },
          ),
        ),
      );
    }
    return MacEditorRow(
      extra: _labelExtra(context.look),
      leading: MacRemoveButton(
        label: ContactEditor.removeBirthdayLabel,
        onPressed: () {
          _draft.removeBirthday();
          _hostErrors.remove('birthday');
          _register();
          WidgetsBinding.instance.addPostFrameCallback((_) => _addBirthdayFocus.requestFocus());
        },
      ),
      label: label,
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: DatePicker.birthday(
          showLabel: false,
          compact: true,
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
    );
  }
}

/// The Mac form's "Custom label" Dialog: one field, its text reported as it changes. It owns the field's
/// controller, so the field outlives the call that opened it while the Dialog closes.
class _CustomLabelDialog extends StatefulWidget {
  const _CustomLabelDialog({required this.initial, required this.onChanged});

  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_CustomLabelDialog> createState() => _CustomLabelDialogState();
}

class _CustomLabelDialogState extends State<_CustomLabelDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MyDataDialog(
        title: ContactEditor.customLabelTitle,
        fields: [
          MacEditField(
            label: ContactEditor.customLabelField,
            placeholder: ContactEditor.customLabelField,
            controller: _text,
            onChanged: widget.onChanged,
          ),
        ],
        confirmLabel: ContactEditor.customLabelConfirm,
      );
}
