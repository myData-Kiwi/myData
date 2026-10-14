import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../generated/tokens.g.dart';
import '../motion.dart';
import '../theme.dart';
import 'button.dart';
import 'floating_bar.dart';
import 'grouped_list.dart' show GroupedRow;
import 'kiwi.dart';
import 'pressable.dart';

/// Which of the three window layouts a width gets (design/platforms.md "Window layouts").
enum AppLayout {
  /// Under 600px: one column, the sections in a floating tab bar at the bottom.
  phone,

  /// 600 to 1024px: the sections in a slim rail.
  rail,

  /// Over 1024px: a `sidebar-width` sidebar on `surface`, then the content.
  sidebar;

  /// The narrowest width that is not a phone.
  static const railMin = 600.0;

  /// The widest width that still gets the rail; anything wider gets the sidebar.
  static const railMax = 1024.0;

  static AppLayout forWidth(double width) => width < railMin ? phone : (width <= railMax ? rail : sidebar);

  /// The layout for the window this [context] is in.
  static AppLayout of(BuildContext context) => forWidth(MediaQuery.sizeOf(context).width);
}

/// One of an app's own top-level sections ("Library", "Albums"), as the frame lists it.
@immutable
class AppSection {
  const AppSection({required this.icon, required this.label});

  /// Drawn at `icon` size. The icon set is not drawn yet; pass a Material outlined or rounded icon.
  final IconData icon;

  /// One short word in sentence case, so it also fits the rail and the phone tab bar.
  final String label;
}

/// The three states of the app's link to the host, shown at the bottom of the sidebar.
enum AppConnectionState { connected, starting, unreachable }

/// What the frame says about the host (design/platforms.md "Each app's frame" and "Offline and errors").
@immutable
class AppConnection {
  /// "Connected to your host", with the `brand` dot. [onOpenMyData] adds an "Open myData" link; the myData
  /// app itself passes none.
  const AppConnection.connected({this.onOpenMyData})
      : state = AppConnectionState.connected,
        onRetry = null,
        lastUpdated = null;

  /// "Starting your host", with the loading kiwi.
  const AppConnection.starting()
      : state = AppConnectionState.starting,
        onOpenMyData = null,
        onRetry = null,
        lastUpdated = null;

  /// A `warning` line, "Cannot reach your host", with a tonal Retry button.
  ///
  /// [lastUpdated] says how old the data on screen is ("Last updated at 09:12"), shown as a caption under the
  /// warning line; the app writes it, the frame only places it. [onRetry] null disables the button while a
  /// retry is under way, and the frame says so next to it ([retryingText]).
  const AppConnection.unreachable({required this.onRetry, this.lastUpdated})
      : state = AppConnectionState.unreachable,
        onOpenMyData = null;

  final AppConnectionState state;
  final VoidCallback? onOpenMyData;
  final VoidCallback? onRetry;

  /// When the data the app shows was last updated from the host, in a full sentence. Null for none.
  final String? lastUpdated;

  /// A retry is under way: the Retry button is disabled.
  bool get retrying => state == AppConnectionState.unreachable && onRetry == null;

  static const connectedText = 'Connected to your host';
  static const openMyDataText = 'Open myData';
  static const startingText = 'Starting your host';
  static const unreachableText = 'Cannot reach your host';
  static const retryText = 'Retry';

  /// The reason the Retry button is disabled, next to it.
  static const retryingText = 'Trying to reach your host';

  /// The rail's short word for [connectedText]; the full sentence is its tooltip and accessible name.
  static const connectedShortText = 'Connected';

  /// The rail's short words for [retryingText]; the full sentence is its tooltip and accessible name.
  static const retryingShortText = 'Trying again';
}

/// The frame every app window shares (design/platforms.md "Window layouts" and "Each app's frame").
///
/// - **Over 1024px:** a `sidebar-width` sidebar on `surface` (no border; the content area is `bg`). At its
///   top the [appName] in the `title` style, then the app's own [sections] as rows, and at the bottom the
///   [connection]. No logo: the kiwi lives in the app icon, empty screens and loading only.
/// - **600 to 1024px:** a slim rail on `surface` with each section as an icon over a short label, and a
///   compact connection at the bottom.
/// - **Under 600px:** the [appName] is the large title at the top of the screen, in `display-xl`, and stays
///   there while the content scrolls under it; a [PageScaffold] inside shows its section title under it in
///   the `title` style, or none when it is the app name ([phoneAppNameOf]). The sections are in a
///   [FloatingBar] at the bottom (five at most), with content scrolling beneath it. The connection shows
///   only when it needs attention (starting or unreachable), as a line under the app name.
/// - **Unreachable**, in every layout: the warning line, the [AppConnection.lastUpdated] caption under it
///   when the app has one, and the Retry button; while a retry runs, the disabled button has the reason next
///   to it.
/// - The current section is an `accent-soft` pill with `accent` text; the others are `ink-muted`. Rows fill
///   with `surface-hover` on hover and draw the focus ring with the keyboard. Tab reaches every row; the
///   up and down arrows move between them (Home and End to the ends); Enter and Space open one.
/// - The window's title bar and its controls stay the platform's.
///
/// The frame holds no state: [current] says which section is showing and [onSelect] is called with the
/// index the user picked.
class AppFrame extends StatelessWidget {
  const AppFrame({
    super.key,
    required this.appName,
    required this.sections,
    required this.current,
    required this.onSelect,
    required this.child,
    this.connection = const AppConnection.connected(),
  });

  /// Written exactly: "myPhotos", "myAssistant".
  final String appName;

  /// The app's own sections only; no app lists the other apps.
  final List<AppSection> sections;

  /// The index in [sections] of the section showing.
  final int current;

  final ValueChanged<int> onSelect;

  /// The current section's content, usually a [PageScaffold].
  final Widget child;

  final AppConnection connection;

  /// The rail's width. No token: wide enough for a one-word `caption` label and the tonal Retry button.
  static const railWidth = 96.0;

  /// Between section rows: the preview's 2px, rounded to the nearest token.
  static const rowGap = MyDataSpace.s1;

  /// The app name when [context] is in a phone frame, under the frame's large title, so a [PageScaffold]
  /// there shows its own title smaller; null anywhere else.
  static String? phoneAppNameOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PhoneTitleScope>()?.appName;

  @override
  Widget build(BuildContext context) {
    assert(sections.isEmpty || (current >= 0 && current < sections.length), 'current must index sections');
    final c = context.colors;
    return Material(
      color: c.bg,
      child: LayoutBuilder(builder: (context, constraints) {
        final layout = AppLayout.forWidth(constraints.maxWidth);
        return switch (layout) {
          AppLayout.sidebar => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Sidebar(frame: this),
              Expanded(child: child),
            ]),
          AppLayout.rail => Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _Rail(frame: this),
              Expanded(child: child),
            ]),
          AppLayout.phone => _Phone(frame: this),
        };
      }),
    );
  }
}

/// The desktop sidebar.
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.frame});
  final AppFrame frame;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: MyDataSize.sidebarWidth,
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: MyDataSpace.s4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          // Lines the name up with the row labels: the list's inset plus the row's own.
          padding: const EdgeInsets.fromLTRB(
              MyDataSpace.s3 + MyDataSpace.s3, MyDataSpace.s2, MyDataSpace.s3 + MyDataSpace.s3, MyDataSpace.s4),
          child: Semantics(
            header: true,
            child: Text(frame.appName,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: MyDataType.title.copyWith(color: c.ink)),
          ),
        ),
        Expanded(
          child: _SectionNav(frame: frame, rail: false),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(MyDataSpace.s3 + MyDataSpace.s3, MyDataSpace.s3, MyDataSpace.s3, 0),
          child: _ConnectionLine(connection: frame.connection),
        ),
      ]),
    );
  }
}

/// The slim rail for medium widths.
class _Rail extends StatelessWidget {
  const _Rail({required this.frame});
  final AppFrame frame;

  @override
  Widget build(BuildContext context) => Container(
        width: AppFrame.railWidth,
        color: context.colors.surface,
        padding: const EdgeInsets.symmetric(vertical: MyDataSpace.s4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: _SectionNav(frame: frame, rail: true)),
          Padding(
            padding: const EdgeInsets.fromLTRB(MyDataSpace.s2, MyDataSpace.s3, MyDataSpace.s2, 0),
            child: _RailConnection(connection: frame.connection),
          ),
        ]),
      );
}

/// The section rows of the sidebar or the rail, with arrow-key movement between them.
class _SectionNav extends StatefulWidget {
  const _SectionNav({required this.frame, required this.rail});
  final AppFrame frame;
  final bool rail;

  @override
  State<_SectionNav> createState() => _SectionNavState();
}

class _SectionNavState extends State<_SectionNav> {
  final List<FocusNode> _nodes = [];

  void _syncNodes() {
    final n = widget.frame.sections.length;
    while (_nodes.length > n) {
      _nodes.removeLast().dispose();
    }
    while (_nodes.length < n) {
      _nodes.add(FocusNode(debugLabel: 'AppFrame section ${_nodes.length}'));
    }
  }

  @override
  void initState() {
    super.initState();
    _syncNodes();
  }

  @override
  void didUpdateWidget(_SectionNav old) {
    super.didUpdateWidget(old);
    _syncNodes();
  }

  @override
  void dispose() {
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final focused = _nodes.indexWhere((n) => n.hasPrimaryFocus);
    if (focused < 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final last = _nodes.length - 1;
    final int target;
    if (key == LogicalKeyboardKey.arrowDown) {
      target = focused == last ? 0 : focused + 1;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      target = focused == 0 ? last : focused - 1;
    } else if (key == LogicalKeyboardKey.home) {
      target = 0;
    } else if (key == LogicalKeyboardKey.end) {
      target = last;
    } else {
      return KeyEventResult.ignored;
    }
    _nodes[target].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.frame;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: f.appName,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onKeyEvent: _onKey,
        child: SingleChildScrollView(
          // Inside the scroll view, so the focus ring is not clipped at the edges.
          padding: EdgeInsets.symmetric(
              horizontal: widget.rail ? MyDataSpace.s2 : MyDataSpace.s3, vertical: MyDataSpace.s1),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < f.sections.length; i++) ...[
              if (i > 0) const SizedBox(height: AppFrame.rowGap),
              widget.rail
                  ? _RailItem(
                      section: f.sections[i], current: i == f.current, focusNode: _nodes[i], onPressed: () => f.onSelect(i))
                  : _SidebarRow(
                      section: f.sections[i], current: i == f.current, focusNode: _nodes[i], onPressed: () => f.onSelect(i)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// A sidebar row: icon and label on a `control-height` pill.
class _SidebarRow extends StatelessWidget {
  const _SidebarRow({required this.section, required this.current, required this.focusNode, required this.onPressed});
  final AppSection section;
  final bool current;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = current ? c.accent : c.inkMuted;
    return AnimatedContainer(
      duration: MyDataMotion.fast,
      curve: MyDataMotion.standard,
      decoration: BoxDecoration(color: current ? c.accentSoft : c.accentSoft.withValues(alpha: 0), borderRadius: MyDataRadii.pill),
      child: Pressable(
        onPressed: onPressed,
        focusNode: focusNode,
        borderRadius: MyDataRadii.pill,
        scaleOnPress: false,
        hoverFill: current ? c.ink.withValues(alpha: GroupedRow.selectedHoverInk) : c.surfaceHover,
        selected: current,
        semanticLabel: section.label,
        child: ExcludeSemantics(
          child: Container(
            height: MyDataSize.controlHeight,
            padding: const EdgeInsets.symmetric(horizontal: MyDataSpace.s3),
            child: Row(children: [
              Icon(section.icon, size: MyDataSize.icon, color: fg),
              const SizedBox(width: MyDataSpace.s3),
              Expanded(
                child: Text(
                  section.label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: (current ? MyDataType.bodyStrong : MyDataType.body).copyWith(color: fg),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A rail item: the icon on a small pill (`accent-soft` when current) over a one-word `caption` label.
class _RailItem extends StatelessWidget {
  const _RailItem({required this.section, required this.current, required this.focusNode, required this.onPressed});
  final AppSection section;
  final bool current;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  /// The pill behind the icon. No token: `row-height` across and `space-8` down, like a tab bar's pill.
  static const indicatorWidth = MyDataSize.rowHeight;
  static const indicatorHeight = MyDataSpace.s8;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = current ? c.accent : c.inkMuted;
    return Pressable(
      onPressed: onPressed,
      focusNode: focusNode,
      borderRadius: MyDataRadii.md,
      scaleOnPress: false,
      hoverFill: c.surfaceHover,
      selected: current,
      semanticLabel: section.label,
      tooltip: section.label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MyDataSpace.s1),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: MyDataMotion.fast,
              curve: MyDataMotion.standard,
              width: indicatorWidth,
              height: indicatorHeight,
              decoration: BoxDecoration(
                  color: current ? c.accentSoft : c.accentSoft.withValues(alpha: 0), borderRadius: MyDataRadii.pill),
              alignment: Alignment.center,
              child: Icon(section.icon, size: MyDataSize.icon, color: fg),
            ),
            const SizedBox(height: MyDataSpace.s1),
            Text(
              section.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: (current ? MyDataType.label : MyDataType.caption).copyWith(color: fg),
            ),
          ]),
        ),
      ),
    );
  }
}

/// The phone layout: the app name as the large title, a line under it when the host needs attention, and
/// the content under a floating tab bar.
class _Phone extends StatelessWidget {
  const _Phone({required this.frame});
  final AppFrame frame;

  @override
  Widget build(BuildContext context) {
    final f = frame;
    assert(f.sections.length <= FloatingBar.maxItems,
        'A phone tab bar holds ${FloatingBar.maxItems} sections at most; this app has ${f.sections.length}.');
    final c = context.colors;
    final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SafeArea(
        bottom: false,
        child: Padding(
          // The page's own phone padding at the sides, so the title lines up with the content.
          padding: const EdgeInsets.fromLTRB(MyDataSpace.s4, MyDataSpace.s4, MyDataSpace.s4, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Semantics(
              header: true,
              child: Text(f.appName,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: MyDataType.displayXl.copyWith(color: c.ink)),
            ),
            if (f.connection.state != AppConnectionState.connected) ...[
              const SizedBox(height: MyDataSpace.s2),
              _ConnectionLine(connection: f.connection, inline: true),
            ],
          ]),
        ),
      ),
      Expanded(
        // Below the tab bar's host, so the bar's bottom clearance reaches the content.
        child: Builder(
          builder: (context) => MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: _PhoneTitleScope(appName: f.appName, child: f.child),
          ),
        ),
      ),
    ]);
    // One section needs no tab bar.
    if (f.sections.length < 2) return content;
    return FloatingBarHost(
      bar: FloatingBar(
        semanticLabel: f.appName,
        current: f.current,
        items: [
          for (var i = 0; i < f.sections.length; i++)
            FloatingBarItem(label: f.sections[i].label, icon: f.sections[i].icon, onPressed: () => f.onSelect(i)),
        ],
      ),
      child: content,
    );
  }
}

/// Tells a [PageScaffold] that the phone frame above it already shows the app name as the large title.
class _PhoneTitleScope extends InheritedWidget {
  const _PhoneTitleScope({required this.appName, required super.child});
  final String appName;

  @override
  bool updateShouldNotify(_PhoneTitleScope oldWidget) => appName != oldWidget.appName;
}

/// The connection at the bottom of the sidebar, or [inline] on one line at the top of a phone screen.
class _ConnectionLine extends StatelessWidget {
  const _ConnectionLine({required this.connection, this.inline = false});
  final AppConnection connection;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final muted = MyDataType.caption.copyWith(color: c.inkMuted);
    switch (connection.state) {
      case AppConnectionState.connected:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          _lead(const _HostDot(), Text(AppConnection.connectedText, style: muted)),
          if (connection.onOpenMyData != null)
            Padding(
              // Under the words, not the dot.
              padding: const EdgeInsetsDirectional.only(start: MyDataSize.icon + MyDataSpace.s2),
              child: _Link(label: AppConnection.openMyDataText, onTap: connection.onOpenMyData!),
            ),
        ]);
      case AppConnectionState.starting:
        return Semantics(
          liveRegion: true,
          child: SizedBox(
            height: MyDataSize.controlHeight,
            child: _lead(const KiwiLoader(size: _HostDot.loaderSize, semanticLabel: AppConnection.startingText),
                ExcludeSemantics(child: Text(AppConnection.startingText, style: muted))),
          ),
        );
      case AppConnectionState.unreachable:
        final line = _lead(
          Icon(Icons.warning_amber_rounded, size: MyDataSize.icon, color: c.warning),
          Text(AppConnection.unreachableText, style: MyDataType.label.copyWith(color: c.warning)),
        );
        // Captions under the words, not the icon.
        Widget caption(String text) => Padding(
              padding: const EdgeInsetsDirectional.only(start: MyDataSize.icon + MyDataSpace.s2),
              child: Text(text, style: muted),
            );
        final updated = connection.lastUpdated;
        final retry = Button(label: AppConnection.retryText, onPressed: connection.onRetry);
        return Semantics(
          liveRegion: true,
          container: true,
          explicitChildNodes: true,
          child: inline
              ? Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      line,
                      if (updated != null) caption(updated),
                      if (connection.retrying) caption(AppConnection.retryingText),
                    ]),
                  ),
                  const SizedBox(width: MyDataSpace.s3),
                  retry,
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  line,
                  if (updated != null) caption(updated),
                  const SizedBox(height: MyDataSpace.s2),
                  Row(children: [
                    retry,
                    if (connection.retrying) ...[
                      const SizedBox(width: MyDataSpace.s2),
                      Flexible(child: Text(AppConnection.retryingText, style: muted)),
                    ],
                  ]),
                ]),
        );
    }
  }

  /// [leading] centred in a `icon`-wide slot, so the dot, loader and warning icon line up with the row icons.
  Widget _lead(Widget leading, Widget text) => Row(children: [
        SizedBox(width: MyDataSize.icon, child: Center(child: leading)),
        const SizedBox(width: MyDataSpace.s2),
        Flexible(child: text),
      ]);
}

/// The rail's compact connection: the same states, stacked and centred.
class _RailConnection extends StatelessWidget {
  const _RailConnection({required this.connection});
  final AppConnection connection;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final muted = MyDataType.caption.copyWith(color: c.inkMuted);
    const gap = SizedBox(height: MyDataSpace.s1);
    return switch (connection.state) {
      AppConnectionState.connected => Column(mainAxisSize: MainAxisSize.min, children: [
          Tooltip(
            message: AppConnection.connectedText,
            child: Semantics(
              label: AppConnection.connectedText,
              child: ExcludeSemantics(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const _HostDot(),
                  gap,
                  Text(AppConnection.connectedShortText, style: muted, textAlign: TextAlign.center),
                ]),
              ),
            ),
          ),
          if (connection.onOpenMyData != null)
            _Link(label: AppConnection.openMyDataText, onTap: connection.onOpenMyData!, center: true),
        ]),
      AppConnectionState.starting => Semantics(
          liveRegion: true,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const KiwiLoader(size: _HostDot.loaderSize, semanticLabel: AppConnection.startingText),
            gap,
            ExcludeSemantics(child: Text(AppConnection.startingText, style: muted, textAlign: TextAlign.center)),
          ]),
        ),
      AppConnectionState.unreachable => Semantics(
          liveRegion: true,
          container: true,
          explicitChildNodes: true,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning_amber_rounded, size: MyDataSize.icon, color: c.warning),
            gap,
            Text(AppConnection.unreachableText,
                textAlign: TextAlign.center, style: MyDataType.label.copyWith(color: c.warning)),
            if (connection.lastUpdated != null) ...[
              gap,
              Text(connection.lastUpdated!, style: muted, textAlign: TextAlign.center),
            ],
            const SizedBox(height: MyDataSpace.s2),
            Button(label: AppConnection.retryText, onPressed: connection.onRetry),
            if (connection.retrying) ...[
              gap,
              Tooltip(
                message: AppConnection.retryingText,
                child: Semantics(
                  label: AppConnection.retryingText,
                  child: ExcludeSemantics(
                    child: Text(AppConnection.retryingShortText, style: muted, textAlign: TextAlign.center),
                  ),
                ),
              ),
            ],
          ]),
        ),
    };
  }
}

/// The host's status dot: `brand`, the only place the kiwi green appears in the interface.
class _HostDot extends StatelessWidget {
  const _HostDot();

  /// The host chip's dot (MyDataBadge.dotSize).
  static const size = 8.0;

  /// The loader that stands in for the dot while the host starts: the `space-6` badge, a little larger
  /// than an icon so the kiwi can be made out.
  static const loaderSize = MyDataSpace.s6;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: context.colors.brand, shape: BoxShape.circle),
      );
}

/// A link: `accent`, underlined (design/README.md "Links"), with a control-height target.
class _Link extends StatelessWidget {
  const _Link({required this.label, required this.onTap, this.center = false});
  final String label;
  final VoidCallback onTap;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      link: true,
      child: Pressable(
        onPressed: onTap,
        button: false,
        scaleOnPress: false,
        borderRadius: MyDataRadii.sm,
        semanticLabel: label,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: MyDataSize.controlHeight, minWidth: MyDataSize.controlHeight),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              alignment: center ? Alignment.center : AlignmentDirectional.centerStart,
              child: Text(
                label,
                textAlign: center ? TextAlign.center : TextAlign.start,
                style: MyDataType.caption.copyWith(
                  color: c.accent,
                  decoration: TextDecoration.underline,
                  decorationColor: c.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
