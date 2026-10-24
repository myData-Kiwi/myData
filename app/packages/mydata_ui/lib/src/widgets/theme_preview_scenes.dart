import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../generated/tokens.g.dart' show MyDataMacSize;
import '../mac/mac_theme.dart' show MacTypeContext, MacSystemLook;
import '../theme/theme.dart';
import 'avatar.dart';
import 'badge.dart';
import 'button.dart';
import 'edges.dart' show MyDataEdgesPaint;
import 'selection.dart';
import 'icon_tile.dart';
import 'status.dart';
import 'switch.dart';

/// Each app's preview scene for the theme gallery (design/themes/ARCHITECTURE.md 4.4): its main screen in
/// small, on synthetic data only (Ava Fictional, `example.org`, Ofcom's drama numbers, a fixed demo week),
/// drawn from the look's roles and the shared widgets, so a card shows a theme as the app would draw it.
/// They live here, not in the apps, so myData's gallery can show every app's scene.
abstract final class ThemePreviewScenes {
  /// The scene of the app [id] (`mycontacts`); myData's for an id it does not know.
  static WidgetBuilder forApp(String id) => switch (id) {
    'mycontacts' => contacts,
    'mycalendar' => calendar,
    'myassistant' => assistant,
    _ => mydata,
  };

  static Widget mydata(BuildContext context) => const _SceneWindow(
    sections: ['Status', 'Import', 'Settings'],
    icons: [MyDataIcon.status, MyDataIcon.download, MyDataIcon.settings],
    title: 'Status',
    child: _StatusScene(),
  );

  static Widget contacts(BuildContext context) => const _SceneWindow(
    sections: ['Contacts', 'Recently deleted', 'Review'],
    icons: [MyDataIcon.person, MyDataIcon.trash, MyDataIcon.review],
    title: 'Contacts',
    child: _ContactsScene(),
  );

  static Widget calendar(BuildContext context) => const _SceneWindow(
    sections: ['Month', 'Calendars'],
    icons: [MyDataIcon.calendarMonth, MyDataIcon.list],
    title: 'March 2026',
    child: _CalendarScene(),
  );

  static Widget assistant(BuildContext context) => const _SceneWindow(
    sections: ['Chat'],
    icons: [MyDataIcon.chat],
    title: 'myAssistant',
    child: _AssistantScene(),
  );
}

/// A window in small: the sidebar with the app's sections (the first selected), the toolbar band with the
/// title, and [child] on `surface`.
class _SceneWindow extends StatelessWidget {
  const _SceneWindow({required this.sections, required this.icons, required this.title, required this.child});

  final List<String> sections;
  final List<MyDataIcon> icons;
  final String title;
  final Widget child;

  static const sidebarWidth = 168.0;

  /// [sidebarWidth], widened in proportion where the theme's body is over 16 px (Large), as the Mac
  /// window's sidebar is (MacSidebar.width), so a section's name fits.
  static double sidebarWidthFor(BuildContext context) =>
      sidebarWidth * math.max(1, (context.typeScale.body.fontSize ?? 16) / 16);
  static const toolbarHeight = 52.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = BorderRadius.all(Radius.circular(context.radius.md));
    return ColoredBox(
      color: c.bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: sidebarWidthFor(context),
            color: c.sidebar,
            padding: EdgeInsets.fromLTRB(context.space(2), toolbarHeight, context.space(2), context.space(2)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sections.length; i++)
                  Padding(
                    padding: EdgeInsets.only(bottom: context.space(1)),
                    // The current section in the theme's selection style, as the frame marks it.
                    child: SelectionMark(
                      selected: i == 0,
                      borderRadius: r,
                      child: Builder(
                        builder: (context) => Padding(
                          padding: EdgeInsets.symmetric(horizontal: context.space(3), vertical: context.space(2)),
                          child: Row(
                            children: [
                              Icon(context.icon(icons[i]),
                                  size: context.density.icon,
                                  color: i == 0 ? (SelectionMark.of(context)?.foreground ?? c.accent) : c.inkMuted),
                              SizedBox(width: context.space(2)),
                              Expanded(
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: SelectionHighlight(
                                    child: Builder(
                                      builder: (context) => Text(
                                        sections[i],
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: context
                                            .type(i == 0 ? MyDataTypeRole.bodyStrong : MyDataTypeRole.body)
                                            .copyWith(color: context.colors.ink),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: toolbarHeight,
                  padding: EdgeInsets.symmetric(horizontal: context.space(5)),
                  alignment: AlignmentDirectional.centerStart,
                  decoration: BoxDecoration(
                    color: c.toolbar,
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  child: Text(title, style: context.type(MyDataTypeRole.heading).copyWith(color: c.ink)),
                ),
                Expanded(
                  child: ColoredBox(color: c.surface, child: child),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _noop() {}

class _ContactsScene extends StatelessWidget {
  const _ContactsScene();

  static const people = ['Ava Fictional', 'Ben Example', 'Chloé Sample', 'Dev Placeholder', 'Eli Testcase'];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = BorderRadius.all(Radius.circular(context.radius.md));
    final muted = context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 210,
          padding: EdgeInsets.all(context.space(2)),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: c.line)),
          ),
          child: Column(
            children: [
              for (var i = 0; i < people.length; i++)
                SelectionMark(
                  selected: i == 0,
                  borderRadius: r,
                  child: Builder(
                    builder: (context) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: context.space(2), vertical: context.space(2)),
                      child: Row(
                        children: [
                          if (Avatar.shown(context)) ...[Avatar(name: people[i]), SizedBox(width: context.space(2))],
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: SelectionHighlight(
                                child: Builder(
                                  builder: (context) => Text(
                                    people[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.type(MyDataTypeRole.body).copyWith(color: context.colors.ink),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          // What fits, as a window shows it (Large loses the last lines).
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              maxHeight: double.infinity,
              child: Padding(
            padding: EdgeInsets.all(context.space(6)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The name beside the avatar, or under it where a theme's title would not fit there whole
                // (Large): never broken mid-word.
                LayoutBuilder(builder: (context, box) {
                  final nameStyle = context.type(MyDataTypeRole.title).copyWith(color: c.ink);
                  final name = Text('Ava Fictional', style: nameStyle);
                  final avatar = [
                    if (Avatar.shown(context)) ...[
                      const Avatar(name: 'Ava Fictional', size: AvatarSize.large),
                      SizedBox(width: context.space(4)),
                    ],
                  ];
                  final word = (TextPainter(
                    text: TextSpan(text: 'Fictional', style: nameStyle),
                    textDirection: TextDirection.ltr,
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout()).width;
                  final label = (TextPainter(
                    text: TextSpan(text: 'Edit', style: Button.labelStyle(context)),
                    textDirection: TextDirection.ltr,
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout()).width;
                  final edit = context.isSystemLook
                      ? math.max(MyDataMacSize.pushButtonHeight * 3, label + 2 * context.space(3))
                      : math.max(context.density.controlHeight, label + 2 * Button.horizontalPadding(context.look));
                  final room = box.maxWidth -
                      (Avatar.shown(context) ? AvatarSize.large.diameter(context.look) + context.space(4) : 0) -
                      edit;
                  if (word <= room) {
                    return Row(children: [...avatar, Expanded(child: name), const Button(label: 'Edit', onPressed: _noop)]);
                  }
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [...avatar, const Spacer(), const Button(label: 'Edit', onPressed: _noop)]),
                    SizedBox(height: context.space(2)),
                    name,
                  ]);
                }),
                SizedBox(height: context.space(6)),
                Text('Email', style: muted),
                Text('ava@example.org', style: context.type(MyDataTypeRole.body).copyWith(color: c.link)),
                SizedBox(height: context.space(3)),
                Text('Phone', style: muted),
                Text('+44 7700 900123', style: context.type(MyDataTypeRole.body).copyWith(color: c.ink)),
                SizedBox(height: context.space(3)),
                Text('Birthday', style: muted),
                Text('18 March', style: context.type(MyDataTypeRole.body).copyWith(color: c.ink)),
              ],
            ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarScene extends StatelessWidget {
  const _CalendarScene();

  /// The event's colour mark at its start edge.
  static const markWidth = 3.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final small = context.type(MyDataTypeRole.caption);
    // 1 March 2026 is a Sunday and the week starts on Monday, so the first row opens on 23 February and
    // six rows reach 5 April.
    const lead = 6;
    const today = 18;
    final events = <int, (String, Color)>{
      3: ('Dentist', c.dataBlue),
      11: ('Book club', c.dataPurple),
      18: ('Lunch with Ava', c.dataGreen),
      20: ('Housewarming', c.dataOrange),
      26: ('Flight', c.dataRed),
    };
    final patterns = context.variants.dataColours == DataColourStyle.pattern;
    Widget day(int n) {
      final inMonth = n >= 1 && n <= 31;
      final label = inMonth ? '$n' : '${n < 1 ? 28 + n : n - 31}';
      final event = inMonth ? events[n] : null;
      return Container(
        padding: EdgeInsets.all(context.space(1)),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: c.line),
            left: BorderSide(color: c.line),
          ),
        ),
        // What fits, as a month cell shows it: a theme with larger type (Large) shows the day and loses the
        // event, never overflowing the cell.
        child: ClipRect(
          child: OverflowBox(
            alignment: AlignmentDirectional.topStart,
            maxHeight: double.infinity,
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: context.space(1)),
              decoration: n == today
                  ? context.radius.decorate(BoxDecoration(color: c.accent, borderRadius: BorderRadius.all(Radius.circular(context.radius.pill))))
                  : null,
              child: Text(
                label,
                style: small.copyWith(color: n == today ? c.onAccent : (inMonth ? c.ink : c.inkMuted)),
              ),
            ),
            if (event != null)
              Container(
                margin: EdgeInsets.only(top: context.space(1)),
                padding: EdgeInsets.symmetric(horizontal: context.space(1)),
                // A theme that draws calendars as patterns (E-ink) shows no colour: a grey chip, an ink mark.
                decoration: BoxDecoration(
                  color: patterns ? c.surfaceSunken : event.$2.withValues(alpha: 0.18),
                  border: BorderDirectional(
                    start: BorderSide(color: patterns ? c.ink : event.$2, width: markWidth),
                  ),
                ),
                child: Text(
                  event.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: small.copyWith(color: c.ink),
                ),
              ),
          ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(context.space(3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final d in const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
                Expanded(
                  child: Text(d, style: small.copyWith(color: c.inkMuted)),
                ),
            ],
          ),
          SizedBox(height: context.space(1)),
          for (var week = 0; week < 6; week++)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (var d = 0; d < 7; d++) Expanded(child: day(week * 7 + d + 1 - lead))],
              ),
            ),
        ],
      ),
    );
  }
}

class _AssistantScene extends StatelessWidget {
  const _AssistantScene();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = BorderRadius.all(Radius.circular(context.radius.lg));
    final body = context.type(MyDataTypeRole.body);
    return Padding(
      padding: EdgeInsets.all(context.space(5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: context.space(4), vertical: context.space(2)),
              decoration: context.radius.decorate(BoxDecoration(color: c.accent, borderRadius: r)),
              child: Text("What's on Friday?", style: body.copyWith(color: c.onAccent)),
            ),
          ),
          SizedBox(height: context.space(4)),
          Container(
            padding: EdgeInsets.all(context.space(4)),
            decoration: context.radius.decorate(BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: r,
              border: Border.all(color: c.line),
            )),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fri 20 Mar 2026: 2 events',
                  style: context.type(MyDataTypeRole.bodyStrong).copyWith(color: c.ink),
                ),
                SizedBox(height: context.space(2)),
                for (final (time, what, colour) in [
                  ('09:30', 'Dentist', c.dataBlue),
                  ('18:00', 'Housewarming at Ava’s', c.dataOrange),
                ])
                  Padding(
                    padding: EdgeInsets.only(bottom: context.space(1)),
                    child: Row(
                      children: [
                        // No colour where calendars are patterns (E-ink).
                        Container(
                            width: 3,
                            height: 18,
                            color: context.variants.dataColours == DataColourStyle.pattern ? c.ink : colour),
                        SizedBox(width: context.space(2)),
                        Text(time, style: body.copyWith(color: c.inkMuted)),
                        SizedBox(width: context.space(3)),
                        Text(what, style: body.copyWith(color: c.ink)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: context.space(4), vertical: context.space(3)),
            decoration: context.radius.decorate(BoxDecoration(
              color: c.surfaceSunken,
              borderRadius: BorderRadius.all(Radius.circular(context.radius.pill)),
            )),
            child: Text('Ask about your contacts and calendar', style: body.copyWith(color: c.inkMuted)),
          ),
        ],
      ),
    );
  }
}

class _StatusScene extends StatelessWidget {
  const _StatusScene();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final r = BorderRadius.all(Radius.circular(context.radius.lg));
    final caption = context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted);
    Widget card(MyDataIcon icon, String title, String line, Widget trailing) => Container(
      margin: EdgeInsets.only(bottom: context.space(3)),
      padding: EdgeInsets.all(context.space(4)),
      decoration: context.radius.decorate(BoxDecoration(color: c.surfaceRaised, borderRadius: r, boxShadow: context.shadows.shadow1)),
      foregroundDecoration: MyDataEdgesPaint.cardEdge(context.look, r),
      child: Row(
        children: [
          IconTile(icon: icon),
          SizedBox(width: context.space(3)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.type(MyDataTypeRole.bodyStrong).copyWith(color: c.ink)),
                Text(line, style: caption),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
    // What fits, as a window shows it: a theme with larger type and rows (Large) loses the last lines.
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: Padding(
      padding: EdgeInsets.all(context.space(5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          card(
            MyDataIcon.host,
            'Host',
            'Running on this Mac',
            const MyDataBadge('Running', tone: MyDataTone.success),
          ),
          card(MyDataIcon.person, 'Contacts', '248 contacts, 3 sources', const SizedBox.shrink()),
          card(MyDataIcon.assistant, 'Assistant', 'Answers on this computer', const SwitchTrack(value: true)),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: Button(label: 'Import contacts…', variant: ButtonVariant.filled, onPressed: _noop),
          ),
        ],
      ),
        ),
      ),
    );
  }
}
