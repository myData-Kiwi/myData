import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../accessibility.dart';
import '../generated/tokens.g.dart';
import '../widgets/app_frame.dart' show AppConnection, AppConnectionState, AppSection;
import 'mac_chrome.dart';
import 'mac_theme.dart';

/// The Mac frame's sidebar: the app's sections as a source list, under the window's close, minimise and zoom
/// buttons, with the host's state at the bottom (the plan's "status only when something is wrong": one quiet
/// line while connected).
///
/// - **Ground.** Translucent through [MacChrome.sidebar] (the window's sidebar material); `sidebar-background`
///   where it cannot be (reduced transparency, tests).
/// - **Rows** are `sidebar-row-height` tall, inset `row-inset` from the sides: a 16pt icon in the accent, the
///   label in `body`, a count after it in `caption` and `secondary-label` (Review's). The current section has
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
  });

  final List<AppSection> sections;
  final int current;
  final ValueChanged<int> onSelect;
  final AppConnection connection;

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
    final mac = context.mac;
    final chrome = MacChrome.of(context);
    final solid = chrome.sidebar == null || MyDataAccessibility.of(context).reduceTransparency;
    Widget list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The window's close, minimise and zoom buttons sit here, in the toolbar's band.
        const SizedBox(height: MyDataMacSize.toolbarHeight),
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
        const Spacer(),
        _ConnectionLine(connection: widget.connection),
      ],
    );
    list = SizedBox(width: MyDataMacSize.sidebarWidth, child: list);
    if (solid) return ColoredBox(color: mac.sidebarBackground, child: list);
    return chrome.sidebar!(list);
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
    final icon = emphasised ? mac.onAccent : (windowActive ? mac.accent : mac.secondaryLabel);
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
                  const SizedBox(width: MyDataSpace.s2),
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

/// The host's state in one line at the bottom of the sidebar: "Connected" with Open myData, "Starting your
/// host", or "Cannot reach your host" with Retry and when the list was read.
class _ConnectionLine extends StatelessWidget {
  const _ConnectionLine({required this.connection});

  final AppConnection connection;

  @override
  Widget build(BuildContext context) {
    final mac = context.mac;
    final c = connection;
    final (text, action, onAction) = switch (c.state) {
      AppConnectionState.connected => (AppConnection.connectedShortText, AppConnection.openMyDataText, c.onOpenMyData),
      AppConnectionState.starting => (AppConnection.startingText, null, null),
      AppConnectionState.unreachable when c.retrying => (AppConnection.retryingText, null, null),
      AppConnectionState.unreachable => (AppConnection.unreachableText, AppConnection.retryText, c.onRetry),
    };
    final style = MyDataMacType.caption.copyWith(color: mac.secondaryLabel);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          MyDataMacSize.rowInset + MyDataMacSize.rowPadding, MyDataSpace.s2, MyDataMacSize.rowInset, MyDataSpace.s3),
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
