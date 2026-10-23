import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import '../theme.dart';
import '../widgets/kiwi.dart';
import '../widgets/pressable.dart';
import 'mac_icons.dart';
import 'mac_theme.dart';

/// What opens over a window in the Mac frame (docs/2026-10-23-plan.md section 5: "Restyled: Dialog (push
/// buttons, the default button in the accent), Inspector, and toasts"), drawn the way macOS 26 draws them.
/// The branded widgets keep their behaviour (keys, focus, waiting for the host, announcements) and hand their
/// parts here when [MacLook.of] is true:
///
/// - [MacAlert]: MyDataDialog as an alert sheet (NSAlert run as a sheet on macOS 26): it comes down from the
///   window's toolbar edge with no scrim over the window, the app's own icon ([MacAppIcon]), the title in
///   `body-emphasized`, the message in `callout`, then the buttons. The default button is in the accent; when
///   the action is destructive, Cancel is the default and the action a push button with red text (HIG Alerts).
/// - [MacMenuLook]: a Menu as a macOS menu: `menu` corners, rows `row-height` tall in `body`, the item under
///   the pointer or the keys on the accent with `on-accent` text, no second line on an item.
/// - [MacToastLook]: a Toast as a small floating panel on `window-background`.
abstract final class MacAlert {
  /// The alert's width.
  static const width = MyDataMacSize.alertWidth;

  /// Inside the panel.
  static const padding = MyDataSpace.s5;

  /// The app's icon at the top (an alert shows the app's icon).
  static const markSize = MyDataSpace.s12;

  /// The panel's corners: macOS 26's larger window corners.
  static const radius = BorderRadius.all(Radius.circular(MyDataMacRadius.sidebar));

  /// The panel: [title], [message], [content], [fields], the [failure] line, then [cancel] and [confirm].
  ///
  /// - **The default button** is [confirm], in the accent; with [destructive] it is [cancel] (Return and the
  ///   accent), and [confirm] is a push button with red text.
  /// - **Side by side** at equal widths, the default button at the trailing end; one button fills the width.
  ///   When one of [buttonLabels] would not fit its half, the buttons stack, the default one on top, as macOS
  ///   stacks an alert's long buttons.
  static Widget panel(
    BuildContext context, {
    required String title,
    String? message,
    Widget? content,
    Widget? fields,
    String? failure,
    Widget? cancel,
    required Widget confirm,
    bool destructive = false,
    List<String> buttonLabels = const [],
  }) {
    final mac = context.mac;
    final c = context.colors;
    final body = <Widget>[
      if (message != null) Text(message, style: MyDataMacType.callout.copyWith(color: mac.label)),
      ?content,
      ?fields,
    ];
    // Default last in a row, first in a stack.
    final byDefault = destructive && cancel != null ? [confirm, cancel] : [?cancel, confirm];
    return Container(
      width: width,
      padding: const EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: mac.windowBackground,
        borderRadius: radius,
        border: Border.all(color: mac.separator),
        boxShadow: context.shadows.shadow2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(alignment: AlignmentDirectional.centerStart, child: MacAppIcon.image(context, size: markSize)),
          const SizedBox(height: MyDataSpace.s3),
          Semantics(header: true, child: Text(title, style: MyDataMacType.bodyEmphasized.copyWith(color: mac.label))),
          if (body.isNotEmpty)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: MyDataSpace.s2),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < body.length; i++) ...[
                    if (i > 0) const SizedBox(height: MyDataSpace.s3),
                    body[i],
                  ],
                ]),
              ),
            ),
          if (failure != null) ...[
            const SizedBox(height: MyDataSpace.s3),
            Text(failure, style: MyDataMacType.callout.copyWith(color: c.danger)),
          ],
          const SizedBox(height: MyDataSpace.s5),
          if (_stacks(context, buttonLabels, byDefault.length))
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              for (final (i, b) in byDefault.reversed.indexed) ...[
                if (i > 0) const SizedBox(height: MyDataSpace.s2),
                b,
              ],
            ])
          else
            Row(children: [
              for (final (i, b) in byDefault.indexed) ...[
                if (i > 0) const SizedBox(width: MyDataSpace.s2),
                Expanded(child: b),
              ],
            ]),
        ],
      ),
    );
  }
}

/// The app's own icon, as an alert shows it: the image [MacShell] was given (each app passes its icon from
/// [MyDataAppIcons]), or the kiwi on its tile when none was.
class MacAppIcon extends InheritedWidget {
  const MacAppIcon({super.key, required this.icon, required super.child});

  final ImageProvider? icon;

  /// The app's icon at [size], or the kiwi tile.
  static Widget image(BuildContext context, {required double size}) {
    final icon = context.dependOnInheritedWidgetOfExactType<MacAppIcon>()?.icon;
    if (icon == null) return KiwiTile(size: size);
    return ExcludeSemantics(
      child: Image(image: icon, width: size, height: size, filterQuality: FilterQuality.medium),
    );
  }

  @override
  bool updateShouldNotify(MacAppIcon old) => old.icon != icon;
}

/// The four apps' icons at 256 px (rendered by design/assets/Logos/app-icons/make_icons.py), for
/// [MacShell.appIcon].
abstract final class MyDataAppIcons {
  static const mydata = AssetImage('assets/app_icons/mydata.png', package: 'mydata_ui');
  static const mycontacts = AssetImage('assets/app_icons/mycontacts.png', package: 'mydata_ui');
  static const mycalendar = AssetImage('assets/app_icons/mycalendar.png', package: 'mydata_ui');
  static const myassistant = AssetImage('assets/app_icons/myassistant.png', package: 'mydata_ui');
}

/// Whether an alert's [labels] are too wide for [count] buttons side by side: a push button's label in
/// `body` with its `space-3` padding each side, in its share of the panel's width.
bool _stacks(BuildContext context, List<String> labels, int count) {
  if (count < 2 || labels.isEmpty) return false;
  final share = (MacAlert.width - 2 * MacAlert.padding - (count - 1) * MyDataSpace.s2) / count;
  final painter = TextPainter(textDirection: TextDirection.ltr, textScaler: MediaQuery.textScalerOf(context));
  try {
    for (final l in labels) {
      painter.text = TextSpan(text: l, style: MyDataMacType.body);
      painter.layout();
      if (painter.width + 2 * MyDataSpace.s3 > share) return true;
    }
    return false;
  } finally {
    painter.dispose();
  }
}

/// A Menu's panel and items in the Mac frame.
abstract final class MacMenuLook {
  /// The panel's corners.
  static const radius = BorderRadius.all(Radius.circular(MyDataMacRadius.sidebarSelection));

  /// An item's highlight's corners.
  static const itemRadius = BorderRadius.all(Radius.circular(MyDataMacRadius.selection - MyDataMacSize.tight));

  /// Inside the panel, around the items.
  static const padding = EdgeInsets.all(MyDataSpace.s1 + 2 * MyDataMacSize.hairline);

  /// An item's text from the highlight's edge.
  static const itemInset = MyDataSpace.s2 + MyDataMacSize.tight;

  /// The panel: `window-background` with a `separator` hairline and `shadow-2`.
  static BoxDecoration panel(BuildContext context) {
    final mac = context.mac;
    return BoxDecoration(
      color: mac.windowBackground,
      borderRadius: radius,
      border: Border.all(color: mac.separator),
      boxShadow: context.shadows.shadow2,
    );
  }

  /// A help tag (the system's tooltip) on [child]: why a menu item is disabled.
  static Widget helpTag(BuildContext context, {required String message, required Widget child}) {
    final mac = context.mac;
    return Tooltip(
      message: message,
      waitDuration: helpTagDelay,
      excludeFromSemantics: true,
      textStyle: MyDataMacType.caption.copyWith(color: mac.label),
      decoration: BoxDecoration(
        color: mac.contentBackground,
        border: Border.all(color: mac.separator),
        borderRadius: const BorderRadius.all(Radius.circular(MyDataMacRadius.control)),
      ),
      child: child,
    );
  }

  /// How long the pointer rests before a help tag shows.
  static const helpTagDelay = Duration(milliseconds: 700);

  /// The separator between groups of items.
  static Widget separator(BuildContext context) => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: itemInset, vertical: MyDataSpace.s1),
        color: context.mac.separator,
      );

  /// One item's face: [label] in `body` on one line (a macOS menu item has no second line; a disabled item's
  /// reason is its [helpTag]), an optional [icon] before it, the [shortcut] or a check mark at the end.
  /// [active]: on the accent with `on-accent` text (the item under the pointer or the keys), as macOS
  /// highlights menu items; a destructive item keeps its `danger` text otherwise.
  static Widget item(
    BuildContext context, {
    required String label,
    IconData? icon,
    bool iconSpace = false,
    String? shortcut,
    bool checked = false,
    bool active = false,
    bool enabled = true,
    bool destructive = false,
  }) {
    final mac = context.mac;
    final c = context.colors;
    final on = active && enabled;
    final fg = on ? mac.onAccent : (destructive ? c.danger : mac.label);
    final muted = on ? mac.onAccent : mac.secondaryLabel;
    final faded = enabled ? 1.0 : Pressable.disabledOpacity;
    final text = Opacity(
      opacity: faded,
      child: Text(label, maxLines: 1, softWrap: false, style: MyDataMacType.body.copyWith(color: fg)),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: MyDataMacSize.rowHeight),
      padding: const EdgeInsets.symmetric(horizontal: itemInset),
      decoration: BoxDecoration(color: on ? mac.accent : null, borderRadius: itemRadius),
      child: Row(children: [
        // The check mark's column, as a macOS menu keeps it.
        SizedBox(
          width: MyDataMacSize.icon,
          child: checked ? Icon(MacIcons.check, size: MyDataMacSize.icon - MyDataMacSize.tight, color: fg) : null,
        ),
        const SizedBox(width: MyDataSpace.s1),
        if (iconSpace) ...[
          Opacity(
            opacity: faded,
            child: SizedBox.square(
              dimension: MyDataMacSize.icon,
              child: icon == null ? null : Icon(icon, size: MyDataMacSize.icon, color: on ? fg : muted),
            ),
          ),
          const SizedBox(width: MyDataSpace.s2),
        ],
        Expanded(child: text),
        if (shortcut != null) ...[
          const SizedBox(width: MyDataSpace.s6),
          Opacity(opacity: faded, child: Text(shortcut, style: MyDataMacType.body.copyWith(color: muted))),
        ],
      ]),
    );
  }
}

/// A Toast in the Mac frame: a floating panel on `window-background` with a `separator` hairline and
/// `shadow-2`, the message in `body`.
abstract final class MacToastLook {
  static const radius = BorderRadius.all(Radius.circular(MyDataMacRadius.sidebar));

  static BoxDecoration decoration(BuildContext context) {
    final mac = context.mac;
    return BoxDecoration(
      color: mac.windowBackground,
      borderRadius: radius,
      border: Border.all(color: mac.separator),
      boxShadow: context.shadows.shadow2,
    );
  }

  /// The panel's height at least: a push button and `space-2` above and below it.
  static const minHeight = MyDataMacSize.pushButtonHeight + 2 * MyDataSpace.s2;

  static TextStyle text(BuildContext context) => MyDataMacType.body.copyWith(color: context.mac.label);
}
