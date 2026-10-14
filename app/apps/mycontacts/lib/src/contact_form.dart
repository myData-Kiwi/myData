import 'package:flutter/widgets.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// The kinds of value a contact can have several of, in the form's order (FieldRow's: Phone, Email,
/// Address, then Links after Birthday).
enum ValueKind {
  phone('Phone', 'Add phone', 'phones', ['Mobile', 'Home', 'Work', 'Other']),
  email('Email', 'Add email', 'emails', ['Home', 'Work', 'Other']),
  address('Address', 'Add address', 'addresses', ['Home', 'Work', 'Other']),
  url('Links', 'Add link', 'urls', ['Home page', 'Home', 'Work', 'Other']);

  const ValueKind(this.heading, this.addLabel, this.field, this.presets);

  /// The group's heading, as on the contact's page.
  final String heading;

  /// "Add phone".
  final String addLabel;

  /// The host's name for the list ("phones"), which its field errors start with.
  final String field;

  /// The labels a new row takes in turn, and the label picker's items before "Custom label…".
  final List<String> presets;

  /// The value's name in a sentence: "Mobile number", "work email", "home address", "work link".
  String noun(String label, {bool capital = false}) {
    final l = label.trim().isEmpty ? 'Other' : label.trim();
    final what = switch (this) {
      phone => 'number',
      email => 'email',
      address => 'address',
      url => 'link',
    };
    final text = '${capital ? l : l.toLowerCase()} $what';
    return capital ? text[0].toUpperCase() + text.substring(1) : text;
  }

  /// Screen readers: "Phone number added".
  String get addedAnnouncement => switch (this) {
        phone => 'Phone number added',
        email => 'Email address added',
        address => 'Address added',
        url => 'Link added',
      };

  /// The accessible name of a row's value ("Mobile, phone number").
  String valueName(String label) => switch (this) {
        phone => '$label, phone number',
        email => '$label, email address',
        address => '$label, address',
        url => '$label, link',
      };

  /// The accessible name of a row's label picker ("Label for phone 1").
  String labelName(int index) => switch (this) {
        phone => 'Label for phone ${index + 1}',
        email => 'Label for email ${index + 1}',
        address => 'Label for address ${index + 1}',
        url => 'Label for link ${index + 1}',
      };
}

/// One value of a [ValueKind] in the form: its label and its text (an address has five parts).
class ValueRow {
  ValueRow(this.key, this.label, {String value = '', PostalAddress? address})
    : value = TextEditingController(text: value),
      street = TextEditingController(text: address?.street ?? ''),
      locality = TextEditingController(text: address?.locality ?? ''),
      region = TextEditingController(text: address?.region ?? ''),
      postalCode = TextEditingController(text: address?.postalCode ?? ''),
      country = TextEditingController(text: address?.country ?? '');

  /// Stays the row's while it exists, so a removed row's neighbours keep their state.
  final int key;

  /// The label as loaded or picked. A value loaded without one keeps it empty, so saving sends it back
  /// unchanged and the host does not add one; [shownLabel] is what the picker shows.
  String label;

  /// The label on screen: [label], or the kind's last preset ("Other") for a value without one.
  String shownLabel(ValueKind kind) => label.trim().isEmpty ? kind.presets.last : label;
  final TextEditingController value;
  final TextEditingController street;
  final TextEditingController locality;
  final TextEditingController region;
  final TextEditingController postalCode;
  final TextEditingController country;
  final valueFocus = FocusNode(debugLabel: 'value');
  final streetFocus = FocusNode(debugLabel: 'street');

  /// The address's parts, in the order this form lays them out.
  List<TextEditingController> get addressParts => [street, locality, region, postalCode, country];

  /// The value's first field: where focus goes when the row is added.
  FocusNode focusFor(ValueKind kind) => kind == ValueKind.address ? streetFocus : valueFocus;

  bool isEmptyFor(ValueKind kind) => kind == ValueKind.address
      ? addressParts.every((c) => c.text.trim().isEmpty)
      : value.text.trim().isEmpty;

  void dispose() {
    for (final c in [value, ...addressParts]) {
      c.dispose();
    }
    valueFocus.dispose();
    streetFocus.dispose();
  }
}

/// What the contact editor holds: every value of the form, what was loaded, and the checks
/// (design/components/FormRow, design/components/Inspector).
///
/// - The form shows First name, Last name, Company and Job title, then Phone, Email, Address (repeatable
///   rows with a label picker), Birthday (year optional), Links and Notes. The card's middle name, prefix,
///   suffix, nickname and department are not in the form; they are sent back as loaded, so nothing is lost.
/// - [changed] compares what would be sent with what was loaded, so typing and deleting back, or adding a
///   row and leaving it empty, is no change.
/// - [toContactIn] sends the whole form, empty rows included, so the host's field errors ("phones[1].value")
///   name the rows by their place; the host drops the empty ones.
class ContactDraft extends ChangeNotifier {
  ContactDraft(this.original) {
    final c = original;
    given.text = c?.givenName ?? '';
    family.text = c?.familyName ?? '';
    company.text = c?.company ?? '';
    jobTitle.text = c?.jobTitle ?? '';
    note.text = c?.note ?? '';
    if (c != null) {
      for (final p in c.phones) {
        rows[ValueKind.phone]!.add(ValueRow(_next++, p.label, value: p.value));
      }
      for (final e in c.emails) {
        rows[ValueKind.email]!.add(ValueRow(_next++, e.label, value: e.value));
      }
      for (final a in c.addresses) {
        rows[ValueKind.address]!.add(ValueRow(_next++, a.label, address: a));
      }
      for (final u in c.urls) {
        rows[ValueKind.url]!.add(ValueRow(_next++, u.label, value: u.value));
      }
      birthday = c.birthday == null ? null : Birthday.parse(c.birthday!);
      hasBirthday = birthday != null;
    }
    for (final t in _texts) {
      t.addListener(notifyListeners);
    }
    for (final list in rows.values) {
      list.forEach(_listen);
    }
    _loaded = _snapshot();
  }

  /// The contact being edited; null for a new one.
  final ContactDetailOut? original;

  final given = TextEditingController();
  final family = TextEditingController();
  final company = TextEditingController();
  final jobTitle = TextEditingController();
  final note = TextEditingController();
  final givenFocus = FocusNode(debugLabel: 'First name');
  final familyFocus = FocusNode(debugLabel: 'Last name');
  final companyFocus = FocusNode(debugLabel: 'Company');
  final jobTitleFocus = FocusNode(debugLabel: 'Job title');
  final noteFocus = FocusNode(debugLabel: 'Notes');
  final birthdayFocus = FocusNode(debugLabel: 'Birthday');

  final rows = {for (final k in ValueKind.values) k: <ValueRow>[]};

  /// The birthday's row is shown (it may still be empty); [birthday] is its value.
  bool hasBirthday = false;
  Birthday? birthday;

  int _next = 0;
  late String _loaded;

  List<TextEditingController> get _texts => [given, family, company, jobTitle, note];

  bool get isNew => original == null;

  /// Any value differs from the one loaded.
  bool get changed => _snapshot() != _loaded;

  /// The name the form would give the contact now, for the inspector's messages: "Ava Fictional", or the
  /// company, or the loaded name, or "This contact".
  String get shownName {
    final name = [given.text.trim(), family.text.trim()].where((p) => p.isNotEmpty).join(' ');
    if (name.isNotEmpty) return name;
    if (company.text.trim().isNotEmpty) return company.text.trim();
    return original?.displayName ?? 'The new contact';
  }

  /// Adds a row of [kind] with the next preset label not yet used.
  ValueRow add(ValueKind kind) {
    final list = rows[kind]!;
    final row = ValueRow(_next++, nextPresetLabel(kind.presets, list.map((r) => r.shownLabel(kind))));
    _listen(row);
    list.add(row);
    notifyListeners();
    return row;
  }

  /// Removes [row]; nothing is removed on the host until Save.
  void remove(ValueKind kind, ValueRow row) {
    rows[kind]!.remove(row);
    // Its fields stay on screen while the row fades out: disposed with the form.
    _removed.add(row);
    notifyListeners();
  }

  final _removed = <ValueRow>[];

  void _listen(ValueRow row) {
    for (final c in [row.value, ...row.addressParts]) {
      c.addListener(notifyListeners);
    }
  }

  void setLabel(ValueRow row, String label) {
    row.label = label;
    notifyListeners();
  }

  void addBirthday() {
    hasBirthday = true;
    notifyListeners();
  }

  void setBirthday(Birthday value) {
    birthday = value;
    notifyListeners();
  }

  void removeBirthday() {
    hasBirthday = false;
    birthday = null;
    notifyListeners();
  }

  /// The form as the host takes it: every field, the ones not in the form as loaded.
  ContactIn toContactIn() {
    final c = original;
    String text(TextEditingController t) => t.text.trim();
    List<LabeledValueIn> values(ValueKind kind) => [
          for (final r in rows[kind]!) LabeledValueIn(label: r.label, value: r.value.text.trim()),
        ];
    return ContactIn(
      givenName: text(given),
      familyName: text(family),
      middleName: c?.middleName ?? '',
      namePrefix: c?.namePrefix ?? '',
      nameSuffix: c?.nameSuffix ?? '',
      nickname: c?.nickname ?? '',
      company: text(company),
      department: c?.department ?? '',
      jobTitle: text(jobTitle),
      phones: values(ValueKind.phone),
      emails: values(ValueKind.email),
      urls: values(ValueKind.url),
      addresses: [
        for (final r in rows[ValueKind.address]!)
          PostalAddressIn(
            label: r.label,
            street: r.street.text.trim(),
            locality: r.locality.text.trim(),
            region: r.region.text.trim(),
            postalCode: r.postalCode.text.trim(),
            country: r.country.text.trim(),
          ),
      ],
      birthday: hasBirthday ? (birthday?.toHostString() ?? '') : '',
      note: note.text.trim(),
    );
  }

  /// What [changed] compares: the form without its empty rows.
  String _snapshot() {
    final f = toContactIn();
    String vs(List<LabeledValueIn>? l) =>
        [for (final v in l ?? const <LabeledValueIn>[]) if ((v.value ?? '').isNotEmpty) '${v.label}\u0001${v.value}']
            .join('\u0002');
    final addresses = [
      for (final a in f.addresses ?? const <PostalAddressIn>[])
        if ([a.street, a.locality, a.region, a.postalCode, a.country].any((p) => (p ?? '').isNotEmpty))
          [a.label, a.street, a.locality, a.region, a.postalCode, a.country].join('\u0001'),
    ].join('\u0002');
    return [
      f.givenName, f.familyName, f.company, f.jobTitle, f.note, f.birthday, //
      vs(f.phones), vs(f.emails), vs(f.urls), addresses,
    ].join('\u0003');
  }

  /// The form-wide rule (FormRow): a contact needs a name, a company, a phone number or an email. A
  /// nickname kept from the card counts too, as the host counts it.
  String? formRule() {
    final f = toContactIn();
    bool any(List<LabeledValueIn>? l) => (l ?? const []).any((v) => (v.value ?? '').isNotEmpty);
    final has = [f.givenName, f.familyName, f.middleName, f.namePrefix, f.nameSuffix, f.nickname, f.company]
            .any((v) => (v ?? '').isNotEmpty) ||
        any(f.phones) ||
        any(f.emails);
    return has ? null : formRuleText;
  }

  static const formRuleText = 'A contact needs a name, a company, a phone number or an email.';

  @override
  void dispose() {
    for (final t in _texts) {
      t.dispose();
    }
    for (final n in [givenFocus, familyFocus, companyFocus, jobTitleFocus, noteFocus, birthdayFocus]) {
      n.dispose();
    }
    for (final r in [...rows.values.expand((l) => l), ..._removed]) {
      r.dispose();
    }
    super.dispose();
  }
}

/// The app's checks of one value, as the host checks it, in the words FormRow asks for: what is wrong and
/// what a right value looks like. Null when it is right (an empty value is always right: the row is dropped).
String? checkValue(ValueKind kind, String text) {
  final v = text.trim();
  if (v.isEmpty) return null;
  switch (kind) {
    case ValueKind.email:
      return _email.hasMatch(v) ? null : emailError;
    case ValueKind.phone:
      final digits = v.replaceAll(RegExp(r'\D'), '').length;
      return _phone.hasMatch(v) && digits >= 2 ? null : phoneError;
    case ValueKind.url:
      return RegExp(r'\s').hasMatch(v) ? urlError : null;
    case ValueKind.address:
      return null;
  }
}

// As the host's contact_form: one @, a dot in the part after it, no spaces or list separators.
final _email = RegExp(r'^[^@\s,;<>"]+@[^@\s,;<>"]+\.[^@\s,;<>".]+$');
final _phone = RegExp(r'^[0-9+().\-/#*,;pPwWxXeEtT  ]+$');

const emailError = 'That email address is incomplete. It looks like name@example.org.';
const phoneError = 'That is not a phone number. Use digits, spaces and + ( ) -, like +1 555 0142.';
const urlError = 'A link cannot hold spaces. It looks like example.org/ava.';

/// The app's sentence for a field error the host gave ([hostPath] as the host names the field), in the
/// app's words where the app knows the rule.
String hostFieldError(String hostPath, String hostMessage) {
  if (hostPath.startsWith('emails[') && hostPath.endsWith('.value')) return emailError;
  if (hostPath.startsWith('phones[') && hostPath.endsWith('.value')) return phoneError;
  if (hostPath.startsWith('urls[') && hostPath.endsWith('.value')) return urlError;
  if (hostPath == 'birthday') return 'That is not a date. Choose one from the calendar.';
  if (hostMessage.startsWith('Too long')) return 'That is too long. Keep it shorter.';
  if (hostMessage.startsWith('Give a name')) return ContactDraft.formRuleText;
  return 'The host could not keep this value. Change it, then press Save again.';
}
