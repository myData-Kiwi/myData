import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, listEquals;
import 'package:flutter/material.dart' show Icons;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../mac/mac_chrome.dart';
import '../mac/mac_theme.dart';
import '../motion.dart';
import '../theme.dart';
import 'app_frame.dart' show AppLayout;
import 'app_menu_bar.dart' show AppMenuBar;
import 'avatar.dart';
import 'group_frame.dart';
import 'grouped_list.dart' show GroupedRow;
import 'menu.dart';
import 'multi_select.dart' show MultiSelectController;
import 'pressable.dart' show FocusRing;
import 'text_field.dart' show MyDataSearchField;
import 'toggle_target.dart' show InsetRingPainter;

/// How a [ContactList] draws its rows.
enum ContactListStyle {
  /// One card per letter group on `bg`, 56px rows with an avatar and a caption (design/components/ContactList).
  grouped,

  /// The Mac frame's plain list (docs/2026-10-23-plan.md section 5, "Lists are lists"): `row-height` (24pt)
  /// rows of the name alone in `body`, the family name in `body-emphasized` as Contacts.app does, under
  /// `section-height` letter headings in `caption-emphasized`; no cards, no avatars, no dividers. The selection
  /// is a `selection` rounded fill inset `row-inset` from the sides: the accent with `on-accent` text while
  /// the list has focus in the active window, `selection-inactive` otherwise; adjacent selected rows join into
  /// one block. A row the keyboard is on without being selected (Option-arrows) gets a 2pt accent ring.
  plain,
}

/// One contact as a [ContactList] shows it. The host gives these values; the list only reads them.
@immutable
class ContactListEntry {
  /// [letter] defaults to [contactGroupLetter] of [name]. Build [caption] with [contactCaption].
  ContactListEntry({
    required this.id,
    required this.name,
    this.givenName = '',
    this.familyName = '',
    this.organisation = '',
    this.emails = const [],
    this.phones = const [],
    this.caption,
    String? letter,
    this.photo,
  }) : letter = letter ?? contactGroupLetter(name);

  /// The host's id for the contact; [ContactList.onOpen] is called with it.
  final String id;

  /// The name to show, as the host gives it (`display_name`): never empty. The organisation, an email address
  /// or a phone number when the card has no name.
  final String name;

  /// The card's given name, or empty. Used for the [Avatar]'s initials and by search.
  final String givenName;

  /// The card's family name, or empty. Used for the [Avatar]'s initials and by search.
  final String familyName;

  /// The card's organisation, or empty. Searched.
  final String organisation;

  /// The card's email addresses, in the card's order. Searched.
  final List<String> emails;

  /// The card's phone numbers, in the card's order. Searched, by their digits too.
  final List<String> phones;

  /// The line under the name, or null for none ([contactCaption]).
  final String? caption;

  /// The letter group the contact is listed under ("A", or "#" for a name that does not start with a letter).
  final String letter;

  /// The contact's photo, or null when the contact has none (the host's `has_photo`).
  final ImageProvider? photo;
}

/// The list of the user's contacts under a search field, from which one contact is opened
/// (design/components/ContactList).
///
/// - **Where it sits.** From 600px ([AppLayout] is not phone) it is the list pane beside the contact pane.
///   Under 600px it fills the screen and pressing a contact pushes that contact's page in. The layout is read
///   from the window's width, as [AppLayout.of] does. Give the list a bounded height: it fills it, with the
///   search field at the top and the groups scrolling below it.
/// - At the top, the search field ([MyDataSearchField], "Search contacts"), [searchGap] (`space-4`) above the
///   first group.
/// - **Groups:** one grouped list per letter, headed in `label` and `ink-muted` by [ContactListEntry.letter].
///   Contacts are listed in the order given (the locale's order; the host sorts them). Groups follow the order
///   in which their letters first appear, except "#" (names that do not start with a letter), which is always
///   last. Groups are [groupGap] (`space-6`) apart.
/// - **A row** is a GroupedList row: a 36px [Avatar] in the icon tile's place, the name in `body-strong`, and
///   the [ContactListEntry.caption] in `caption` and `ink-muted`, or no second line. Each is one line, cut
///   short with an ellipsis when too long, so every row's height is known before it is built: the list builds
///   only the rows on screen, and a photo is fetched only for a row that is shown. From 600px nothing sits at
///   the right end; under 600px a chevron in `ink-muted`.
/// - **One target.** The whole row is the target; it holds nothing else that can be pressed.
/// - **Hover:** the GroupedList hover fill (`surface-hover`). A selected row keeps its `accent-soft` under the
///   pointer (preview: `.r.sel:hover`), because the ring, not the fill, marks it.
/// - **Pressing** a row calls [onOpen] with its id: the app selects it and shows it in the contact pane, or,
///   under 600px, pushes its page.
/// - **Selected** (from 600px, [selectedId]): a [selectionRingWidth] `ink` ring inside the row over the
///   `accent-soft` fill, and `selected` in the semantics. Under 600px no row is shown selected.
/// - **Keyboard.** The list is one tab stop, after the search field; Tab from it goes on to the contact pane.
///   - From 600px, Up and Down move the selection one row at a time, across the letter groups, calling
///     [onOpen] at once so the contact pane follows. Under 600px they move the focus, and Return or Space
///     calls [onOpen] for the focused row.
///   - Home and End go to the first and last contact; Page Up and Page Down by a screenful.
///   - Typing letters while the list has focus moves to the first name that starts with them (ignoring case
///     and accents); the typed letters are forgotten after [typeAheadTimeout].
///   - Down in the search field moves into the list at the first result (from 600px, selecting it).
///   - The focus ring (2px `focus`) is drawn inside the selection ring, so both show. The selected or focused
///     row is scrolled into view. Pressing a row focuses the list without the ring, which shows once a key
///     moves the cursor (the web's `:focus-visible`, as in MonthGrid).
/// - **Search** filters as the user types ([contactMatches]): names, organisations, email addresses and phone
///   numbers, ignoring case and accents. The groups keep only their matches; empty ones are left out. The
///   selected contact stays selected (the list never calls [onOpen] because of a search), even when it no
///   longer matches. With no matches, one line in `body` and `ink-muted` ([noMatches]) takes the list's place.
///   Escape, in the field or the list, clears the search.
/// - **Screen readers** hear each row as a button named by the name and the caption ("Ava Fictional, Example
///   Labs"); the avatar is decoration. The letters are headings. While the list has focus, the row the
///   keyboard is on is the focused node, so a screen reader follows Up, Down, Home, End and type-ahead.
/// - With no contacts at all (no source on, or nothing read yet), show an EmptyState instead of this list.
/// - From 600px, choose what is selected when the screen opens with [initialContactSelection], so the
///   contact pane is never empty while there are contacts.
/// - **Several selected** ([selection], from 600px; design/components/MultiSelect): a click selects that one
///   row and opens it; ⌘-click (Ctrl-click on Windows and Linux) adds or removes a row; ⇧-click selects the
///   range from the anchor, across the letter groups; ⌘A selects every row shown; ⇧-Up and ⇧-Down (⇧-Home,
///   ⇧-End) extend the range; Option-Up and Option-Down move the focus ring only, and Space adds or removes
///   the focused row; Escape goes back to one row before it clears the search. Adjacent selected rows of a
///   group share one ring, with no divider between them. Rows a search hides leave the selection. [onOpen]
///   is called whenever one row becomes the selection by a plain click or a plain key; listen to [selection]
///   for the rest.
/// - **A row's Menu** ([menuFor]): a right-click, a Control-click on macOS or a long-press on a row, or
///   Shift-F10 and the context menu key on the row the keyboard is on (under it). The row keeps its hover
///   fill while its menu is open. Each enabled item is also a custom action of the row for screen readers.
/// - [onReturn]: Return on the row the keyboard is on from 600px, where that row is already open (it edits
///   it: design/platforms.md "Edit"). [onDelete]: the key that deletes the selected records while the list
///   has focus ([AppMenuBar.listDeleteActivator]: the Delete key on Windows and Linux, ⌘⌫ on macOS).
class ContactList extends StatefulWidget {
  const ContactList({
    super.key,
    required this.contacts,
    required this.selectedId,
    required this.onOpen,
    this.searchController,
    this.focusNode,
    this.searchFocusNode,
    this.padding = EdgeInsets.zero,
    this.selection,
    this.menuFor,
    this.onReturn,
    this.onDelete,
    this.searchTrailing,
    this.style = ContactListStyle.grouped,
    this.showSearch = true,
  });

  /// How the rows are drawn: the branded cards, or the Mac frame's plain list.
  final ContactListStyle style;

  /// The list draws its own search field above the rows. False: the search field is elsewhere (the Mac
  /// frame's toolbar) and drives the list through [searchController]; the rows start at [padding]'s top.
  final bool showSearch;

  /// Every contact, in the locale's order. The list filters them itself as the search text changes.
  final List<ContactListEntry> contacts;

  /// The id of the contact open in the contact pane, or null. Under 600px no row is shown selected, but the
  /// keyboard starts on this one: pass the contact last opened, so coming back from its page lands on it.
  final String? selectedId;

  /// Called with a contact's id when it is pressed, or chosen with the keyboard.
  final ValueChanged<String> onOpen;

  /// Holds the search text. Null: the list keeps its own, starting empty.
  final TextEditingController? searchController;

  /// The list's one focus node (the tab stop after the search field). Null: the list makes its own.
  final FocusNode? focusNode;

  /// The search field's focus node. Null: the field makes its own.
  final FocusNode? searchFocusNode;

  /// Space around the search field and the groups. The sides and the bottom are inside the scrolling area,
  /// so give the screen's padding here rather than around the list: the groups' shadows are then not cut off
  /// at the sides, and the last group can scroll clear of a phone's tab bar.
  final EdgeInsets padding;

  /// The rows selected, from 600px, when several can be (design/components/MultiSelect). Null: one row at a
  /// time, [selectedId]. With it, keep [selectedId] the one row open (null while several are selected).
  final MultiSelectController<String>? selection;

  /// The Menu of the row [id] (design/components/Menu): "Edit contact", "Delete contact". Null: no menu.
  final List<MenuEntry> Function(String id)? menuFor;

  /// Return on the open row from 600px; null: Return opens the row, as it does under 600px.
  final ValueChanged<String>? onReturn;

  /// The delete key while the list has focus; null: the key does nothing here.
  final VoidCallback? onDelete;

  /// Beside the search field, at its end, [searchTrailingGap] from it: the list's "New contact" IconButton
  /// (design/components/IconButton, "title bars"). Tab reaches it after the search field, before the list.
  final Widget? searchTrailing;

  /// Between the search field and [searchTrailing].
  static const searchTrailingGap = MyDataSpace.s2;

  /// The search field's placeholder, which is also its accessible name.
  static const searchPlaceholder = 'Search contacts';

  /// Between the search field and the first group (spec: `space-4`).
  static const searchGap = MyDataSpace.s4;

  /// Between letter groups (preview: `.sec{margin-bottom:24px}`).
  static const groupGap = MyDataSpace.s6;

  /// The selected row's `ink` ring, inside the row (preview: `box-shadow:inset 0 0 0 2px var(--ink)`).
  static const selectionRingWidth = 2.0;

  /// How far inside the row's edge the focus ring's child box sits: the selection ring, then the focus
  /// ring's own 2px offset and 2px width ([FocusRing] draws outside its child), so the ring is drawn from
  /// 2px to 4px inside the row, just inside the selection ring, as in MonthGrid.
  static const focusRingInset = selectionRingWidth + 4;

  /// How long typed letters are remembered for type-ahead.
  static const typeAheadTimeout = Duration(seconds: 1);

  /// The line shown in place of the list when nothing matches [query].
  static String noMatches(String query) => 'No contacts match “${query.trim()}”.';

  @override
  State<ContactList> createState() => _ContactListState();
}

// ---------------------------------------------------------------------------------------------------------
// Search, grouping and captions: pure functions.
// ---------------------------------------------------------------------------------------------------------

/// [text] folded for search: lower case, with accents and other marks removed ("Élodie" gives "elodie",
/// "Straße" gives "strasse", "Łódź" gives "lodz"). Letters without a plain form are kept as they are.
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    // Combining marks, as in text that arrives decomposed ("e" followed by U+0301).
    if (rune >= 0x0300 && rune <= 0x036F) continue;
    final ch = String.fromCharCode(_foldTable[rune] ?? rune);
    out.write(_foldExpand[ch] ?? ch);
  }
  return out.toString();
}

/// The letter group for a contact shown as [name], by the host's rule (`sort_letter`, host
/// `sources/views.py`), so a list built without the host's letters groups as the host does:
///
/// - the first letter, upper case, without its accents or other marks ("Émile" is under "E", "Ölaf" under
///   "O", "Ёжик" under "Е");
/// - a letter with no decomposition is its own group ("Øyvind" under "Ø", "Æsa" under "Æ", "Łukasz" under
///   "Ł"), as in the alphabets that use them;
/// - "#" when the name does not start with a letter (a phone number, "+44 …", an emoji), or starts with a
///   Chinese, Japanese kanji or Korean character, where one group per character would help no one.
String contactGroupLetter(String name) {
  final shown = name.trim();
  if (shown.isEmpty) return contactOtherGroup;
  final rune = shown.runes.first;
  final first = String.fromCharCode(rune);
  if (_noInitial(rune) || !_startsWithLetter.hasMatch(first)) return contactOtherGroup;
  // Lower-cased to look the letter up in the fold table, then upper-cased again: the decomposition's base.
  final lower = first.toLowerCase().runes.first;
  final base = String.fromCharCode(_foldTable[lower] ?? lower);
  final upper = base.toUpperCase();
  return upper.runes.length == 1 ? upper : base;
}

/// CJK ideographs (unified, their extensions and compatibility forms) and Hangul (syllables and jamo): the
/// host's `_NO_INITIAL_SCRIPTS`.
bool _noInitial(int rune) =>
    (rune >= 0x1100 && rune <= 0x11FF) ||
    (rune >= 0x3130 && rune <= 0x318F) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0x4E00 && rune <= 0x9FFF) ||
    (rune >= 0xA960 && rune <= 0xA97F) ||
    (rune >= 0xAC00 && rune <= 0xD7FF) ||
    (rune >= 0xF900 && rune <= 0xFAFF) ||
    (rune >= 0x20000 && rune <= 0x3FFFF);

/// The heading of the group for names that do not start with a letter. Always the last group.
const contactOtherGroup = '#';

/// The caption line under a contact's name: the [organisation], or else the first email address or phone
/// number that is not already the [name] shown. Null when there is nothing else to say. The host's rule
/// (`contact_caption`, host `sources/views.py`):
///
/// - a value is "already the name" when it is the same ignoring case and accents ([foldForSearch]): a
///   company's card named by its organisation, a card named by its email address;
/// - when the name is a phone number, a phone with the same digits is the name too, however either is
///   spaced ("+44 7700 900456" and "+447700900456").
String? contactCaption({
  required String name,
  String organisation = '',
  List<String> emails = const [],
  List<String> phones = const [],
}) {
  final shown = foldForSearch(name.trim());
  final shownDigits = _isPhoneLike(name) ? _digits(name) : null;
  bool same(String value) => foldForSearch(value) == shown;
  final org = organisation.trim();
  if (org.isNotEmpty && !same(org)) return org;
  for (final e in emails) {
    final v = e.trim();
    if (v.isNotEmpty && !same(v)) return v;
  }
  for (final p in phones) {
    final v = p.trim();
    if (v.isEmpty || same(v) || (shownDigits != null && _digits(v) == shownDigits)) continue;
    return v;
  }
  return null;
}

/// Whether [contact] matches the search [query], ignoring case and accents ([foldForSearch]).
///
/// - An empty query matches everything.
/// - Every word of the query must appear somewhere in the contact's name, given name, family name,
///   organisation, email addresses or phone numbers: "ava lab" finds Ava Fictional of Example Labs.
/// - A query made only of digits and phone punctuation ("7700 900123", "+44 7700") also matches a phone number
///   whose digits contain the query's digits, however either is spaced.
bool contactMatches(ContactListEntry contact, String query) {
  final q = foldForSearch(query).trim();
  if (q.isEmpty) return true;
  final keys = _keysOf(contact);
  if (q.split(_spaces).every(keys.text.contains)) return true;
  if (_isPhoneLike(query)) {
    final d = _digits(query);
    if (d.isNotEmpty && keys.phoneDigits.any((p) => p.contains(d))) return true;
  }
  return false;
}

/// The contacts that match [query] ([contactMatches]), in their order.
List<ContactListEntry> filterContacts(List<ContactListEntry> contacts, String query) =>
    foldForSearch(query).trim().isEmpty
    ? contacts
    : [
        for (final c in contacts)
          if (contactMatches(c, query)) c,
      ];

/// One letter group of a [ContactList].
typedef ContactGroup = ({String letter, List<ContactListEntry> contacts});

/// [contacts] in their letter groups: groups in the order their letters first appear, with
/// [contactOtherGroup] ("#") last; each group's contacts in their given order.
List<ContactGroup> groupContacts(List<ContactListEntry> contacts) {
  final byLetter = <String, List<ContactListEntry>>{};
  for (final c in contacts) {
    (byLetter[c.letter] ??= []).add(c);
  }
  final other = byLetter.remove(contactOtherGroup);
  return [
    for (final e in byLetter.entries) (letter: e.key, contacts: e.value),
    if (other != null) (letter: contactOtherGroup, contacts: other),
  ];
}

/// The contact to select when the list opens from 600px: [lastOpenedId] (the contact last opened on this
/// device) when it is still among [contacts], otherwise the first contact in the list as it is shown (the
/// first of the first group: never a "#" contact while there are others, wherever the "#" ones are given);
/// null when there are none.
String? initialContactSelection(List<ContactListEntry> contacts, String? lastOpenedId) {
  if (contacts.isEmpty) return null;
  if (lastOpenedId != null && contacts.any((c) => c.id == lastOpenedId)) return lastOpenedId;
  return groupContacts(contacts).first.contacts.first.id;
}

/// The folded text a contact is searched by, kept per entry (entries never change).
typedef _Keys = ({String text, String name, List<String> phoneDigits});

final _keys = Expando<_Keys>('ContactListEntry search keys');

_Keys _keysOf(ContactListEntry c) => _keys[c] ??= (
  // One field per line, so no query word (which has no spaces) can match across two fields.
  text: foldForSearch([c.name, c.givenName, c.familyName, c.organisation, ...c.emails, ...c.phones].join('\n')),
  name: foldForSearch(c.name.trim()),
  phoneDigits: [for (final p in c.phones) _digits(p)],
);

final _spaces = RegExp(r'\s+');

final _startsWithLetter = RegExp(r'^\p{L}', unicode: true);

/// Digits and the usual phone punctuation only, with at least one digit.
bool _isPhoneLike(String s) => _phoneLike.hasMatch(s.trim()) && _digitRe.hasMatch(s);

final _phoneLike = RegExp(r'^[\d\s+().\-‐–/]+$');

final _digitRe = RegExp(r'\d');

String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');

/// Lower-case letters with marks and their plain letter, one for one (Latin-1 Supplement, Latin Extended-A
/// and -B, Latin Extended Additional, Greek and Greek Extended, Cyrillic): each letter's canonical
/// decomposition without its marks, as Python's `unicodedata.normalize("NFD", …)` gives it on the host.
const _foldFrom =
    'àáâãäåçèéêëìíîïñòóôõöùúûüýÿāăąćĉċčďēĕėęěĝğġģĥĩīĭįĵķĺļľńņňōŏőŕŗřśŝşšţťũūŭůűųŵŷźżžơưǎǐǒǔǖǘǚǜǟǡǣǧǩǫǭǯǰǵ'
    'ǹǻǽǿȁȃȅȇȉȋȍȏȑȓȕȗșțȟȧȩȫȭȯȱȳΐάέήίΰϊϋόύώϓϔйѐёѓїќѝўѷӂӑӓӗӛӝӟӣӥӧӫӭӯӱӳӵӹḁḃḅḇḉḋḍḏḑḓḕḗḙḛḝḟḡḣḥḧḩḫḭḯḱḳḵḷḹḻḽḿṁṃṅ'
    'ṇṉṋṍṏṑṓṕṗṙṛṝṟṡṣṥṧṩṫṭṯṱṳṵṷṹṻṽṿẁẃẅẇẉẋẍẏẑẓẕẖẗẘẙẛạảấầẩẫậắằẳẵặẹẻẽếềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹἀἁἂἃἄἅἆἇἐἑ'
    'ἒἓἔἕἠἡἢἣἤἥἦἧἰἱἲἳἴἵἶἷὀὁὂὃὄὅὐὑὒὓὔὕὖὗὠὡὢὣὤὥὦὧὰάὲέὴήὶίὸόὺύὼώᾀᾁᾂᾃᾄᾅᾆᾇᾐᾑᾒᾓᾔᾕᾖᾗᾠᾡᾢᾣᾤᾥᾦᾧᾰᾱᾲᾳᾴᾶᾷῂῃῄῆῇῐῑῒΐῖῗῠῡ'
    'ῢΰῤῥῦῧῲῳῴῶῷ';
const _foldTo =
    'aaaaaaceeeeiiiinooooouuuuyyaaaccccdeeeeegggghiiiijklllnnnooorrrssssttuuuuuuwyzzzouaiouuuuuaaægkooʒjg'
    'naæøaaeeiioorruusthaeooooyιαεηιυιυουωϒϒиеегікиуѵжааеәжзииоөэууучыabbbcdddddeeeeefghhhhhiikkkllllmmmn'
    'nnnoooopprrrrsssssttttuuuuuvvwwwwwxxyzzzhtwyſaaaaaaaaaaaaeeeeeeeeiioooooooooooouuuuuuuyyyyααααααααεε'
    'εεεεηηηηηηηηιιιιιιιιοοοοοουυυυυυυυωωωωωωωωααεεηηιιοουυωωααααααααηηηηηηηηωωωωωωωωαααααααηηηηηιιιιιιυυ'
    'υυρρυυωωωωω';

final Map<int, int> _foldTable = () {
  assert(_foldFrom.length == _foldTo.length, 'the fold table pairs one letter with one letter');
  return {for (var i = 0; i < _foldFrom.length; i++) _foldFrom.codeUnitAt(i): _foldTo.codeUnitAt(i)};
}();

/// Letters that have no decomposition but a plain spelling.
const _foldExpand = {
  'æ': 'ae',
  'œ': 'oe',
  'ø': 'o',
  'đ': 'd',
  'ð': 'd',
  'ł': 'l',
  'ŀ': 'l',
  'þ': 'th',
  'ß': 'ss',
  'ı': 'i',
  'ħ': 'h',
  'ŧ': 't',
  'ſ': 's',
  'ς': 'σ',
};

// ---------------------------------------------------------------------------------------------------------
// The widget.
// ---------------------------------------------------------------------------------------------------------

/// What the list shows, in order: a heading, then its rows, for each group.
sealed class _Item {
  const _Item();
}

final class _HeadingItem extends _Item {
  const _HeadingItem(this.letter, {required this.first});
  final String letter;

  /// The first group: no [ContactList.groupGap] above it.
  final bool first;
}

final class _RowItem extends _Item {
  const _RowItem(this.entry, this.row, {required this.first, required this.last});
  final ContactListEntry entry;

  /// Its index among the rows shown, which is keyboard order.
  final int row;
  final bool first;
  final bool last;
}

class _Model {
  _Model(List<ContactListEntry> matches) {
    for (final (i, g) in groupContacts(matches).indexed) {
      items.add(_HeadingItem(g.letter, first: i == 0));
      for (final (j, c) in g.contacts.indexed) {
        rowIndex.putIfAbsent(c.id, () => rows.length);
        itemOfRow.add(items.length);
        items.add(_RowItem(c, rows.length, first: j == 0, last: j == g.contacts.length - 1));
        rows.add(c);
      }
    }
  }

  final items = <_Item>[];

  /// The rows shown, in keyboard order.
  final rows = <ContactListEntry>[];

  /// For each row, its index in [items].
  final itemOfRow = <int>[];
  final rowIndex = <String, int>{};

  int? indexOf(String? id) => id == null ? null : rowIndex[id];
}

class _ContactListState extends State<ContactList> {
  TextEditingController? _ownSearch;
  FocusNode? _ownFocus;
  FocusNode? _ownSearchFocus;
  final _scroll = ScrollController();

  TextEditingController get _search => widget.searchController ?? (_ownSearch ??= TextEditingController());
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'ContactList'));
  FocusNode get _searchFocus =>
      widget.searchFocusNode ?? (_ownSearchFocus ??= FocusNode(debugLabel: 'ContactList search'));

  late String _query;

  /// The row the keyboard is on, by id. From 600px it follows [ContactList.selectedId].
  String? _cursorId;
  bool _focused = false;
  bool _keyboard = FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  /// The list took focus from a press, not the keyboard: no focus ring until a key moves the cursor (the
  /// web's `:focus-visible`, as in MonthGrid). A mouse press leaves Flutter's highlight mode as it was, so
  /// [_keyboard] alone would show the ring on the row just clicked.
  bool _pointerFocus = false;

  String _typed = '';
  Timer? _typedTimer;

  List<ContactListEntry>? _modelContacts;
  String? _modelQuery;
  _Model _model = _Model(const []);

  /// Each item's height, and where it starts in the scrolling content.
  List<double> _extents = const [];
  List<double> _tops = const [];

  bool _phone = false;

  @override
  void initState() {
    super.initState();
    _query = _search.text;
    _search.addListener(_searchChanged);
    widget.selection?.addListener(_selectionChanged);
    _cursorId = widget.selectedId;
    FocusManager.instance.addHighlightModeListener(_highlightChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _phone) return;
      final i = _model.indexOf(widget.selectedId);
      if (i != null) _reveal(i);
    });
  }

  @override
  void didUpdateWidget(ContactList old) {
    super.didUpdateWidget(old);
    if (old.searchController != widget.searchController) {
      (old.searchController ?? _ownSearch)?.removeListener(_searchChanged);
      _search.addListener(_searchChanged);
      _searchChanged();
    }
    if (old.selection != widget.selection) {
      old.selection?.removeListener(_selectionChanged);
      widget.selection?.addListener(_selectionChanged);
    }
    if (old.selectedId != widget.selectedId && widget.selectedId != null) {
      _cursorId = widget.selectedId;
      final i = _modelFor(widget.contacts, _query).indexOf(widget.selectedId);
      if (i != null && !_phone) _reveal(i);
    }
  }

  @override
  void dispose() {
    widget.selection?.removeListener(_selectionChanged);
    _search.removeListener(_searchChanged);
    FocusManager.instance.removeHighlightModeListener(_highlightChanged);
    _typedTimer?.cancel();
    _ownSearch?.dispose();
    _ownFocus?.dispose();
    _ownSearchFocus?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Several rows can be selected here: [ContactList.selection], from 600px.
  MultiSelectController<String>? get _multi => _phone ? null : widget.selection;

  void _selectionChanged() {
    if (!mounted) return;
    final focused = widget.selection?.focused;
    setState(() {
      if (focused != null && !_phone) _cursorId = focused;
    });
  }

  void _highlightChanged(FocusHighlightMode mode) {
    final keyboard = mode == FocusHighlightMode.traditional;
    if (keyboard != _keyboard && mounted) setState(() => _keyboard = keyboard);
  }

  void _searchChanged() {
    final text = _search.text;
    if (text == _query) return;
    setState(() => _query = text);
    // The results start at the top.
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  _Model _modelFor(List<ContactListEntry> contacts, String query) {
    if (!identical(contacts, _modelContacts) || query != _modelQuery) {
      _modelContacts = contacts;
      _modelQuery = query;
      _model = _Model(filterContacts(contacts, query));
      _syncSelectionRows();
    }
    return _model;
  }

  /// The selection holds only the rows on screen: a row a search hides leaves it (MultiSelect). Done after
  /// this build, since the selection's listeners include this list.
  void _syncSelectionRows() {
    final selection = widget.selection;
    if (selection == null) return;
    final ids = [for (final r in _model.rows) r.id];
    if (listEquals(ids, selection.rows)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(widget.selection, selection)) selection.rows = ids;
    });
  }

  /// Every row's height is known before it is built: one line of name, one optional line of caption.
  void _measure(TextScaler scaler) {
    double line(TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: 'Ag', style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final h = p.height;
      p.dispose();
      return h;
    }

    if (widget.style == ContactListStyle.plain) {
      final row = math.max(MyDataMacSize.rowHeight, line(MyDataMacType.body) + MyDataSpace.s2);
      final heading = math.max(MyDataMacSize.sectionHeight, line(MyDataMacType.captionEmphasized) + MyDataSpace.s2);
      final extents = <double>[];
      final tops = <double>[];
      var y = _listTop;
      for (final item in _model.items) {
        final h = item is _HeadingItem ? heading : row;
        tops.add(y);
        extents.add(h);
        y += h;
      }
      _extents = extents;
      _tops = tops;
      return;
    }
    final name = line(MyDataType.bodyStrong);
    final caption = line(MyDataType.caption);
    final label = line(MyDataType.label);
    double row(bool withCaption) => math.max(
      MyDataSize.rowHeight,
      GroupedRow.padding.vertical + math.max(AvatarSize.small.diameter, name + (withCaption ? caption : 0)),
    );
    final plain = row(false);
    final captioned = row(true);
    final extents = <double>[];
    final tops = <double>[];
    var y = _listTop;
    for (final item in _model.items) {
      final h = switch (item) {
        _HeadingItem(:final first) => (first ? 0 : ContactList.groupGap) + label + GroupFrame.headingPadding.bottom,
        _RowItem(:final entry, :final first) =>
          (first ? 0 : GroupFrame.dividerWidth) + (entry.caption == null ? plain : captioned),
      };
      tops.add(y);
      extents.add(h);
      y += h;
    }
    _extents = extents;
    _tops = tops;
  }

  /// Where the first heading starts in the scrolling content: under the search field's gap, or at the top.
  double get _listTop => widget.showSearch ? ContactList.searchGap : 0;

  /// A screenful's worth of rows, for Page Up and Page Down in the selection.
  double get _rowHeight =>
      widget.style == ContactListStyle.plain ? MyDataMacSize.rowHeight : MyDataSize.rowHeight;

  /// The row the keyboard is on: the cursor if it is shown; from 600px the selected row if it is shown;
  /// otherwise the first row. Null when no rows are shown.
  int? get _cursor {
    if (_model.rows.isEmpty) return null;
    return _model.indexOf(_cursorId) ?? (_phone ? null : _model.indexOf(widget.selectedId)) ?? 0;
  }

  /// Moves the keyboard to [row]; from 600px that selects it, and the contact pane follows.
  void _moveTo(int row) {
    final id = _model.rows[row].id;
    setState(() {
      _cursorId = id;
      _pointerFocus = false;
    });
    final multi = _multi;
    if (multi != null && (multi.count != 1 || !multi.isSelected(id))) multi.select(id);
    if (!_phone && id != widget.selectedId) widget.onOpen(id);
    _reveal(row);
  }

  void _open(int row) {
    final id = _model.rows[row].id;
    setState(() => _cursorId = id);
    final multi = _multi;
    if (multi != null && (multi.count != 1 || !multi.isSelected(id))) multi.select(id);
    widget.onOpen(id);
  }

  void _press(int row) {
    if (!_focus.hasFocus) {
      _pointerFocus = true;
      _focus.requestFocus();
    }
    final multi = _multi;
    if (multi != null) {
      final k = HardwareKeyboard.instance;
      final id = _model.rows[row].id;
      if (MultiSelectController.commandPressed(k)) {
        setState(() => _cursorId = id);
        multi.toggle(id);
        _openSingle(multi);
        return;
      }
      if (k.isShiftPressed) {
        setState(() => _cursorId = id);
        multi.extendTo(id);
        _openSingle(multi);
        return;
      }
    }
    _open(row);
  }

  /// After a change to [multi] that leaves one row selected, that row is the one open.
  void _openSingle(MultiSelectController<String> multi) {
    if (multi.count != 1) return;
    final id = multi.selected.first;
    if (id != widget.selectedId) widget.onOpen(id);
  }

  /// The row [row]'s rectangle on screen, from the heights known before building (the row may be off
  /// screen); null before the first layout.
  Rect? _rowRect(int row) {
    final box = _focus.context?.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !_scroll.hasClients) return null;
    final item = _model.itemOfRow[row];
    final top = _tops[item] - _scroll.position.pixels;
    return box.localToGlobal(Offset(widget.padding.left, top)) &
        Size(box.size.width - widget.padding.horizontal, _extents[item]);
  }

  /// Shift-F10 or the context menu key: the Menu of the row the keyboard is on, under it.
  void _menuFromKeyboard(int row) {
    final menuFor = widget.menuFor;
    final rect = _rowRect(row);
    if (menuFor == null || rect == null) return;
    final ltr = Directionality.of(context) == TextDirection.ltr;
    unawaited(Menu.showAt(context,
        position: ltr ? rect.bottomLeft : rect.bottomRight,
        entries: menuFor(_model.rows[row].id),
        fromKeyboard: true));
  }

  /// Scrolls [row] into view after this frame's layout; a group's first row brings its heading with it.
  void _reveal(int row) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || row >= _model.rows.length) return;
      final item = _model.itemOfRow[row];
      var top = _tops[item];
      if (_model.items[item - 1] case _HeadingItem(:final first)) {
        top = first
            ? 0
            : _tops[item - 1] + (widget.style == ContactListStyle.plain ? 0 : ContactList.groupGap);
      }
      final bottom = _tops[item] + _extents[item];
      final p = _scroll.position;
      var to = p.pixels;
      if (bottom > to + p.viewportDimension) to = bottom - p.viewportDimension;
      if (top < to) to = top;
      // The lazy list only estimates its length until it has laid out its end; the heights are known
      // here, so the end is worked out from them instead of from the scroll position.
      final end = _tops.last + _extents.last + widget.padding.bottom;
      to = to.clamp(0.0, math.max(0.0, end - p.viewportDimension));
      if (to != p.pixels) _scroll.jumpTo(to);
    });
  }

  /// The row a screenful down ([direction] 1) or up (-1) from [row].
  int _page(int row, int direction) {
    final last = _model.rows.length - 1;
    if (!_scroll.hasClients) return (row + direction * 10).clamp(0, last);
    final view = _scroll.position.viewportDimension;
    double top(int r) => _tops[_model.itemOfRow[r]];
    var to = row;
    if (direction > 0) {
      while (to < last && top(to + 1) <= top(row) + view) {
        to++;
      }
      if (to == row) to = math.min(last, row + 1);
    } else {
      while (to > 0 && top(to - 1) >= top(row) - view) {
        to--;
      }
      if (to == row) to = math.max(0, row - 1);
    }
    return to;
  }

  void _typeAhead(String character) {
    _typed += character;
    _typedTimer?.cancel();
    _typedTimer = Timer(ContactList.typeAheadTimeout, () => _typed = '');
    final prefix = foldForSearch(_typed);
    final i = _model.rows.indexWhere((c) => _keysOf(c).name.startsWith(prefix));
    if (i >= 0) _moveTo(i);
  }

  bool get _modifier {
    final k = HardwareKeyboard.instance;
    return k.isControlPressed || k.isMetaPressed || k.isAltPressed;
  }

  KeyEventResult _onListKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final multi = _multi;
    if (key == LogicalKeyboardKey.escape) {
      // Several selected: back to one first (MultiSelect), then the search.
      if (multi != null && event is KeyDownEvent && multi.clearToFocused()) {
        _openSingle(multi);
        return KeyEventResult.handled;
      }
      if (_search.text.isEmpty) return KeyEventResult.ignored;
      _search.clear();
      return KeyEventResult.handled;
    }
    final cursor = _cursor;
    if (cursor == null) return KeyEventResult.ignored;
    if (event is KeyDownEvent && widget.menuFor != null &&
        (const SingleActivator(LogicalKeyboardKey.f10, shift: true).accepts(event, keyboard) ||
            key == LogicalKeyboardKey.contextMenu)) {
      _menuFromKeyboard(cursor);
      return KeyEventResult.handled;
    }
    if (event is KeyDownEvent &&
        widget.onDelete != null &&
        AppMenuBar.listDeleteActivator(defaultTargetPlatform).accepts(event, keyboard)) {
      widget.onDelete!();
      return KeyEventResult.handled;
    }
    if (multi != null) {
      final typingSpace = key == LogicalKeyboardKey.space && _typed.isNotEmpty;
      final enter = key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
      if (!typingSpace && !enter) {
        final view = _scroll.hasClients ? _scroll.position.viewportDimension : 0.0;
        final page = math.max(1, (view / _rowHeight).floor());
        if (multi.focused == null || !multi.rows.contains(multi.focused)) {
          final id = _model.rows[cursor].id;
          if (multi.isSelected(id)) {
            multi.focusOnly(id);
          }
        }
        final before = multi.focused;
        final handled = multi.handleKey(event, page: page);
        if (handled == KeyEventResult.handled) {
          final focused = multi.focused;
          setState(() {
            _pointerFocus = false;
            if (focused != null) _cursorId = focused;
          });
          _openSingle(multi);
          final row = _model.indexOf(focused ?? before);
          if (row != null) _reveal(row);
          return KeyEventResult.handled;
        }
      }
    }
    if (_modifier) return KeyEventResult.ignored;
    final last = _model.rows.length - 1;
    int? to;
    if (key == LogicalKeyboardKey.arrowDown) {
      to = math.min(last, cursor + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      to = math.max(0, cursor - 1);
    } else if (key == LogicalKeyboardKey.home) {
      to = 0;
    } else if (key == LogicalKeyboardKey.end) {
      to = last;
    } else if (key == LogicalKeyboardKey.pageDown) {
      to = _page(cursor, 1);
    } else if (key == LogicalKeyboardKey.pageUp) {
      to = _page(cursor, -1);
    }
    if (to != null) {
      _moveTo(to);
      return KeyEventResult.handled;
    }
    final typing = _typed.isNotEmpty;
    final enter = key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter;
    if (enter && !_phone && widget.onReturn != null) {
      widget.onReturn!(_model.rows[cursor].id);
      return KeyEventResult.handled;
    }
    if (enter || (key == LogicalKeyboardKey.space && !typing)) {
      _open(cursor);
      return KeyEventResult.handled;
    }
    final ch = event.character;
    if (ch != null && ch.isNotEmpty && ch.runes.first >= 0x20 && ch.runes.first != 0x7F) {
      _typeAhead(ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onSearchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && !_modifier) {
      if (_model.rows.isEmpty) return KeyEventResult.ignored;
      _focus.requestFocus();
      _moveTo(0);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape && _search.text.isNotEmpty) {
      _search.clear();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _focusChanged(bool focused) {
    setState(() => _focused = focused);
    if (focused) {
      final cursor = _cursor;
      if (cursor != null) _reveal(cursor);
    } else {
      _typed = '';
      _pointerFocus = false;
    }
  }

  /// From 600px: the row is selected, by [ContactList.selection] or else [ContactList.selectedId].
  bool _isSelected(String id) {
    if (_phone) return false;
    final multi = widget.selection;
    return multi != null && multi.count > 0 ? multi.isSelected(id) : id == widget.selectedId;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    _phone = AppLayout.of(context) == AppLayout.phone;
    final model = _modelFor(widget.contacts, _query);
    _measure(MediaQuery.textScalerOf(context));
    final pad = widget.padding;
    final cursor = _cursor;
    final ring = _focused && _keyboard && !_pointerFocus;

    final search = Padding(
      padding: EdgeInsets.fromLTRB(pad.left, pad.top, pad.right, 0),
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onSearchKey,
        child: widget.searchTrailing == null
            ? MyDataSearchField(controller: _search, placeholder: ContactList.searchPlaceholder, focusNode: _searchFocus)
            : Row(children: [
                Expanded(
                  child: MyDataSearchField(
                      controller: _search, placeholder: ContactList.searchPlaceholder, focusNode: _searchFocus),
                ),
                const SizedBox(width: ContactList.searchTrailingGap),
                widget.searchTrailing!,
              ]),
      ),
    );

    final plain = widget.style == ContactListStyle.plain;
    final top = widget.showSearch ? ContactList.searchGap : pad.top;
    final emphasised = _focused && MacChrome.of(context).windowActive;
    final Widget body;
    if (model.rows.isEmpty) {
      body = _query.trim().isEmpty
          ? const SizedBox.shrink()
          : Padding(
              // Preview: `.none{margin:8px}` under the field's 16px margin.
              padding: EdgeInsets.fromLTRB(pad.left + MyDataSpace.s2, top, pad.right, pad.bottom),
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: Text(ContactList.noMatches(_query),
                    style: plain
                        ? MyDataMacType.body.copyWith(color: context.mac.secondaryLabel)
                        : MyDataType.body.copyWith(color: c.inkMuted)),
              ),
            );
    } else if (plain) {
      body = ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(pad.left, top, pad.right, pad.bottom),
        itemCount: model.items.length,
        itemExtentBuilder: (i, _) => i < _extents.length ? _extents[i] : null,
        addSemanticIndexes: false,
        semanticChildCount: model.rows.length,
        itemBuilder: (context, i) => switch (model.items[i]) {
          _HeadingItem(:final letter) => _PlainHeading(letter: letter),
          _RowItem(:final entry, :final row, :final first, :final last) => IndexedSemantics(
            index: row,
            child: _PlainContactRow(
              key: ValueKey(entry.id),
              entry: entry,
              selected: _isSelected(entry.id),
              emphasised: emphasised,
              joinsUp: !first && _isSelected(entry.id) && _isSelected(model.rows[row - 1].id),
              joinsDown: !last && _isSelected(entry.id) && _isSelected(model.rows[row + 1].id),
              focusRing: ring && row == cursor && !_isSelected(entry.id),
              cursor: row == cursor,
              focused: _focused && row == cursor,
              menu: widget.menuFor == null ? null : () => widget.menuFor!(entry.id),
              onPressed: () => _press(row),
            ),
          ),
        },
      );
    } else {
      body = ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(pad.left, top, pad.right, pad.bottom),
        itemCount: model.items.length,
        itemExtentBuilder: (i, _) => i < _extents.length ? _extents[i] : null,
        addSemanticIndexes: false,
        semanticChildCount: model.rows.length,
        itemBuilder: (context, i) => switch (model.items[i]) {
          _HeadingItem(:final letter, :final first) => _Heading(letter: letter, first: first),
          _RowItem(:final entry, :final row, :final first, :final last) => IndexedSemantics(
            index: row,
            child: _ContactRow(
              key: ValueKey(entry.id),
              entry: entry,
              first: first,
              last: last,
              phone: _phone,
              selected: _isSelected(entry.id),
              joinsUp: !first && _isSelected(entry.id) && _isSelected(model.rows[row - 1].id),
              joinsDown: !last && _isSelected(entry.id) && _isSelected(model.rows[row + 1].id),
              focusRing: ring && row == cursor,
              cursor: row == cursor,
              focused: _focused && row == cursor,
              menu: widget.menuFor == null ? null : () => widget.menuFor!(entry.id),
              onPressed: () => _press(row),
            ),
          ),
        },
      );
    }

    // One traversal unit: the search field, then the list, then on to whatever follows (the contact pane),
    // whatever the geometry around it.
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showSearch) search,
          Expanded(
            child: Focus(
              focusNode: _focus,
              canRequestFocus: model.rows.isNotEmpty,
              // The row the keyboard is on is the focused node for screen readers (the preview's roving
              // tabindex), not the list around it.
              includeSemantics: false,
              onKeyEvent: _onListKey,
              onFocusChange: _focusChanged,
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

/// A letter heading in the plain list: `caption-emphasized` in `secondary-label`, lined up with the names.
class _PlainHeading extends StatelessWidget {
  const _PlainHeading({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: MyDataMacSize.rowInset + MyDataMacSize.rowPadding),
    child: Align(
      alignment: AlignmentDirectional.bottomStart,
      child: Padding(
        padding: const EdgeInsets.only(bottom: MyDataSpace.s1),
        child: Semantics(
          header: true,
          child: Text(letter, maxLines: 1, style: MyDataMacType.captionEmphasized.copyWith(color: context.mac.secondaryLabel)),
        ),
      ),
    ),
  );
}

/// One row of the plain list (ContactListStyle.plain).
class _PlainContactRow extends StatefulWidget {
  const _PlainContactRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.emphasised,
    required this.joinsUp,
    required this.joinsDown,
    required this.focusRing,
    required this.cursor,
    required this.focused,
    required this.onPressed,
    this.menu,
  });

  final ContactListEntry entry;
  final bool selected;

  /// The list has focus in the active window: the selection is the accent.
  final bool emphasised;
  final bool joinsUp;
  final bool joinsDown;
  final bool focusRing;
  final bool cursor;
  final bool focused;
  final VoidCallback onPressed;
  final List<MenuEntry> Function()? menu;

  @override
  State<_PlainContactRow> createState() => _PlainContactRowState();
}

class _PlainContactRowState extends State<_PlainContactRow> {
  /// Its Menu is open: it gets the ring a right-clicked row has on the Mac.
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final e = widget.entry;
    final onAccent = widget.selected && widget.emphasised;
    final ink = onAccent ? mac.onAccent : mac.label;
    const corner = Radius.circular(MyDataMacRadius.selection);
    final shape = BorderRadius.vertical(
      top: widget.joinsUp ? Radius.zero : corner,
      bottom: widget.joinsDown ? Radius.zero : corner,
    );

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: MyDataMacSize.rowPadding),
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: widget.selected ? (widget.emphasised ? mac.accent : mac.selectionInactive) : null,
        borderRadius: shape,
        // The keyboard's ring in the system's `focus-ring`; the row a context menu was opened on, outlined in
        // the accent, as the system's lists do.
        border: widget.focusRing
            ? Border.all(color: mac.focusRing, width: MyDataMacSize.focusRingWidth)
            : (_menuOpen && !widget.selected ? Border.all(color: mac.accent, width: MyDataMacSize.tight) : null),
      ),
      child: Text.rich(
        plainNameSpan(e, MyDataMacType.body.copyWith(color: ink), MyDataMacType.bodyEmphasized.copyWith(color: ink)),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
      ),
    );
    content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: MyDataMacSize.rowInset),
      child: content,
    );
    content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: widget.onPressed,
      child: content,
    );
    final menu = widget.menu;
    if (menu != null) {
      content = ContextMenuRegion(
        entries: menu,
        onOpenChanged: (open) => setState(() => _menuOpen = open),
        child: content,
      );
    }
    final caption = e.caption;
    return Semantics(
      container: true,
      button: true,
      selected: widget.selected,
      focusable: widget.cursor ? true : null,
      focused: widget.cursor ? widget.focused : null,
      label: caption == null ? e.name : '${e.name}, $caption',
      onTap: widget.onPressed,
      customSemanticsActions: menu == null
          ? null
          : {
              for (final item in menu())
                if (item is MenuItem && item.enabled) CustomSemanticsAction(label: item.label): item.onSelected,
            },
      child: ExcludeSemantics(child: content),
    );
  }
}

/// [e]'s name with its family name in [strong], as Contacts.app lists names: "Ava **Fictional**". A name
/// without a family name in it (a company, an email address) is all in [strong] when the card has no given or
/// family name, and all in [regular] otherwise.
TextSpan plainNameSpan(ContactListEntry e, TextStyle regular, TextStyle strong) {
  final family = e.familyName.trim();
  final name = e.name;
  if (family.isNotEmpty) {
    final at = name.lastIndexOf(family);
    if (at >= 0) {
      return TextSpan(style: regular, children: [
        if (at > 0) TextSpan(text: name.substring(0, at)),
        TextSpan(text: family, style: strong),
        if (at + family.length < name.length) TextSpan(text: name.substring(at + family.length)),
      ]);
    }
  }
  final noPersonName = e.givenName.trim().isEmpty && family.isEmpty;
  return TextSpan(text: name, style: noPersonName ? strong : regular);
}

/// A letter group's heading: `label` in `ink-muted`, as GroupedList draws its heading.
class _Heading extends StatelessWidget {
  const _Heading({required this.letter, required this.first});

  final String letter;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: GroupFrame.headingPadding.add(EdgeInsets.only(top: first ? 0 : ContactList.groupGap)),
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: Semantics(
        header: true,
        child: Text(letter, maxLines: 1, style: MyDataType.label.copyWith(color: context.colors.inkMuted)),
      ),
    ),
  );
}

/// One contact row, drawn as its own piece of its letter group's card: `surface`, the group's corners when
/// it is first or last, the 1px `line` divider above it unless it is first, and its share of the card's
/// shadow.
class _ContactRow extends StatefulWidget {
  const _ContactRow({
    super.key,
    required this.entry,
    required this.first,
    required this.last,
    required this.phone,
    required this.selected,
    this.joinsUp = false,
    this.joinsDown = false,
    required this.focusRing,
    required this.cursor,
    required this.focused,
    required this.onPressed,
    this.menu,
  });

  final ContactListEntry entry;
  final bool first;
  final bool last;
  final bool phone;
  final bool selected;

  /// The row above (or below) is selected too: one ring around the run, no divider between them.
  final bool joinsUp;
  final bool joinsDown;

  /// The row's Menu entries; null for none.
  final List<MenuEntry> Function()? menu;

  /// The focus ring is drawn: keyboard focus is on this row.
  final bool focusRing;

  /// The row the keyboard is on: the list's one focusable node for screen readers (the preview's roving
  /// tabindex).
  final bool cursor;

  /// The list has focus and this is the row the keyboard is on: the focused node for screen readers, so
  /// they follow the keys, however the focus came (a press shows no ring but still moves the reader).
  final bool focused;
  final VoidCallback onPressed;

  @override
  State<_ContactRow> createState() => _ContactRowState();
}

class _ContactRowState extends State<_ContactRow> {
  bool _hovered = false;
  bool _pressed = false;

  /// Its Menu is open: it keeps its hover fill (design/components/Menu).
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final e = widget.entry;
    const corner = Radius.circular(MyDataRadius.lg);
    final shape = BorderRadius.vertical(
      top: widget.first ? corner : Radius.zero,
      bottom: widget.last ? corner : Radius.zero,
    );
    final caption = e.caption;

    Widget content = Padding(
      padding: GroupedRow.padding,
      child: Row(
        children: [
          Avatar(name: e.name, givenName: e.givenName, familyName: e.familyName, photo: e.photo),
          const SizedBox(width: GroupedRow.gap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: MyDataType.bodyStrong.copyWith(color: c.ink),
                ),
                if (caption != null)
                  Text(
                    caption,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: MyDataType.caption.copyWith(color: c.inkMuted),
                  ),
              ],
            ),
          ),
          if (widget.phone) ...[
            const SizedBox(width: GroupedRow.gap),
            Icon(Icons.chevron_right_rounded, size: MyDataSize.icon, color: c.inkMuted),
          ],
        ],
      ),
    );

    // Hover and press fill, under the content; a selected row keeps accent-soft.
    final lit = (_hovered || _pressed || _menuOpen) && !widget.selected;
    content = AnimatedContainer(
      duration: MyDataMotion.fast,
      curve: MyDataMotion.standard,
      decoration: BoxDecoration(
        color: lit ? c.surfaceHover : c.surfaceHover.withValues(alpha: 0),
        borderRadius: shape,
      ),
      child: content,
    );
    // Press: dims at once, returns over `fast` (Pressable's press, without the scale: rows fill instead).
    content = AnimatedOpacity(
      opacity: _pressed ? MyDataMotion.pressOpacity : 1,
      duration: _pressed ? Duration.zero : MyDataMotion.fast,
      curve: MyDataMotion.standard,
      child: content,
    );

    // Bottom up: the fill, the content, the selection ring, then the focus ring inside it.
    final inset = ContactList.focusRingInset;
    content = Stack(
      fit: StackFit.passthrough,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: widget.selected ? c.accentSoft : null, borderRadius: shape),
          position: DecorationPosition.background,
          child: content,
        ),
        // A row selected on its own: its own ring. A run's ring is drawn over the whole pieces (below).
        if (widget.selected && !widget.joinsUp && !widget.joinsDown)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: c.ink, width: ContactList.selectionRingWidth),
                  borderRadius: shape,
                ),
              ),
            ),
          ),
        if (widget.focusRing)
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.all(inset),
                child: FocusRing(visible: true, borderRadius: _shrink(shape, inset), child: const SizedBox.expand()),
              ),
            ),
          ),
      ],
    );

    content = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: content,
      ),
    );
    final menu = widget.menu;
    if (menu != null) {
      content = ContextMenuRegion(
        entries: menu,
        onOpenChanged: (open) => setState(() => _menuOpen = open),
        child: content,
      );
    }

    content = Semantics(
      container: true,
      button: true,
      selected: widget.phone ? null : widget.selected,
      focusable: widget.cursor ? true : null,
      focused: widget.cursor ? widget.focused : null,
      label: caption == null ? e.name : '${e.name}, $caption',
      onTap: widget.onPressed,
      // The Menu's items, for VoiceOver's Actions rotor and TalkBack's actions (design/components/Menu).
      customSemanticsActions: menu == null
          ? null
          : {
              for (final item in menu())
                if (item is MenuItem && item.enabled) CustomSemanticsAction(label: item.label): item.onSelected,
            },
      child: ExcludeSemantics(child: content),
    );

    return CustomPaint(
      painter: _CardPieceShadow(context.shadows.shadow1, first: widget.first, last: widget.last),
      // A run of selected rows: one ring over the whole piece (its divider too), open where it joins the
      // next row, so the run's sides have no gap.
      foregroundPainter: widget.selected && (widget.joinsUp || widget.joinsDown)
          ? InsetRingPainter(
              color: c.ink,
              width: ContactList.selectionRingWidth,
              borderRadius: shape,
              top: !widget.joinsUp,
              bottom: !widget.joinsDown,
            )
          : null,
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.surface, borderRadius: shape),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // No divider inside a run of selected rows: the run reads as one block.
            if (!widget.first)
              Container(height: GroupFrame.dividerWidth, color: widget.joinsUp ? c.accentSoft : c.line),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  static BorderRadius _shrink(BorderRadius r, double by) {
    Radius less(Radius x) => Radius.circular(math.max(0, x.x - by));
    return BorderRadius.only(
      topLeft: less(r.topLeft),
      topRight: less(r.topRight),
      bottomLeft: less(r.bottomLeft),
      bottomRight: less(r.bottomRight),
    );
  }
}

/// One row's share of its group card's shadow (`shadow-1`). The list builds rows lazily, so the card is drawn
/// piece by piece; each piece paints the shadow of a card that runs on past its inner edges, clipped to its
/// own height there, so the pieces join into one card's shadow with no seams. The first and last pieces add
/// the card's ends.
class _CardPieceShadow extends CustomPainter {
  _CardPieceShadow(this.shadows, {required this.first, required this.last});

  final List<BoxShadow> shadows;
  final bool first;
  final bool last;

  /// Further than any `shadow-1` blur reaches.
  static const reach = 64.0;

  @override
  void paint(Canvas canvas, Size size) {
    const corner = Radius.circular(MyDataRadius.lg);
    final clip = Rect.fromLTRB(
      -reach,
      first ? -reach : 0,
      size.width + reach,
      last ? size.height + reach : size.height,
    );
    final card = RRect.fromRectAndCorners(
      Rect.fromLTRB(0, first ? 0 : -2 * reach, size.width, last ? size.height : size.height + 2 * reach),
      topLeft: first ? corner : Radius.zero,
      topRight: first ? corner : Radius.zero,
      bottomLeft: last ? corner : Radius.zero,
      bottomRight: last ? corner : Radius.zero,
    );
    canvas.save();
    canvas.clipRect(clip);
    for (final s in shadows) {
      canvas.drawRRect(card.shift(s.offset).inflate(s.spreadRadius), s.toPaint());
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CardPieceShadow old) => old.shadows != shadows || old.first != first || old.last != last;
}
