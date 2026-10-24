import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'links.dart';
import 'theme_controller.dart';

/// Says once, in each app's own window, that its look changed because Kiwi in an old colour moved to that
/// colour's theme (design/themes/ARCHITECTURE.md 4.2): "Plum is now a palette of Journal, so myContacts looks
/// different." with OK, at the bottom of the window over the content, until OK (or Escape) says it was read
/// ([ThemeController.acknowledgeMovedHere]). Each app says it once; myData's Settings > Appearance keeps the
/// record. Put it in each app's MaterialApp `builder`, round the content.
///
/// - It is a polite live region, so a screen reader hears it when it appears; OK takes the focus only when
///   the user moves it there, never on its own, so typing in the window is never interrupted.
/// - Nothing is said while the gallery previews another theme, or when the move cannot be stored (it is said
///   again on the next start).
class ThemeMovedNotice extends StatefulWidget {
  const ThemeMovedNotice({super.key, required this.themes, required this.app, required this.child});

  final ThemeController themes;
  final MyDataAppId app;
  final Widget child;

  static const okLabel = 'OK';

  /// "Plum is now a palette of Journal, so myContacts looks different."
  static String message(String colour, MyDataAppId app) {
    final to = ThemeLibrary.movedColours[colour]!;
    final theme = ThemeLibrary.byId(to.theme)!;
    return '${theme.palette(to.palette)!.name} is now a palette of ${theme.name}, so ${app.displayName} looks '
        'different.';
  }

  @override
  State<ThemeMovedNotice> createState() => _ThemeMovedNoticeState();
}

class _ThemeMovedNoticeState extends State<ThemeMovedNotice> {
  /// The colour shown now; kept until OK, though the file may lose it meanwhile.
  String? _showing;

  /// Told already in this run (OK pressed), so a slow write never shows it twice.
  final _done = <String>{};

  @override
  void initState() {
    super.initState();
    widget.themes.addListener(_changed);
    _changed();
  }

  @override
  void didUpdateWidget(ThemeMovedNotice old) {
    super.didUpdateWidget(old);
    if (old.themes != widget.themes) {
      old.themes.removeListener(_changed);
      widget.themes.addListener(_changed);
      _changed();
    }
  }

  @override
  void dispose() {
    widget.themes.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    final showing = _showing;
    if (showing != null) {
      // Said elsewhere for this app meanwhile (myData's Appearance, for myData): it goes.
      if (widget.themes.settings.told[showing]?.contains(widget.app.name) ?? false) {
        if (mounted) setState(() => _showing = null);
      }
      return;
    }
    final c = widget.themes.movedNotice;
    if (c == null || _done.contains(c)) return;
    if (mounted) setState(() => _showing = c);
  }

  Future<void> _ok() async {
    final c = _showing;
    if (c == null) return;
    _done.add(c);
    setState(() => _showing = null);
    try {
      await widget.themes.acknowledgeMovedHere(c);
    } on Object {
      // Not stored: said again on the next start.
    }
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final c = _showing;
    if (c == null) return widget.child;
    final colors = context.colors;
    final radius = MyDataRadii.lg(context.look);
    final text = ThemeMovedNotice.message(c, widget.app);
    final bar = Semantics(
      container: true,
      liveRegion: true,
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => _ok()},
        child: Container(
          constraints: const BoxConstraints(maxWidth: MyDataSize.dialogWidth),
          padding: EdgeInsetsDirectional.fromSTEB(context.space(4), context.space(2), context.space(2), context.space(2)),
          // Its outline is the theme's card edge, else `line-strong`: in a flat theme (Journal) the bar would
          // otherwise be lost on its ground.
          decoration: context.radius.decorate(BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: radius,
              boxShadow: context.shadows.shadow2,
              border: Border.fromBorderSide(context.look.edges.card ?? BorderSide(color: colors.lineStrong)))),
          child: Material(
            type: MaterialType.transparency,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(context.icon(MyDataIcon.info), size: context.density.icon, color: colors.info),
                SizedBox(width: context.space(3)),
                Flexible(child: Text(text, style: context.type(MyDataTypeRole.body).copyWith(color: colors.ink))),
                SizedBox(width: context.space(3)),
                Button(label: ThemeMovedNotice.okLabel, variant: ButtonVariant.plain, onPressed: _ok),
              ],
            ),
          ),
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(child: widget.child),
        PositionedDirectional(
          start: context.space(4),
          end: context.space(4),
          bottom: context.space(4),
          child: Center(child: bar),
        ),
      ],
    );
  }
}
