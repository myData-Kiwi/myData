/// How each component is drawn (theme.schema.json `components`, design/themes/ARCHITECTURE.md 3.2): the
/// enumerations as typed values, read by the widgets' variant switches through `context.variants`. The app
/// keeps choosing roles (a filled button is the primary action); the theme decides how each role is drawn.
library;

import 'package:flutter/foundation.dart';

import 'theme_file.dart' show KeyedEnum;

/// How the primary action (a filled [Button]) is drawn. Never text only: a primary action must look like a
/// button.
enum PrimaryStyle with KeyedEnum {
  /// The accent, with `on-accent` text (Kiwi).
  filled('filled'),

  /// No fill: a 2 px accent outline and accent text (Journal).
  outline('outline'),

  /// The accent with a 3 px `edge` outline over a hard offset drop that a press pushes into (Brutalist).
  brutal('brutal'),

  /// The accent, bevelled: a light line top and left, a dark one bottom and right, and an outer `edge` ring
  /// (Retro Desktop's default button).
  bevel('bevel'),

  /// The Mac push button: the accent under a soft top light, a hairline darker edge and a small drop.
  push('push');

  const PrimaryStyle(this.key);
  @override
  final String key;
}

/// How a secondary action (a tonal [Button]) is drawn.
enum SecondaryStyle with KeyedEnum {
  /// `accent-soft` with accent text (Kiwi).
  tonal('tonal'),

  /// No fill, the control outline and `ink` text (Hairline).
  outline('outline'),

  /// The accent label alone, underlined so it still reads as an action (Journal).
  text('text');

  const SecondaryStyle(this.key);
  @override
  final String key;
}

/// The corners of a button, whatever the theme's other controls take.
enum ButtonShapeStyle with KeyedEnum {
  pill('pill'),
  rounded('rounded'),
  square('square'),
  cut('cut');

  const ButtonShapeStyle(this.key);
  @override
  final String key;
}

/// How a list of rows is drawn (GroupedList, GroupedSection, ContactList, MultiSelectList, event lists).
enum ListStyle with KeyedEnum {
  /// Rows straight on the ground, no container, full-width separators (Hairline).
  plain('plain'),

  /// Rows in a rounded group on `surface` with a lift (Kiwi, as drawn today).
  inset('inset'),

  /// Each row its own card, a gap between them (Arcade).
  cards('cards'),

  /// One group with an outline, always drawn whatever `borders.cards` says (Sticker).
  bordered('bordered'),

  /// No container: a rule above, between and below the rows, in the border colour (Journal).
  ruled('ruled'),

  /// A table: a header band, square corners, an outline, full rules and zebra stripes (Ledger).
  table('table');

  const ListStyle(this.key);
  @override
  final String key;
}

/// How the sidebar of the branded frame is drawn. On a Mac the window keeps its skeleton (its sidebar
/// column); the style reaches how its rows are drawn.
enum SidebarStyle with KeyedEnum {
  /// The Mac source list: small rows inset from the edges, the selection a rounded fill (Sticker).
  sourceList('source-list'),

  /// A flush column of pills with a rule along its edge (Kiwi).
  column('column'),

  /// A narrow rail of icons with their names under them.
  rail('rail'),

  /// The places as tabs along the top of the content, the sidebar folded away.
  tabs('tabs');

  const SidebarStyle(this.key);
  @override
  final String key;
}

/// How the toolbar band is drawn.
enum ToolbarStyle with KeyedEnum {
  /// A transparent band on the window ground, no rule (Notebook, Zen; the Mac's own).
  native('native'),

  /// A solid band with a rule under it (Kiwi).
  flat('flat'),

  /// A detached capsule with the theme's outline and lift (Frosted, Sticker).
  floating('floating');

  const ToolbarStyle(this.key);
  @override
  final String key;
}

/// How text fields, selects, pickers and token fields are drawn.
enum InputStyle with KeyedEnum {
  /// A `surface-sunken` well with a `line-strong` line under it.
  filled('filled'),

  /// A `surface` box with a `line-strong` outline (Kiwi).
  outlined('outlined'),

  /// No box: a `line-strong` line under the text (Journal).
  underlined('underlined');

  const InputStyle(this.key);
  @override
  final String key;
}

/// How the current item (a selected row, the current place in the sidebar, the selected day) is marked.
enum SelectionStyle with KeyedEnum {
  /// An `accent-soft` fill; where that is under 3:1 on `surface`, a `selection` bar too (or an outline in a
  /// theme that outlines its controls), so it is never colour alone (Kiwi, Sticker).
  tint('tint'),

  /// A `selection` fill with `on-selection` text (Retro Desktop, Geometric).
  solid('solid'),

  /// An `ink` fill with its text in `bg` (High Contrast, Brutalist).
  inverse('inverse'),

  /// A 3 px `selection` bar at the leading edge over an `accent-soft` fill (Hairline, Journal).
  bar('bar'),

  /// A 2 px `selection` outline (Large, Blueprint).
  outline('outline'),

  /// A `selection` swipe behind the name, and a 3 px accent bar at the leading edge, since the swipe alone
  /// is under 3:1 on paper (Notebook).
  highlighter('highlighter');

  const SelectionStyle(this.key);
  @override
  final String key;
}

/// How a person's avatar is drawn.
enum AvatarStyle with KeyedEnum {
  circle('circle'),
  rounded('rounded'),
  square('square'),

  /// A circle, a square or a triangle, chosen from the person's name (Geometric).
  shape('shape'),

  /// No avatar: the name is the content (Journal, Notebook).
  none('none');

  const AvatarStyle(this.key);
  @override
  final String key;
}

/// How tabs and segmented controls mark the current one.
enum TabsStyle with KeyedEnum {
  /// A pill on a sunken track (Kiwi).
  pill('pill'),

  /// A 2 px line under the current one, no track (Hairline, Journal).
  underline('underline'),

  /// Boxed segments in one outline, the current one filled (High Contrast, Ledger).
  boxed('boxed');

  const TabsStyle(this.key);
  @override
  final String key;
}

/// How myAssistant's conversation is drawn.
enum ChatStyle with KeyedEnum {
  /// Bubbles: the user's on the right in `accent-soft`, myAssistant's on the left on `surface` (Kiwi).
  bubbles('bubbles'),

  /// Full-width blocks, the user's on `surface-sunken` (Hairline).
  blocks('blocks'),

  /// A transcript: the speaker's name over each turn and a rule at its leading edge, no bubbles (Journal).
  transcript('transcript');

  const ChatStyle(this.key);
  @override
  final String key;
}

/// How the month grid's day cells are drawn.
enum MonthStyle with KeyedEnum {
  /// The month in a card on `surface` with `radius-lg` and a lift, each day boxed by `line` rules (Kiwi, as
  /// drawn today; its RULES.md's "cells with a gap" is not built: open for the owner).
  boxed('boxed'),

  /// No cells: the days on the ground, a rule between the weeks (Hairline, Journal).
  open('open'),

  /// One ruled grid in the control outline's colour, `radius-sm`, no lift (Ledger, Swiss).
  table('table');

  const MonthStyle(this.key);
  @override
  final String key;
}

/// How today's date is marked in the month.
enum TodayStyle with KeyedEnum {
  /// A filled accent disc behind the number (Kiwi).
  disc('disc'),

  /// An accent ring around the number (Frosted, Journal).
  ring('ring'),

  /// The whole cell in `ink`, its text in `bg` (High Contrast, Ledger).
  inverse('inverse');

  const TodayStyle(this.key);
  @override
  final String key;
}

/// How calendars and other data are told apart.
enum DataColourStyle with KeyedEnum {
  /// By colour (`data-*`).
  colour('colour'),

  /// By a grey pattern, with the name always shown (E-ink).
  pattern('pattern');

  const DataColourStyle(this.key);
  @override
  final String key;
}

T _of<T extends KeyedEnum>(List<T> values, String? key, T fallback) {
  for (final v in values) {
    if (v.key == key) return v;
  }
  return fallback;
}

/// How each component is drawn in a look: one typed value per `components` key, Kiwi's where a file leaves
/// one out (the validator fills a drawn file's groups from `based-on`, so only a partial group gets here).
@immutable
class MyDataVariants {
  const MyDataVariants._(
    this.values, {
    required this.primary,
    required this.secondary,
    required this.buttonShape,
    required this.list,
    required this.sidebar,
    required this.toolbar,
    required this.inputs,
    required this.selection,
    required this.avatar,
    required this.tabs,
    required this.chat,
    required this.month,
    required this.today,
    required this.dataColours,
  });

  /// The variants a theme's `components` give (`button.primary` → `filled`, `list` → `inset`, ...).
  factory MyDataVariants(Map<String, String> values) => MyDataVariants._(
        values,
        primary: _of(PrimaryStyle.values, values['button.primary'], PrimaryStyle.filled),
        secondary: _of(SecondaryStyle.values, values['button.secondary'], SecondaryStyle.tonal),
        buttonShape: _of(ButtonShapeStyle.values, values['button.shape'], ButtonShapeStyle.pill),
        list: _of(ListStyle.values, values['list'], ListStyle.inset),
        sidebar: _of(SidebarStyle.values, values['sidebar'], SidebarStyle.column),
        toolbar: _of(ToolbarStyle.values, values['toolbar'], ToolbarStyle.flat),
        inputs: _of(InputStyle.values, values['inputs'], InputStyle.outlined),
        selection: _of(SelectionStyle.values, values['selection'], SelectionStyle.tint),
        avatar: _of(AvatarStyle.values, values['avatar'], AvatarStyle.circle),
        tabs: _of(TabsStyle.values, values['tabs'], TabsStyle.pill),
        chat: _of(ChatStyle.values, values['chat'], ChatStyle.bubbles),
        month: _of(MonthStyle.values, values['month'], MonthStyle.boxed),
        today: _of(TodayStyle.values, values['today'], TodayStyle.disc),
        dataColours: _of(DataColourStyle.values, values['data-colours'], DataColourStyle.colour),
      );

  /// Kiwi's, as drawn today: the fallback look's.
  static final kiwi = MyDataVariants(const {
    'button.primary': 'filled',
    'button.secondary': 'tonal',
    'button.shape': 'pill',
    'list': 'inset',
    'sidebar': 'column',
    'toolbar': 'flat',
    'inputs': 'outlined',
    'selection': 'tint',
    'avatar': 'circle',
    'tabs': 'pill',
    'chat': 'bubbles',
    'month': 'boxed',
    'today': 'disc',
    'data-colours': 'colour',
  });

  /// The file's keys and values, as given.
  final Map<String, String> values;

  final PrimaryStyle primary;
  final SecondaryStyle secondary;
  final ButtonShapeStyle buttonShape;
  final ListStyle list;
  final SidebarStyle sidebar;
  final ToolbarStyle toolbar;
  final InputStyle inputs;
  final SelectionStyle selection;
  final AvatarStyle avatar;
  final TabsStyle tabs;
  final ChatStyle chat;
  final MonthStyle month;
  final TodayStyle today;
  final DataColourStyle dataColours;

  /// `variants['list']`, `variants['button.primary']`: the file's key as given.
  String? operator [](String key) => values[key];

  /// These variants with [values] changed (tests, and the gallery's specimens).
  MyDataVariants copyWith(Map<String, String> values) => MyDataVariants({...this.values, ...values});

  @override
  bool operator ==(Object other) => other is MyDataVariants && mapEquals(other.values, values);

  @override
  int get hashCode => Object.hashAllUnordered(values.entries.map((e) => Object.hash(e.key, e.value)));
}
