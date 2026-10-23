import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import '../widgets/app_frame.dart' show AppConnection, AppConnectionState, AppSection;
import 'mac_chrome.dart';
import 'mac_theme.dart';

/// The Mac frame's sidebar: the app's sections as a source list in a [MacSidebar] panel, under the window's
/// close, minimise and zoom buttons, with the host's state at the bottom only when something is wrong (the plan's "status only when
/// something is wrong": nothing while connected).
///
/// - **Shape.** macOS 26's floating sidebar: a panel `sidebar-margin` in from the window's left, top and
///   bottom edges, with `sidebar` corners and a `separator` outline, in a `sidebar-width` column; around it
///   the content's ground (`content-background`), as the window's content runs under the panel.
/// - **Ground.** Translucent through [MacChrome.sidebar] (the window's sidebar material, showing through the
///   panel's rounded shape); `sidebar-background` where it cannot be (reduced transparency, tests). Flutter
///   cannot draw Liquid Glass: the panel is the material or a flat colour, never glass.
/// - **Rows** are `sidebar-row-height` tall, inset `row-inset` from the sides: a 16pt icon in `label`, the
///   label in `body`, a count after it in `caption` and `secondary-label` when given. The current section has
///   the `sidebar-selection` fill; while the list has keyboard focus the fill is the accent and the row's
///   icon and text are `on-accent`, as in Finder. In an inactive window the icons are `secondary-label`.
/// - **Keys.** One Tab stop; Up and Down change the section at once.
/// - No app name is typed in the sidebar (plan section 5, "The system's chrome").
class MacSourceList extends StatefulWidget {
  const MacSourceList({
    super.key,
    required this.sections,
    required this.current,
    required this.onSelect,
    required this.connection,
    this.showConnection = true,
  });

  final List<AppSection> sections;
  final int current;
  final ValueChanged<int> onSelect;
  final AppConnection connection;

  /// False while the content already says the host cannot be reached (with its one Retry): the line at the
  /// bottom would say it twice.
  final bool showConnection;

  @override
  State<MacSourceList> createState() => _MacSourceListState();
}

class _MacSourceListState extends State<MacSourceList> {
  final _focus = FocusNode(debugLabel: 'Sidebar');
  bool _focused = false;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final last = widget.sections.length - 1;
    final to = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => math.min(last, widget.current + 1),
      LogicalKeyboardKey.arrowUp => math.max(0, widget.current - 1),
      _ => null,
    };
    if (to == null) return KeyEventResult.ignored;
    if (to != widget.current) widget.onSelect(to);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final chrome = MacChrome.of(context);
    return MacSidebar(
      connection: widget.connection,
      showConnection: widget.showConnection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            focusNode: _focus,
            onKeyEvent: _onKey,
            onFocusChange: (f) => setState(() => _focused = f),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < widget.sections.length; i++)
                  _Row(
                    section: widget.sections[i],
                    current: i == widget.current,
                    emphasised: i == widget.current && _focused && chrome.windowActive,
                    windowActive: chrome.windowActive,
                    onPressed: () {
                      _focus.requestFocus();
                      if (i != widget.current) widget.onSelect(i);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.section,
    required this.current,
    required this.emphasised,
    required this.windowActive,
    required this.onPressed,
  });

  final AppSection section;
  final bool current;
  final bool emphasised;
  final bool windowActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final ink = emphasised ? mac.onAccent : mac.label;
    // In the label colour, as macOS 26's sidebars draw an SF Symbol label (the SwiftUI prototype's live window).
    final icon = emphasised ? mac.onAccent : (windowActive ? mac.label : mac.secondaryLabel);
    final count = section.count;
    return Semantics(
      button: true,
      selected: current,
      label: count == null || count == 0 ? section.label : '${section.label}, $count${section.countMore ? '+' : ''}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MyDataMacSize.rowInset),
            child: Container(
              height: MyDataMacSize.sidebarRowHeight,
              padding: const EdgeInsets.symmetric(horizontal: MyDataMacSize.rowPadding),
              decoration: BoxDecoration(
                color: emphasised ? mac.accent : (current ? mac.sidebarSelection : null),
                borderRadius: const BorderRadius.all(Radius.circular(MyDataMacRadius.sidebarSelection)),
              ),
              child: Row(
                children: [
                  Icon(section.icon, size: MyDataMacSize.icon, color: icon),
                  SizedBox(width: context.space(2)),
                  Expanded(
                    child: Text(section.label,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: MyDataMacType.body.copyWith(color: ink)),
                  ),
                  if (count != null && count > 0)
                    Text('$count${section.countMore ? '+' : ''}',
                        style: MyDataMacType.caption.copyWith(color: emphasised ? mac.onAccent : mac.secondaryLabel)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Mac frame's sidebar panel around content of the app's own, for an app whose sidebar is not a list of
/// sections: myCalendar's calendar list, as Calendar.app's sidebar is. The same panel as [MacSourceList]
/// (macOS 26's floating sidebar: `sidebar-margin` in from the window's left, top and bottom edges, `sidebar`
/// corners, a `separator` outline, translucent through [MacChrome.sidebar] or `sidebar-background` where it
/// cannot be), the room for the window's close, minimise and zoom buttons at its top, and the host's state
/// at its bottom only when something is wrong. [child] fills the rest and scrolls itself.
///
/// [MacSourceList] draws its sections in this panel, so every app's sidebar is the same panel.
class MacSidebar extends StatelessWidget {
  const MacSidebar({super.key, required this.connection, required this.child, this.showConnection = true});

  final AppConnection connection;
  final Widget child;

  /// False: no connection line (the content says what is wrong).
  final bool showConnection;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final chrome = MacChrome.of(context);
    // A drawn theme paints its own `sidebar`: the window's material is System's.
    final solid = chrome.sidebar == null || MyDataAccessibility.of(context).reduceTransparency || !context.isSystemLook;
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: MyDataMacSize.toolbarHeight - MyDataMacSize.sidebarMargin),
        Expanded(child: child),
        if (showConnection) MacConnectionLine(connection: connection),
      ],
    );
    const margin = MyDataMacSize.sidebarMargin;
    const radius = BorderRadius.all(Radius.circular(MyDataMacRadius.sidebar));
    final panel = Padding(
      padding: const EdgeInsets.fromLTRB(margin, margin, 0, margin),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(borderRadius: radius, border: Border.all(color: mac.separator, width: MyDataMacSize.hairline)),
        child: ClipRRect(
          borderRadius: radius,
          child: solid
              ? DecoratedBox(decoration: BoxDecoration(color: mac.sidebarBackground, borderRadius: radius), child: list)
              : list,
        ),
      ),
    );
    final column = SizedBox(
      width: MyDataMacSize.sidebarWidth,
      child: CustomPaint(painter: _AroundPanel(color: mac.contentBackground), child: panel),
    );
    return solid ? column : chrome.sidebar!(column);
  }
}

/// The Mac frame's window with a [MacSidebar]: [sidebar] in the panel, then [child] on `content-background`.
/// With no [sidebar] (nothing to list yet: no source, the host not reached) or no [connection] (a build that
/// cannot have a host) [child] alone, which then says what is wrong; its toolbar leaves room for the
/// window's buttons ([MacToolbar.windowControls]). Put it in a Scaffold with a transparent background, so the
/// sidebar's material shows.
class MacSidebarFrame extends StatelessWidget {
  const MacSidebarFrame({super.key, required this.sidebar, required this.connection, required this.child});

  final Widget? sidebar;
  final AppConnection? connection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final content = ColoredBox(color: context.mac.contentBackground, child: child);
    final c = connection;
    final panel = sidebar;
    if (c == null || panel == null) return content;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MacSidebar(connection: c, child: panel),
        Expanded(child: content),
      ],
    );
  }
}

/// Paints [color] over the sidebar column except the rounded panel, so the window's material shows only
/// through the panel.
class _AroundPanel extends CustomPainter {
  const _AroundPanel({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const m = MyDataMacSize.sidebarMargin;
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTRB(m, m, size.width, size.height - m),
      const Radius.circular(MyDataMacRadius.sidebar),
    );
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(panel);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_AroundPanel old) => old.color != color;
}

/// The host's state in one line at the bottom of a Mac sidebar: nothing while connected, "Starting your
/// host", or "Cannot reach your host" with Retry and when the data on screen was read (as [MacSourceList]
/// writes it).
class MacConnectionLine extends StatelessWidget {
  const MacConnectionLine({super.key, required this.connection});

  final AppConnection connection;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final c = connection;
    if (c.state == AppConnectionState.connected && c.lastUpdated == null) return const SizedBox.shrink();
    final (text, action, onAction) = switch (c.state) {
      AppConnectionState.connected => (AppConnection.connectedShortText, AppConnection.openMyDataText, c.onOpenMyData),
      AppConnectionState.starting => (AppConnection.startingText, null, null),
      AppConnectionState.unreachable when c.retrying => (AppConnection.retryingText, null, null),
      AppConnectionState.unreachable => (AppConnection.unreachableText, AppConnection.retryText, c.onRetry),
    };
    final style = MyDataMacType.caption.copyWith(color: mac.secondaryLabel);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          MyDataMacSize.rowInset + MyDataMacSize.rowPadding, context.space(2), MyDataMacSize.rowInset, context.space(3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(text: text),
              if (action != null && onAction != null) ...[
                const TextSpan(text: ' · '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: Semantics(
                    link: true,
                    child: GestureDetector(
                      onTap: onAction,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text(action, style: style.copyWith(color: mac.accent)),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
            style: style,
          ),
          if (c.lastUpdated != null) Text(c.lastUpdated!, style: style),
        ],
      ),
    );
  }
}
