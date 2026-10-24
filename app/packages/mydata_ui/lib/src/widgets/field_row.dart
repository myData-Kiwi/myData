import 'package:flutter/gestures.dart' show PointerDeviceKind, PointerDownEvent;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import 'group_frame.dart';
import 'grouped_list.dart';
import 'icon_button.dart';
import 'pressable.dart';

/// What kind of value a [FieldRow] shows. The order is the order of the groups on a contact's page
/// ([FieldGroups]): Phone, Email, Address, Birthday, Links, Notes.
enum FieldKind {
  /// A phone number. Plain text: it opens nothing until a phone app exists.
  phone('Phone', 'phone number', 'number', {'number', 'phone', 'fax', 'pager'}),

  /// An email address. Plain text: it opens nothing until myMail exists.
  email('Email', 'email', 'email', {'email', 'e-mail', 'mail'}),

  /// A postal address, its lines in the order the locale writes them, separated by line breaks.
  address('Address', 'address', 'address', {'address'}),

  /// A birthday, already written out ([formatBirthday]). It has no label.
  birthday('Birthday', 'birthday', 'birthday', {'birthday'}),

  /// A web address. It is a link only when [safeWebLink] says so; otherwise plain text.
  link('Links', 'link', 'link', {'link', 'website', 'site', 'url', 'homepage', 'home page', 'blog', 'profile'}),

  /// A note, keeping its line breaks. It has no label.
  note('Notes', 'notes', 'notes', {'note', 'notes'});

  const FieldKind(this.heading, this._bareNoun, this._noun, this._ownNames);

  /// The heading of this kind's group on a contact's page, in sentence case.
  final String heading;

  // What the copy button copies when the value has no label ("Copy phone number").
  final String _bareNoun;

  // What follows a label in the copy button's name ("Copy mobile number").
  final String _noun;

  // Labels that already name the thing, so no noun follows them ("Copy website", not "Copy website link").
  final Set<String> _ownNames;
}

/// Shows a link: called with the address to open in the default browser, never inside the app. On macOS an
/// app passes `(url) => macSystem.open('$url')` from mydata_core.
typedef LinkOpener = void Function(Uri url);

/// A [GroupedList]-style row that shows one labelled value from a record, such as a phone number, and
/// copies it (design/components/FieldRow).
///
/// - At least `row-height` tall, padded `space-4` across and `space-2` down, with no icon tile.
/// - The [label] sits above the value in `caption` and `ink-muted`, exactly as the source wrote it
///   ("Mobile", or a custom label). Null or empty: no label line (a birthday, a note).
/// - The [value] is in `body` and `ink`, selectable with the pointer, and wraps; line breaks are kept, so an
///   address keeps its lines and a note its paragraphs. A word longer than the line breaks anywhere.
/// - **Links.** Only a [FieldKind.link] value can be a link, and only when [safeWebLink] accepts it (an
///   `http` or `https` address, or a bare host name with a dot, which opens with `https://` added). It is
///   then `accent` and underlined, shown exactly as written, and opens through [onOpenLink]. Any other
///   value, and any link when [onOpenLink] is null, is plain text: still readable, selectable and copyable.
///   The link's target is the label and the value together, at least `control-height` tall, so it meets the
///   44px rule without making the row taller; it is a Tab stop with the focus ring, and Enter opens it.
///   A link is not selectable; the copy button copies it.
/// - At the right end, `space-3` from the text, a plain icon button `control-height` square copies the
///   value exactly as written: a copy icon in `ink-muted`, `surface-hover` on hover. Its accessible name
///   and tooltip are [copyName] (by default from the kind and the label: "Copy mobile number"). After
///   copying, the icon becomes a check, the tooltip reads [copiedLabel], screen readers hear
///   [copiedLabel], and it stays so until another FieldRow copies something or the value changes.
/// - Right-click, or a long press on a touch screen, anywhere on the row, the value included, offers Copy,
///   which does what the button does: it copies the whole value and sets Copied. On the value, the value is
///   shown selected while that menu is open. Only when the user has selected part of the value themselves
///   (by dragging, a double-click, or moving the handles) does a right-click on it show the platform's
///   text menu, whose Copy copies that selection. Escape closes either menu.
/// - The row has no hover fill: the copy button is its target.
/// - Put rows in a [FieldGroup], or let [FieldGroups] lay out a contact's page.
class FieldRow extends StatefulWidget {
  const FieldRow({super.key, required this.kind, this.label, required this.value, this.onOpenLink, this.copyName});

  /// What kind of value this is. It decides the group, the copy button's name, and whether the value may
  /// be a link at all.
  final FieldKind kind;

  /// The label the source gives, exactly as written; null or empty for none.
  final String? label;

  /// The value, exactly as the source wrote it; line breaks separate an address's lines.
  final String value;

  /// Opens a link in the default browser. Null: a web address is shown as plain text.
  final LinkOpener? onOpenLink;

  /// The copy button's accessible name and tooltip. Null: [copyNameFor] the kind and the label.
  final String? copyName;

  /// The tooltip after copying, and what screen readers hear.
  static const copiedLabel = 'Copied';

  /// The context menu's one item.
  static const copyMenuLabel = 'Copy';

  /// Preview: `.r{padding:8px 16px}`; the same as a [GroupedRow].
  static EdgeInsets padding(MyDataLook look) => GroupedRow.padding(look);

  /// Between the text and the copy button (preview: `gap:12px`).
  static double gap(MyDataLook look) => GroupedRow.gap(look);

  /// The copy button's name for a value of [kind] with [label]: "Copy" and what it copies. A label whose
  /// last word already names the thing is used alone ("Copy website", "Copy work fax"); otherwise the
  /// kind's noun follows it ("Copy mobile number", "Copy home address", "Copy Apple Watch number").
  ///
  /// Only the host's own sentence-case labels ([builtInLabels]: "Mobile", "Home fax", "Website") are
  /// lower-cased to sit inside the sentence. Every other label, a custom one or a name such as "iPhone",
  /// "Apple Watch" or "Skype", is used exactly as written.
  static String copyNameFor(FieldKind kind, String? label) {
    final l = (label ?? '').trim();
    if (l.isEmpty || kind == FieldKind.birthday || kind == FieldKind.note) return 'Copy ${kind._bareNoun}';
    final named = builtInLabels.contains(l) ? l.toLowerCase() : l;
    final lower = l.toLowerCase();
    if (kind._ownNames.any((name) => lower == name || lower.endsWith(' $name'))) return 'Copy $named';
    return 'Copy $named ${kind._noun}';
  }

  /// The labels the host writes in sentence case for the sources' built-in ones
  /// (host/src/mydata/sources/views.py `_LABELS`), plus "Website", the usual label of a link. They are
  /// common words, so [copyNameFor] lower-cases them. "iPhone" and "Apple Watch" are names and keep
  /// their capitals.
  static const builtInLabels = {
    'Mobile', 'Home', 'Work', 'Other', 'Main', 'Fax', 'Home fax', 'Work fax', 'Other fax', 'Pager', //
    'School', 'Home page', 'Website',
  };

  @override
  State<FieldRow> createState() => _FieldRowState();
}

/// The row whose value was copied last, so only that one says Copied.
final ValueNotifier<Object?> _lastCopied = ValueNotifier<Object?>(null);

class _FieldRowState extends State<FieldRow> {
  // Stands for this row's current value in [_lastCopied]; replaced when the value changes.
  Object _token = Object();
  final _menu = ContextMenuController();
  // Holds focus while the row's menu is open, so Escape reaches it.
  final _menuFocus = FocusNode(debugLabel: 'FieldRow menu');
  FocusNode? _focusBeforeMenu;
  // Reached by pointer, not by Tab: the copy button (and a link) are the keyboard's targets.
  final _valueFocus = FocusNode(debugLabel: 'FieldRow value', skipTraversal: true);

  // The selection the current gesture on the value made by itself (the word a right-click or a long press
  // selects), as opposed to one the user made. Reset at every pointer down on the value; the gesture's
  // first change, if it comes from a tap or a long press, sets it.
  TextSelection? _gestureSelection;
  bool _freshGesture = false;

  bool get _copied => identical(_lastCopied.value, _token);

  @override
  void initState() {
    super.initState();
    _lastCopied.addListener(_changed);
  }

  @override
  void didUpdateWidget(FieldRow old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _token = Object();
  }

  @override
  void dispose() {
    _lastCopied.removeListener(_changed);
    _menu.remove();
    _menuFocus.dispose();
    _valueFocus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    _lastCopied.value = _token;
    await SemanticsService.sendAnnouncement(View.of(context), FieldRow.copiedLabel, Directionality.of(context));
  }

  ContextMenuButtonItem _copyItem(VoidCallback close) => ContextMenuButtonItem(
    type: ContextMenuButtonType.copy,
    label: FieldRow.copyMenuLabel,
    onPressed: () {
      close();
      _copy();
    },
  );

  // The row's menu, outside the value: one item, Copy. It takes focus so Escape closes it, and gives focus
  // back when it does.
  void _showMenu(Offset globalPosition) {
    _focusBeforeMenu = FocusManager.instance.primaryFocus;
    _menu.show(
      context: context,
      contextMenuBuilder: (context) => TapRegion(
        onTapOutside: (_) => _menu.remove(),
        child: Focus(
          focusNode: _menuFocus,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return KeyEventResult.ignored;
            _closeMenuByKey();
            return KeyEventResult.handled;
          },
          child: AdaptiveTextSelectionToolbar.buttonItems(
            anchors: TextSelectionToolbarAnchors(primaryAnchor: globalPosition),
            buttonItems: [_copyItem(_menu.remove)],
          ),
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _menu.isShown) _menuFocus.requestFocus();
    });
  }

  void _closeMenuByKey() {
    _menu.remove();
    final previous = _focusBeforeMenu;
    _focusBeforeMenu = null;
    if (previous != null && previous.context != null && previous.canRequestFocus) previous.requestFocus();
  }

  void _valuePointerDown(PointerDownEvent _) {
    _gestureSelection = null;
    _freshGesture = true;
  }

  void _valueSelectionChanged(TextSelection selection, SelectionChangedCause? cause) {
    if (_freshGesture && (cause == SelectionChangedCause.tap || cause == SelectionChangedCause.longPress)) {
      _gestureSelection = selection;
    }
    _freshGesture = false;
  }

  // The value's menu (a right-click or a long press on it). The platform's text menu when the user has
  // selected part of the value; otherwise the row's Copy, with the whole value shown selected.
  Widget _valueMenu(BuildContext context, EditableTextState field) {
    final value = field.textEditingValue;
    final selection = value.selection;
    final all = TextSelection(baseOffset: 0, extentOffset: value.text.length);
    final users = selection.isValid && !selection.isCollapsed && selection != _gestureSelection && selection != all;
    if (users) return AdaptiveTextSelectionToolbar.editableText(editableTextState: field);
    if (selection != all) {
      _gestureSelection = all;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !field.mounted || field.textEditingValue.text != value.text) return;
        field.userUpdateTextEditingValue(
          field.textEditingValue.copyWith(selection: all),
          SelectionChangedCause.toolbar,
        );
      });
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: field.contextMenuAnchors,
      buttonItems: [_copyItem(field.hideToolbar)],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label = (widget.label ?? '').trim().isEmpty ? null : widget.label!;
    final link = widget.kind == FieldKind.link && widget.onOpenLink != null ? safeWebLink(widget.value) : null;
    final copyName = widget.copyName ?? FieldRow.copyNameFor(widget.kind, widget.label);

    final labelText = label == null ? null : Text(label, style: context.typeScale.caption.copyWith(color: c.inkMuted));
    final Widget text;
    if (link != null) {
      text = Align(
        alignment: AlignmentDirectional.centerStart,
        child: _Link(
          uri: link,
          label: label,
          value: widget.value,
          onOpen: () => widget.onOpenLink!(link),
          labelText: labelText,
        ),
      );
    } else {
      text = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ?labelText,
          Listener(
            onPointerDown: _valuePointerDown,
            child: SelectableText(
              widget.value,
              focusNode: _valueFocus,
              style: context.typeScale.body.copyWith(color: c.ink),
              onSelectionChanged: _valueSelectionChanged,
              contextMenuBuilder: _valueMenu,
            ),
          ),
        ],
      );
    }

    Widget row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: context.density.rowHeight),
      child: Padding(
        padding: FieldRow.padding(context.look),
        child: Row(
          children: [
            Expanded(child: text),
            SizedBox(width: FieldRow.gap(context.look)),
            _CopyButton(name: copyName, copied: _copied, onPressed: _copy),
          ],
        ),
      ),
    );
    // A long press offers Copy on touch screens only: with a mouse, holding still is the start of a selection.
    row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      supportedDevices: const {PointerDeviceKind.touch, PointerDeviceKind.stylus},
      onLongPressStart: (d) => _showMenu(d.globalPosition),
      child: row,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapUp: (d) => _showMenu(d.globalPosition),
      child: row,
    );
  }
}

/// The label and the link together: one target, at least `control-height` square, so it meets the 44px
/// rule inside the row's own height. `accent` and underlined (design/README.md "Links").
class _Link extends StatelessWidget {
  const _Link({required this.uri, required this.label, required this.value, required this.onOpen, this.labelText});

  final Uri uri;
  final String? label;
  final String value;
  final VoidCallback onOpen;
  final Widget? labelText;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      link: true,
      linkUrl: uri,
      child: Pressable(
        onPressed: onOpen,
        button: false,
        scaleOnPress: false,
        borderRadius: MyDataRadii.sm(context.look),
        semanticLabel: label == null ? value : '$label, $value',
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: context.density.controlHeight, minWidth: context.density.controlHeight),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              heightFactor: 1,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ?labelText,
                  Text(
                    value,
                    style: context.typeScale.body.copyWith(
                      color: c.accent,
                      decoration: TextDecoration.underline,
                      decorationColor: c.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The button that copies: the [MyDataIconButton] in its quiet tone, a copy icon in `ink-muted` that becomes
/// a check once copied, its tooltip then [FieldRow.copiedLabel], which screen readers also hear as its value.
class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.name, required this.copied, required this.onPressed});

  final String name;
  final bool copied;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Semantics(
          value: copied ? FieldRow.copiedLabel : null,
          child: MyDataIconButton(
            icon: MyDataIcon.copy,
            label: name,
            tone: IconButtonTone.quiet,
            done: copied,
            doneLabel: FieldRow.copiedLabel,
            onPressed: onPressed,
          ),
        ),
      );
}

/// A group of [FieldRow]s: a [GroupedList]'s look (`surface`, `radius-lg`, `shadow-1`, full-width `line`
/// dividers), with the optional [heading] above it in `label` and `ink-muted`.
class FieldGroup extends StatelessWidget {
  FieldGroup({super.key, this.heading, required this.rows})
    : assert(rows.isNotEmpty, 'a group with no values is left out, not shown empty');

  /// The kind's heading ("Phone"), in sentence case. Null for none.
  final String? heading;

  final List<FieldRow> rows;

  @override
  Widget build(BuildContext context) => GroupFrame(heading: heading, parts: rows);
}

/// A contact's fields: one [FieldGroup] per [FieldKind], headed by [FieldKind.heading], in the spec's
/// order (Phone, Email, Address, Birthday, Links, Notes), `space-6` apart. A kind with no values is left
/// out entirely, and so is a value that is empty or only spaces, so there is never an empty row. Within a
/// kind, rows keep the order given.
///
/// Notes: pass a [FieldKind.note] row only when the source reads notes (`notes_included`) and the note is
/// not empty. A contact from This Mac has none, so it has no Notes group at all.
class FieldGroups extends StatelessWidget {
  const FieldGroups({super.key, required this.fields});

  final List<FieldRow> fields;

  /// Between groups (preview: `.sec{margin-bottom:24px}`).
  static double gap(MyDataLook look) => look.space(6);

  @override
  Widget build(BuildContext context) {
    final groups = [
      for (final kind in FieldKind.values)
        if (fields.where((f) => f.kind == kind && f.value.trim().isNotEmpty).toList() case final rows
            when rows.isNotEmpty)
          FieldGroup(heading: kind.heading, rows: rows),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < groups.length; i++) ...[if (i > 0) SizedBox(height: gap(context.look)), groups[i]],
      ],
    );
  }
}

/// The address a [FieldKind.link] value opens, or null when it must not open anything.
///
/// The value is never trusted to say what it opens (contact cards come from shared and imported vCards).
/// It is a link only when, after trimming spaces at its ends, it is:
///
/// - an `http` or `https` URL (any case) with `//` and a host, such as `https://example.com/ava`; or
/// - a bare address with no scheme whose host is a name with a dot and a top-level part of letters, such
///   as `example.com/ava` or `www.example.org:8080`; it opens with `https://` added.
///
/// Never a link: any other scheme (`javascript:`, `file:`, `data:`, `mailto:`, `ftp:`, an app's own
/// scheme); a value with spaces, control characters or a backslash inside; a protocol-relative `//host`;
/// an address with a user name or password (`ava@example.com`, `https://a@example.com`), which can
/// disguise where it goes; a bare host without a dot (`localhost`) or with a numeric end (`1.5`,
/// `192.168.0.1`); or anything that does not parse.
Uri? safeWebLink(String value) {
  final v = value.trim();
  if (v.isEmpty || v.length > _maxLinkLength) return null;
  if (_forbidden.hasMatch(v)) return null;
  final scheme = _scheme.firstMatch(v);
  final bare = scheme == null || _hostPort.hasMatch(v);
  final String candidate;
  if (bare) {
    if (v.startsWith('/')) return null;
    candidate = 'https://$v';
  } else {
    final s = scheme.group(1)!.toLowerCase();
    if (s != 'http' && s != 'https') return null;
    if (!v.startsWith('//', scheme.end)) return null;
    candidate = v;
  }
  final uri = Uri.tryParse(candidate);
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
  if (!_validHost(uri.host, bare: bare)) return null;
  return uri;
}

const _maxLinkLength = 2048;
final _forbidden = RegExp(r'[\s\x00-\x1F\x7F\\]');
final _scheme = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*):');
// "example.com:8080/ava" looks like a scheme ("example.com:") but is a host and a port.
final _hostPort = RegExp(r'^[A-Za-z0-9.\-]+:[0-9]{1,5}(?:[/?#]|$)');
final _label = RegExp(r'^[\p{L}\p{N}](?:[\p{L}\p{N}\-]*[\p{L}\p{N}])?$', unicode: true);
final _topLevel = RegExp(r'^(?:\p{L}{2,}|xn--[a-z0-9\-]+)$', unicode: true, caseSensitive: false);

bool _validHost(String encodedHost, {required bool bare}) {
  // An IPv6 literal ([::1]) parses as a host with colons; allowed only with an explicit scheme.
  if (encodedHost.contains(':')) return !bare;
  final String host;
  try {
    host = Uri.decodeComponent(encodedHost);
  } on ArgumentError {
    return false;
  }
  final labels = host.split('.');
  if (labels.any((l) => !_label.hasMatch(l))) return false;
  if (!bare) return true;
  return labels.length >= 2 && _topLevel.hasMatch(labels.last);
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
final _fullBirthday = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _noYearBirthday = RegExp(r'^--(\d{2})-?(\d{2})$');

/// A birthday as the host gives it (`YYYY-MM-DD`, or `--MM-DD` when the year is not known) written out
/// in the long form without a weekday: "12 May 1990", or "12 May" without a year. Null when [value] is
/// not a real date (show nothing rather than a guess).
///
/// The apps are in English only, so this writes British English day-month-year. A locale-aware form
/// comes with localisation.
String? formatBirthday(String value) {
  final v = value.trim();
  int? year;
  final int month;
  final int day;
  final full = _fullBirthday.firstMatch(v);
  final noYear = _noYearBirthday.firstMatch(v);
  if (full != null) {
    year = int.parse(full.group(1)!);
    month = int.parse(full.group(2)!);
    day = int.parse(full.group(3)!);
  } else if (noYear != null) {
    month = int.parse(noYear.group(1)!);
    day = int.parse(noYear.group(2)!);
  } else {
    return null;
  }
  if (month < 1 || month > 12 || day < 1) return null;
  // Without a year, 29 February is a real birthday; use a leap year to check the day.
  final checkYear = year ?? 2000;
  final daysInMonth = DateTime.utc(checkYear, month + 1, 0).day;
  if (day > daysInMonth) return null;
  final dayMonth = '$day ${_months[month - 1]}';
  return year == null ? dayMonth : '$dayMonth $year';
}
