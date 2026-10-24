import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mac/mac_shell.dart';
import '../mac/mac_theme.dart' show MacLook, MacTypeContext;
import '../theme/choice.dart';
import '../theme/library.dart';
import '../theme/motion.dart';
import '../theme/theme.dart';
import '../theme/theme_file.dart';
import 'button.dart';
import 'group_frame.dart';
import 'notice.dart';
import 'pressable.dart';
import 'segmented_control.dart';
import 'theme_picker.dart';
import 'toast.dart';
import 'role_label.dart';

/// One app a [ThemeGallery] can choose for: its id in the device's settings (`mycontacts`), its name, its
/// preview scene ([ThemePreviewScenes]) and what it draws now.
@immutable
class ThemeGalleryApp {
  const ThemeGalleryApp({required this.id, required this.name, required this.scene, required this.current});

  final String id;
  final String name;
  final WidgetBuilder scene;
  final ThemeChoice current;
}

/// Undoes a Use everywhere (puts each app's choice back): true when it did, false when the choices had
/// changed since and nothing was put back.
typedef ThemeUndo = Future<bool> Function();

/// Whether a gallery is open in this app ([ThemeGallery.showing]).
final _showing = ValueNotifier<bool>(false);

/// Opens the theme gallery over [context]'s window (design/themes/ARCHITECTURE.md 4.4): View > Theme…
/// in every app, and Change… in myData's Appearance. Completes when it closes.
///
/// - [apps]: the apps it chooses for, the first unless [initialApp] says; more than one shows an app
///   switcher above the grid (myData's gallery), so a theme can be judged on another app's scene.
/// - [windowApp]: the app whose window this is. While that app is the one shown, [onPreview] draws the
///   selection on the whole window as it moves; null ends the preview (Cancel, Escape, closing).
/// - [onUse]: "Use in myContacts", or Return: stores the choice for that app, then the gallery closes.
/// - [onUseEverywhere]: stores the choice for every app and returns its undo, offered in a toast inside the
///   gallery, which stays open. Null (phones: one theme per app) leaves the button out.
/// - [everywhere]: the gallery chooses the everywhere choice (myData's Appearance, the Everywhere row). It
///   starts on [everywhere], Use everywhere is the default action (Return), and there is no "Use in".
///   Needs [onUseEverywhere].
/// - One at a time: while a gallery is open ([ThemeGallery.showing]), this does nothing. On a Mac the menu
///   bar is not behind the gallery's barrier, so View > Theme… could otherwise open a second one.
Future<void> showThemeGallery({
  required BuildContext context,
  required List<ThemeGalleryApp> apps,
  String? initialApp,
  required String windowApp,
  required ValueChanged<ThemeChoice?> onPreview,
  required Future<void> Function(String app, ThemeChoice choice) onUse,
  Future<ThemeUndo> Function(ThemeChoice choice)? onUseEverywhere,
  ThemeChoice? everywhere,
}) {
  assert(everywhere == null || onUseEverywhere != null, 'Choosing everywhere needs Use everywhere.');
  if (_showing.value) return Future.value();
  _showing.value = true;
  final reduced = MyDataMotion.reduced(context);
  return Navigator.of(context)
      .push<void>(
        _GalleryRoute(
          reduced: reduced,
          motion: context.lookNow.motion,
          builder: (_) => ThemeGallery(
            apps: apps,
            initialApp: initialApp,
            windowApp: windowApp,
            everywhere: everywhere,
            onPreview: onPreview,
            onUse: onUse,
            onUseEverywhere: onUseEverywhere,
          ),
        ),
      )
      .whenComplete(() => _showing.value = false);
}

class _GalleryRoute extends PopupRoute<void> {
  _GalleryRoute({required this.builder, required this.reduced, required this.motion});

  final WidgetBuilder builder;
  final bool reduced;
  final MyDataMotionSpec motion;

  /// No scrim: the window behind shows the theme being previewed.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => reduced ? motion.fast : motion.slow;

  /// Removed without completing (the app's navigator torn down): the next [showThemeGallery] may open.
  @override
  void dispose() {
    _showing.value = false;
    super.dispose();
  }

  @override
  Duration get reverseTransitionDuration => motion.fast;

  // Not wrapped in the themes captured at opening: the gallery follows the preview like the window.
  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Builder(builder: builder);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: context.motion.standard);
    final faded = FadeTransition(opacity: curved, child: child);
    if (reduced) return faded;
    return SlideTransition(
      position: Tween(begin: Offset(0, -context.motion.sheetDrop), end: Offset.zero).animate(curved),
      child: faded,
    );
  }
}

/// The theme gallery: a panel of live cards, one per theme, each drawing the app's own scene in light and
/// dark ([showThemeGallery] opens it).
///
/// - **Groups:** System, then Built-in ([ThemeLibrary.offered]). A card shows the theme's name, who made it
///   and its licence, its blurb, and its palettes as swatches.
/// - **Keys:** focus starts on the selected card. The cards are a radio group: the arrow keys (Home, End)
///   move the selection, and the window previews it. Tab goes on to the palette row (the selected theme's
///   palettes as named swatches, also previewed as they change; none for System or a theme with one), kept
///   in view above the buttons while the cards scroll, then the buttons. Return uses the selection in the app; Escape or Cancel puts the window back as it was.
/// - **Use everywhere** stores the theme and palette for every app and clears each app's own, so its toast
///   offers Undo; the gallery stays open, and Cancel becomes Done. With [everywhere] it is the default
///   action and "Use in" is left out.
/// - **While a choice is being stored** the selection, the app switcher, Escape and the buttons wait for it,
///   so what is stored is what was shown; when it cannot be stored, a Notice above the buttons says so.
/// - **Screen readers:** the cards are radios named "Kiwi, theme" with their blurb; each palette swatch is a
///   radio named after its colour. The previews are pictures and are not read.
class ThemeGallery extends StatefulWidget {
  const ThemeGallery({
    super.key,
    required this.apps,
    this.initialApp,
    required this.windowApp,
    required this.onPreview,
    required this.onUse,
    this.onUseEverywhere,
    this.everywhere,
  }) : assert(everywhere == null || onUseEverywhere != null);

  final List<ThemeGalleryApp> apps;
  final String? initialApp;
  final String windowApp;

  /// The everywhere choice, when this gallery chooses it ([showThemeGallery]); null: it chooses for an app.
  final ThemeChoice? everywhere;
  final ValueChanged<ThemeChoice?> onPreview;
  final Future<void> Function(String app, ThemeChoice choice) onUse;
  final Future<ThemeUndo> Function(ThemeChoice choice)? onUseEverywhere;

  static const title = 'Theme';

  /// Whether a gallery is open in this app: View > Theme… ([AppMenuBar]) is disabled meanwhile, and
  /// [showThemeGallery] does nothing.
  static ValueListenable<bool> get showing => _showing;

  /// "Choose how myContacts looks on this Mac."
  static String sentence(String app) => 'Choose how $app looks on this device.';
  static const cancelLabel = 'Cancel';

  /// Cancel's label once Use everywhere has stored something: closing then keeps it.
  static const doneLabel = 'Done';

  /// The everywhere gallery's sentence.
  static const everywhereSentence = 'Choose how every app looks on this device, unless it has its own.';

  /// When a choice could not be stored.
  static const failed = 'The theme could not be stored on this device. Try again.';
  static const everywhereLabel = 'Use everywhere';
  static String useLabel(String app) => 'Use in $app';
  static const paletteLabel = 'Palette';
  static const themesLabel = 'Themes';
  static const appsLabel = 'App';
  static const systemGroup = 'System';
  static const builtInGroup = 'Built-in';

  /// "Kiwi, Plum is now used in every app."
  static String everywhereDone(String choice) => '$choice is now used in every app.';
  static const everywhereUndone = "Each app's theme is back.";
  static const everywhereNotUndone = 'Not undone. The themes were changed after that.';

  /// What System means here, under its card: the Mac's own look, or Kiwi until this platform's own pass
  /// (ARCHITECTURE.md section 0).
  static String systemNote({required bool mac}) =>
      mac ? "Your Mac's own look and accent colour." : "Kiwi, until this platform's own look.";

  /// The scene's size before it is scaled into a card.
  static const sceneSize = Size(720, 450);

  /// The panel's widest.
  static const maxWidth = 860.0;

  /// A card's width: two previews side by side.
  static const cardWidth = 380.0;

  @override
  State<ThemeGallery> createState() => _ThemeGalleryState();
}

class _ThemeGalleryState extends State<ThemeGallery> {
  late ThemeGalleryApp _app = widget.apps.firstWhere((a) => a.id == widget.initialApp, orElse: () => widget.apps.first);
  late ThemeChoice _choice = ThemeLibrary.normalise(_current);
  final _toasts = ToastController();
  final List<FocusNode> _cardNodes = [];
  bool _used = false;
  bool _ended = false;
  bool _working = false;

  /// Use everywhere stored something: Cancel is Done.
  bool _stored = false;

  /// Why the last choice could not be stored, or null.
  String? _error;

  bool get _choosingEverywhere => widget.everywhere != null;

  /// What the gallery starts on and what an unselected card shows: the everywhere choice, or the app's.
  ThemeChoice get _current => widget.everywhere ?? _app.current;

  List<ThemeFile> get _themes => ThemeLibrary.offered;

  int get _selected => math.max(0, _themes.indexWhere((t) => t.id == _choice.theme));

  bool get _previewsWindow => _app.id == widget.windowApp;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _themes.length; i++) {
      _cardNodes.add(FocusNode(debugLabel: 'ThemeGallery card $i'));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cardNodes[_selected].requestFocus();
    });
  }

  /// Closed without a choice (Escape, Cancel, the route popped): the window draws what it stored again.
  void _endPreview() {
    if (_used || _ended) return;
    _ended = true;
    widget.onPreview(null);
  }

  @override
  void dispose() {
    // Removed without a pop (the app's navigator replaced): end the preview after this frame, since a
    // listener's rebuild cannot be asked for while the tree is being torn down.
    if (!_used && !_ended) {
      _ended = true;
      final onPreview = widget.onPreview;
      WidgetsBinding.instance.addPostFrameCallback((_) => onPreview(null));
    }
    for (final n in _cardNodes) {
      n.dispose();
    }
    _toasts.dispose();
    super.dispose();
  }

  void _show(ThemeChoice choice) {
    setState(() => _choice = choice);
    if (_previewsWindow) widget.onPreview(choice);
  }

  /// A theme's card was chosen: its default palette, or the palette in use when it is the current theme
  /// (palette ids belong to one theme).
  void _selectTheme(int index) {
    if (_working) return;
    final theme = _themes[index];
    if (theme.id == _choice.theme) return;
    final current = ThemeLibrary.normalise(_current);
    _show(current.theme == theme.id ? current : ThemeLibrary.defaultChoice(theme));
  }

  void _selectPalette(String id) {
    if (!_working) _show(ThemeChoice(_choice.theme, id));
  }

  /// Another app's scene. Choosing for an app, its own choice is selected; choosing everywhere, the
  /// selection stays and is judged on that app's scene.
  void _switchApp(String id) {
    if (_working) return;
    final app = widget.apps.firstWhere((a) => a.id == id);
    if (_previewsWindow) widget.onPreview(null);
    setState(() {
      _app = app;
      if (!_choosingEverywhere) _choice = ThemeLibrary.normalise(app.current);
    });
    if (_previewsWindow) widget.onPreview(_choice);
  }

  /// Return: Use in the app, or Use everywhere when choosing everywhere.
  Future<void> _useDefault() => _choosingEverywhere ? _useEverywhere() : _use();

  Future<void> _use() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.onUse(_app.id, _choice);
      _used = true;
      if (mounted) Navigator.of(context).pop();
    } on Object {
      if (mounted) setState(() => _error = ThemeGallery.failed);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _useEverywhere() async {
    final everywhere = widget.onUseEverywhere;
    if (everywhere == null || _working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    final choice = _choice;
    try {
      final undo = await everywhere(choice);
      if (!mounted) return;
      _stored = true;
      _toasts.show(
        ThemeGallery.everywhereDone(ThemeLibrary.describe(choice)),
        undo: () async {
          final undone = await undo();
          return UndoResult(undone ? ThemeGallery.everywhereUndone : ThemeGallery.everywhereNotUndone);
        },
      );
    } on Object {
      if (mounted) setState(() => _error = ThemeGallery.failed);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  /// Cancel, Done or Escape; not while a choice is being stored, so the window is never put back under a
  /// choice that is still landing.
  void _cancel() {
    if (!_working) Navigator.of(context).pop();
  }

  KeyEventResult _onCardKey(int index, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    if (_working) return KeyEventResult.handled;
    final n = _themes.length;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    int? next;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == (rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight)) {
      next = (index + 1) % n;
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == (rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft)) {
      next = (index - 1 + n) % n;
    } else if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = n - 1;
    } else if (key == LogicalKeyboardKey.space) {
      _selectTheme(index);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      // Return on the cards uses the selection; on a button or a palette swatch it presses that.
      if (event is KeyDownEvent) unawaited(_useDefault());
      return KeyEventResult.handled;
    }
    if (next == null) return KeyEventResult.ignored;
    _cardNodes[next].requestFocus();
    _selectTheme(next);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selected = _selected;
    for (var i = 0; i < _cardNodes.length; i++) {
      _cardNodes[i].skipTraversal = i != selected;
    }
    final theme = _themes[selected];
    final width = MediaQuery.sizeOf(context).width;
    final margin = context.space(width < 600 ? 4 : 8);
    final panelWidth = math.max(0.0, math.min(ThemeGallery.maxWidth, width - 2 * margin));

    Widget group(String heading, List<int> indexes) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: RoleLabel(heading, style: context.type(MyDataTypeRole.label), color: c.inkMuted),
        ),
        SizedBox(height: context.space(2)),
        Wrap(
          spacing: context.space(4),
          runSpacing: context.space(4),
          children: [
            for (final i in indexes)
              _ThemeCard(
                theme: _themes[i],
                choice: i == selected ? _choice : _cardChoice(_themes[i]),
                selected: i == selected,
                focusNode: _cardNodes[i],
                scene: _app.scene,
                onSelect: () {
                  if (_working) return;
                  _cardNodes[i].requestFocus();
                  _selectTheme(i);
                },
                onKey: (e) => _onCardKey(i, e),
              ),
          ],
        ),
      ],
    );

    final systemIndexes = [
      for (var i = 0; i < _themes.length; i++)
        if (_themes[i].frame == ThemeFrame.system) i,
    ];
    final builtInIndexes = [
      for (var i = 0; i < _themes.length; i++)
        if (_themes[i].frame != ThemeFrame.system) i,
    ];

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(ThemeGallery.title, style: context.type(MyDataTypeRole.title).copyWith(color: c.ink)),
        ),
        SizedBox(height: context.space(1)),
        Text(
          _choosingEverywhere ? ThemeGallery.everywhereSentence : ThemeGallery.sentence(_app.name),
          style: context.type(MyDataTypeRole.body).copyWith(color: c.inkMuted)),
        if (widget.apps.length > 1) ...[
          SizedBox(height: context.space(4)),
          SegmentedControl<String>(
            semanticLabel: ThemeGallery.appsLabel,
            segments: [for (final a in widget.apps) (a.id, a.name)],
            selected: _app.id,
            onChanged: _working ? null : _switchApp,
          ),
        ],
        SizedBox(height: context.space(5)),
        Semantics(
          container: true,
          role: SemanticsRole.radioGroup,
          label: ThemeGallery.themesLabel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (systemIndexes.isNotEmpty) group(ThemeGallery.systemGroup, systemIndexes),
              if (systemIndexes.isNotEmpty && builtInIndexes.isNotEmpty) SizedBox(height: context.space(5)),
              if (builtInIndexes.isNotEmpty) group(ThemeGallery.builtInGroup, builtInIndexes),
            ],
          ),
        ),
      ],
    );

    // The selected theme's palettes, kept in view under the cards however many themes there are.
    final palettes = theme.palettes.length < 2
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RoleLabel(ThemeGallery.paletteLabel, style: context.type(MyDataTypeRole.label), color: c.inkMuted),
              SizedBox(height: context.space(2)),
              ThemePicker(
                key: ValueKey('palettes ${theme.id}'),
                themes: ThemeLibrary.paletteSwatches(theme),
                selected: _choice.palette,
                semanticLabel: '${ThemeGallery.paletteLabel} of ${theme.name}',
                onChanged: _working ? null : _selectPalette,
              ),
            ],
          );

    final buttons = ButtonRow(
      alignment: WrapAlignment.end,
      children: [
        Button(
          label: _stored ? ThemeGallery.doneLabel : ThemeGallery.cancelLabel,
          variant: ButtonVariant.plain,
          onPressed: _working ? null : _cancel,
        ),
        if (widget.onUseEverywhere != null)
          Button(
            label: ThemeGallery.everywhereLabel,
            variant: _choosingEverywhere ? ButtonVariant.filled : ButtonVariant.tonal,
            onPressed: _working ? null : _useEverywhere,
          ),
        if (!_choosingEverywhere)
          Button(
            label: ThemeGallery.useLabel(_app.name),
            variant: ButtonVariant.filled,
            onPressed: _working ? null : _use,
          ),
      ],
    );

    final panel = Container(
      width: panelWidth,
      constraints: BoxConstraints(maxHeight: math.max(0.0, MediaQuery.sizeOf(context).height - 2 * margin)),
      decoration: context.radius.decorate(BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.all(Radius.circular(context.radius.xl)),
        boxShadow: context.shadows.shadow2,
        border: Border.all(color: c.line),
      )),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(context.space(6), context.space(6), context.space(6), context.space(4)),
              child: body,
            ),
          ),
          if (palettes != null)
            Padding(
              padding: EdgeInsets.fromLTRB(context.space(6), context.space(2), context.space(6), context.space(2)),
              child: palettes,
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(context.space(6), context.space(2), context.space(6), context.space(6)),
            child: _error == null
                ? buttons
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Notice(message: _error!, tone: NoticeTone.warning),
                      SizedBox(height: context.space(3)),
                      buttons,
                    ],
                  ),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: !_working,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _endPreview();
      },
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
        child: FocusScope(
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: ThemeGallery.title,
            // The toast sits at the window's foot, under the panel that keeps only its own height.
            child: ToastHost(
              controller: _toasts,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: margin),
                    child: Material(type: MaterialType.transparency, child: panel),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// What a card that is not selected draws: the palette in use when it is the app's current theme, else
  /// the theme's default.
  ThemeChoice _cardChoice(ThemeFile theme) {
    final current = ThemeLibrary.normalise(_current);
    return current.theme == theme.id ? current : ThemeLibrary.defaultChoice(theme);
  }
}

class _ThemeCard extends StatefulWidget {
  const _ThemeCard({
    required this.theme,
    required this.choice,
    required this.selected,
    required this.focusNode,
    required this.scene,
    required this.onSelect,
    required this.onKey,
  });

  final ThemeFile theme;
  final ThemeChoice choice;
  final bool selected;
  final FocusNode focusNode;
  final WidgetBuilder scene;
  final VoidCallback onSelect;
  final KeyEventResult Function(KeyEvent event) onKey;

  @override
  State<_ThemeCard> createState() => _ThemeCardState();
}

class _ThemeCardState extends State<_ThemeCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = widget.theme;
    final radius = BorderRadius.all(Radius.circular(context.radius.lg));
    final system = t.frame == ThemeFrame.system;
    final note = system ? ThemeGallery.systemNote(mac: MacLook.forThisPlatform) : (t.blurb ?? '');
    final byline = [if (t.author != null) t.author!, t.licence].join(' · ');
    final ring = _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

    Widget preview(Brightness b) => Expanded(
      child: context.radius.clip(
        BorderRadius.all(Radius.circular(context.radius.sm)),
        child: ThemeScenePreview(choice: widget.choice, brightness: b, scene: widget.scene),
      ),
    );

    final card = Container(
      width: ThemeGallery.cardWidth,
      padding: EdgeInsets.all(context.space(3)),
      decoration: context.radius.decorate(BoxDecoration(
        color: c.surface,
        borderRadius: radius,
        border: Border.all(
          color: widget.selected ? c.ink : c.line,
          width: widget.selected ? ThemePicker.ringWidth : GroupFrame.dividerWidth,
        ),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              preview(Brightness.light),
              SizedBox(width: context.space(2)),
              preview(Brightness.dark),
            ],
          ),
          SizedBox(height: context.space(3)),
          Row(
            children: [
              Expanded(
                child: Text(
                  t.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type(MyDataTypeRole.bodyStrong).copyWith(color: c.ink),
                ),
              ),
              if (t.palettes.length > 1) _PaletteDots(theme: t, chosen: widget.choice.palette),
            ],
          ),
          if (note.isNotEmpty) Text(note, style: context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted)),
          if (!system) Text(byline, style: context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted)),
        ],
      ),
    );

    return Semantics(
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: widget.selected,
      focusable: true,
      focused: _focused,
      label: '${t.name}, theme',
      hint: note.isEmpty ? null : note,
      onTap: widget.onSelect,
      child: ExcludeSemantics(
        child: Focus(
          focusNode: widget.focusNode,
          onFocusChange: (f) => setState(() => _focused = f),
          onKeyEvent: (_, e) => widget.onKey(e),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onSelect,
              child: FocusRing(visible: ring, borderRadius: radius, child: card),
            ),
          ),
        ),
      ),
    );
  }
}

/// A theme's palettes as small discs of their accent, the chosen one ringed; a picture (the palette row
/// below the grid names them).
class _PaletteDots extends StatelessWidget {
  const _PaletteDots({required this.theme, required this.chosen});

  final ThemeFile theme;
  final String? chosen;

  static const size = 12.0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in ThemeLibrary.paletteSwatches(theme))
          Padding(
            padding: EdgeInsetsDirectional.only(start: context.space(1)),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: dark ? s.accentDark : s.accentLight,
                shape: BoxShape.circle,
                border: s.id == chosen
                    ? Border.all(color: c.ink, width: ThemePicker.ringWidth, strokeAlign: BorderSide.strokeAlignOutside)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// [scene] drawn in [choice] and [brightness] as the app would draw it ([MacShell.themeDataFor]), at
/// [ThemeGallery.sceneSize] and scaled into its parent's width: a picture, never focused, tapped or read.
class ThemeScenePreview extends StatelessWidget {
  const ThemeScenePreview({super.key, required this.choice, required this.brightness, required this.scene});

  final ThemeChoice choice;
  final Brightness brightness;
  final WidgetBuilder scene;

  @override
  Widget build(BuildContext context) {
    final data = MacShell.themeDataFor(context, choice, brightness);
    final mq = MediaQuery.of(context);
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: ThemeGallery.sceneSize.aspectRatio,
        child: ExcludeSemantics(
          child: ExcludeFocus(
            child: IgnorePointer(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox.fromSize(
                  size: ThemeGallery.sceneSize,
                  child: MediaQuery(
                    data: mq.copyWith(size: ThemeGallery.sceneSize, disableAnimations: true),
                    child: Theme(
                      data: data,
                      child: Builder(
                        builder: (context) => Material(
                          color: context.colors.bg,
                          child: Builder(builder: scene),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
