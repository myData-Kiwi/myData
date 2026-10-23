import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A key for a menu action, written once for every desktop: Command with [key] on macOS, Control with it on
/// Windows and Linux (design/platforms.md "The menu bar on macOS": "Ctrl+N, Ctrl+Z, … Ctrl+S, Ctrl+1").
@immutable
class AppShortcut {
  const AppShortcut(this.key, {this.shift = false, this.option = false, this.control = false});

  final LogicalKeyboardKey key;
  final bool shift;

  /// Option on macOS, Alt elsewhere (New Calendar… is ⌥⌘N).
  final bool option;

  /// Control as well as Command, on macOS only (Enter Full Screen is ⌃⌘F, macOS's own).
  final bool control;

  /// The activator on [platform]: Command on macOS, Control elsewhere.
  SingleActivator activator(TargetPlatform platform) {
    final mac = platform == TargetPlatform.macOS;
    return SingleActivator(key, meta: mac, control: !mac || control, shift: shift, alt: option);
  }

  /// As the platform writes it in a menu: "⌥⌘N" on macOS, "Ctrl+Alt+N" elsewhere.
  String label(TargetPlatform platform) {
    final mac = platform == TargetPlatform.macOS;
    final name = _keyName(key, mac: mac);
    if (mac) return '${control ? '⌃' : ''}${option ? '⌥' : ''}${shift ? '⇧' : ''}⌘$name';
    return ['Ctrl', if (option) 'Alt', if (shift) 'Shift', name].join('+');
  }

  static String _keyName(LogicalKeyboardKey key, {required bool mac}) {
    if (key == LogicalKeyboardKey.backspace) return mac ? '⌫' : 'Backspace';
    if (key == LogicalKeyboardKey.delete) return mac ? '⌦' : 'Delete';
    if (key == LogicalKeyboardKey.comma) return ',';
    if (key == LogicalKeyboardKey.enter) return mac ? '↩' : 'Enter';
    return key.keyLabel.toUpperCase();
  }

  @override
  bool operator ==(Object other) =>
      other is AppShortcut &&
      other.key == key &&
      other.shift == shift &&
      other.option == option &&
      other.control == control;

  @override
  int get hashCode => Object.hash(key, shift, option, control);
}

/// One item an app declares in its menu bar.
@immutable
class AppMenuItem {
  const AppMenuItem({required this.title, this.shortcut, this.onSelected, this.textComesFirst = false});

  /// Delete Contact, Delete Event, Delete Calendar… (design/platforms.md "Delete"): ⌘⌫ on macOS. On Windows and
  /// Linux the Delete key alone deletes, while the list has focus, so this item adds no window-wide key there:
  /// the list puts [AppMenuBar.listDeleteActivator] on itself. It is disabled while a text field has focus,
  /// where ⌘⌫ deletes text. [title] ends with an ellipsis when a Dialog asks first ("Delete 3 Contacts…").
  const AppMenuItem.delete({required this.title, this.onSelected})
      : shortcut = AppMenuBar.deleteShortcut,
        textComesFirst = true;

  /// In title case, the one place in the apps that is (design/platforms.md "Case"); [menuTitleCase] turns a
  /// Menu's sentence-case label into it. An item that opens a dialog or file chooser first ends with "…".
  final String title;
  final AppShortcut? shortcut;

  /// Null disables the item; it is never hidden, so the menus keep their shape.
  final VoidCallback? onSelected;

  /// Disabled while a text field has focus, so a key meant for text never acts on a record.
  final bool textComesFirst;
}

/// A sentence-case label in a menu bar's title case: "New contact" is "New Contact", "Delete 3 contacts…" is
/// "Delete 3 Contacts…", "Go to today" is "Go to Today". Short joining words stay lower case unless first or
/// last; a word with a capital after its first letter ("myContacts") is left as it is.
String menuTitleCase(String sentence) {
  const small = {'a', 'an', 'and', 'as', 'at', 'but', 'by', 'for', 'from', 'in', 'into', 'nor', 'of', 'on', 'or', 'the', 'to', 'with'};
  final words = sentence.split(' ');
  return [
    for (var i = 0; i < words.length; i++)
      () {
        final w = words[i];
        if (w.isEmpty) return w;
        if (RegExp(r'^.+[A-Z]').hasMatch(w)) return w;
        final bare = w.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        if (i > 0 && i < words.length - 1 && small.contains(bare)) return w.toLowerCase();
        return w[0].toUpperCase() + w.substring(1);
      }(),
  ].join(' ');
}

/// What the widgets under an [AppMenuBar] hand it, so each key has one owner: a [ToastHost] showing Undo
/// claims Undo (⌘Z, Ctrl+Z and Edit, Undo run the toast's undo, which shows what came back), and an open
/// [Inspector] claims Save (⌘S, Ctrl+S and File, Save save the inspector). Without the menu bar they listen
/// to the keyboard themselves; under it they leave the keys to it, so one press never acts twice.
///
/// A claim is a function that runs the action and returns true, or returns false when it cannot act now
/// (a dialog is open over it); the menu bar then does what it would have done without the claim.
class AppMenuCommands extends ChangeNotifier {
  final _undo = <Object, bool Function()>{};
  final _save = <Object, bool Function()>{};

  /// [owner]'s Undo, until [releaseUndo]. The newest claim runs first.
  void claimUndo(Object owner, bool Function() run) {
    final had = _undo.containsKey(owner);
    _undo.remove(owner);
    _undo[owner] = run;
    if (!had) notifyListeners();
  }

  void releaseUndo(Object owner) {
    if (_undo.remove(owner) != null) notifyListeners();
  }

  /// [owner]'s Save, until [releaseSave].
  void claimSave(Object owner, bool Function() run) {
    final had = _save.containsKey(owner);
    _save.remove(owner);
    _save[owner] = run;
    if (!had) notifyListeners();
  }

  void releaseSave(Object owner) {
    if (_save.remove(owner) != null) notifyListeners();
  }

  bool get hasUndo => _undo.isNotEmpty;
  bool get hasSave => _save.isNotEmpty;

  /// Runs the newest Undo claim that can act; false when none could.
  bool runUndo() => _run(_undo);

  /// Runs the newest Save claim that can act; false when none could.
  bool runSave() => _run(_save);

  static bool _run(Map<Object, bool Function()> claims) {
    for (final run in claims.values.toList().reversed) {
      if (run()) return true;
    }
    return false;
  }
}

class _AppMenuScope extends InheritedWidget {
  const _AppMenuScope({required this.commands, required super.child});
  final AppMenuCommands commands;

  @override
  bool updateShouldNotify(_AppMenuScope old) => old.commands != commands;
}

/// The app's menu bar on macOS, declared once per app (design/platforms.md "The menu bar on macOS"), and the
/// same shortcuts with Control on Windows and Linux, which have no menu bar of this kind.
///
/// Menus, in order: the app's menu (About, Settings… for myData only, Hide, Hide Others, Show All, Quit),
/// File ([file], then Close Window ⌘W), Edit (Undo and Redo, Cut, Copy, Paste, Select All, then [edit]), View
/// ([view], then Enter Full Screen) and Window (Minimize, Zoom, Bring All to Front). There is no Help menu.
/// macOS's own items are macOS's ([PlatformProvidedMenuItem]); macOS adds its own to Edit.
///
/// - **Undo and Redo name the action** ([undoAction], [redoAction]): "Undo Delete Contact"; with nothing to
///   undo, "Undo", disabled. Redo stays disabled until the host can redo ([onRedo] null).
/// - **Text comes first.** While a text field has focus, Undo and Redo are "Undo Typing" and "Redo Typing" and
///   act on the field, Cut, Copy, Paste and Select All act on its text, and [AppMenuItem.textComesFirst]
///   items (Delete) are disabled. On macOS a key goes to the focused field before the menu, so ⌘Z and ⌘⌫ in
///   a field act on its text.
/// - **Windows and Linux:** no menu is drawn; every item's [AppShortcut] works with Control (Redo also on
///   Ctrl+Y), except Delete, which is the Delete key alone on the focused list
///   ([listDeleteActivator]). Cut, Copy, Paste and Select All are the text fields' own keys there.
/// - **One owner per key:** a [ToastHost] or [Inspector] below claims Undo or Save ([AppMenuCommands]), and
///   the menu bar runs the claim in place of [onUndo] or the declared Save item.
class AppMenuBar extends StatefulWidget {
  const AppMenuBar({
    super.key,
    required this.appName,
    required this.child,
    this.file = const [],
    this.edit = const [],
    this.view = const [],
    this.undoAction,
    this.onUndo,
    this.redoAction,
    this.onRedo,
    this.onSettings,
    this.onQuit,
    this.onCloseWindow,
    this.platform,
  });

  /// "myContacts": the app's menu and its About, Hide and Quit items are named after it.
  final String appName;
  final Widget child;

  /// File's items before Close Window: New Contact ⌘N; New Event ⌘N and New Calendar… ⌥⌘N; Import…; Save ⌘S.
  final List<AppMenuItem> file;

  /// Edit's items after Select All: Edit Contact ⌘E, Delete Contact ⌘⌫ ([AppMenuItem.delete]), …
  final List<AppMenuItem> edit;

  /// View's items before Enter Full Screen: one per sidebar section (⌘1, ⌘2…), Go to Today ⌘T.
  final List<AppMenuItem> view;

  /// The action the next Undo undoes, by its verb and object in title case ("Delete Contact"); null: nothing
  /// to undo. The names come from the host's undo log, not from a Toast.
  final String? undoAction;
  final VoidCallback? onUndo;
  final String? redoAction;
  final VoidCallback? onRedo;

  /// myData only: Settings… ⌘, in the app's menu.
  final VoidCallback? onSettings;

  /// An app's own Quit, when it needs one; null gives macOS's own. Quitting never stops the host (a login service).
  final VoidCallback? onQuit;

  /// Close Window ⌘W. Null disables it (Flutter has no call to close the window by itself).
  final VoidCallback? onCloseWindow;

  /// For tests; null is [defaultTargetPlatform].
  final TargetPlatform? platform;

  static const undoShortcut = AppShortcut(LogicalKeyboardKey.keyZ);
  static const redoShortcut = AppShortcut(LogicalKeyboardKey.keyZ, shift: true);
  static const cutShortcut = AppShortcut(LogicalKeyboardKey.keyX);
  static const copyShortcut = AppShortcut(LogicalKeyboardKey.keyC);
  static const pasteShortcut = AppShortcut(LogicalKeyboardKey.keyV);
  static const selectAllShortcut = AppShortcut(LogicalKeyboardKey.keyA);
  static const closeWindowShortcut = AppShortcut(LogicalKeyboardKey.keyW);
  static const settingsShortcut = AppShortcut(LogicalKeyboardKey.comma);
  static const quitShortcut = AppShortcut(LogicalKeyboardKey.keyQ);

  /// ⌘⌫ on macOS (Delete Contact, Delete Event).
  static const deleteShortcut = AppShortcut(LogicalKeyboardKey.backspace);

  /// ⌘E: Edit Contact and Edit Event, in every app (decided 2026-10-14; unverified against Apple's apps).
  static const editShortcut = AppShortcut(LogicalKeyboardKey.keyE);

  /// ⌘N, ⌘S, ⌘T and ⌘1… for the items apps declare.
  static const newShortcut = AppShortcut(LogicalKeyboardKey.keyN);
  static const saveShortcut = AppShortcut(LogicalKeyboardKey.keyS);
  static const todayShortcut = AppShortcut(LogicalKeyboardKey.keyT);
  static AppShortcut sectionShortcut(int n) => AppShortcut(LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + n - 1));

  static const fileMenu = 'File';
  static const editMenu = 'Edit';
  static const viewMenu = 'View';
  static const windowMenu = 'Window';

  /// The key that deletes the selected records while a list has focus: the Delete key alone on Windows and
  /// Linux (as in Explorer and Outlook; Ctrl+Delete deletes a word in text there), ⌘⌫ on macOS (where the
  /// menu bar's item also has it). Put it on the list, not on the window.
  static SingleActivator listDeleteActivator(TargetPlatform platform) => platform == TargetPlatform.macOS
      ? deleteShortcut.activator(platform)
      : const SingleActivator(LogicalKeyboardKey.delete);

  /// How a Menu shows the Delete key: "⌘⌫" on macOS, "Delete" on Windows and Linux.
  static String deleteLabel(TargetPlatform platform) =>
      platform == TargetPlatform.macOS ? deleteShortcut.label(platform) : 'Delete';

  /// "Undo Delete Contact", "Undo Typing" while a text field has focus, or "Undo" with nothing to undo.
  static String undoTitle(String? action, {bool typing = false}) =>
      typing ? 'Undo Typing' : (action == null ? 'Undo' : 'Undo $action');

  /// "Redo Edit Event", "Redo Typing", or "Redo".
  static String redoTitle(String? action, {bool typing = false}) =>
      typing ? 'Redo Typing' : (action == null ? 'Redo' : 'Redo $action');

  /// The commands of the menu bar above [context], or null when there is none (a phone, a test).
  static AppMenuCommands? commandsOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_AppMenuScope>()?.commands;

  /// Whether a text field has keyboard focus.
  static bool textHasFocus() =>
      FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null;

  @override
  State<AppMenuBar> createState() => _AppMenuBarState();
}

class _AppMenuBarState extends State<AppMenuBar> {
  bool _typing = false;
  final _commands = AppMenuCommands();

  TargetPlatform get _platform => widget.platform ?? defaultTargetPlatform;
  bool get _mac => _platform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focusChanged);
    _commands.addListener(_claimsChanged);
    _typing = AppMenuBar.textHasFocus();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focusChanged);
    _commands.dispose();
    super.dispose();
  }

  void _claimsChanged() {
    // A claim comes and goes from a child's build or dispose: rebuild the menus after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  /// Undo, not in a text field: a claim (the toast's), else the app's.
  bool get _canUndo => _commands.hasUndo || (widget.undoAction != null && widget.onUndo != null);
  void _undo() {
    if (!_commands.runUndo() && widget.undoAction != null) widget.onUndo?.call();
  }

  bool _isSave(AppMenuItem item) => item.shortcut == AppMenuBar.saveShortcut;

  void _focusChanged() {
    final typing = AppMenuBar.textHasFocus();
    if (typing != _typing && mounted) setState(() => _typing = typing);
  }

  /// Sends a text intent to the focused field.
  void _text(Intent intent) {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context != null) Actions.maybeInvoke(context, intent);
  }

  PlatformMenuItem _item(AppMenuItem item) {
    VoidCallback? run = item.onSelected;
    // Save runs the open inspector's save, when one has claimed it.
    if (_isSave(item) && _commands.hasSave) run = () => _commands.runSave() ? null : item.onSelected?.call();
    return PlatformMenuItem(
      label: item.title,
      shortcut: item.shortcut?.activator(_platform),
      onSelected: item.textComesFirst && _typing ? null : run,
    );
  }

  PlatformMenuItem _plain(String label, AppShortcut? shortcut, VoidCallback? onSelected) =>
      PlatformMenuItem(label: label, shortcut: shortcut?.activator(_platform), onSelected: onSelected);

  List<PlatformMenuItem> _menus() {
    const cause = SelectionChangedCause.keyboard;
    final name = widget.appName;
    return [
      PlatformMenu(label: name, menus: [
        const PlatformMenuItemGroup(members: [PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.about)]),
        if (widget.onSettings != null)
          PlatformMenuItemGroup(members: [_plain('Settings…', AppMenuBar.settingsShortcut, widget.onSettings)]),
        const PlatformMenuItemGroup(members: [
          PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hide),
          PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.hideOtherApplications),
          PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.showAllApplications),
        ]),
        PlatformMenuItemGroup(members: [
          if (widget.onQuit != null)
            _plain('Quit $name', AppMenuBar.quitShortcut, widget.onQuit)
          else
            const PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.quit),
        ]),
      ]),
      PlatformMenu(label: AppMenuBar.fileMenu, menus: [
        if (widget.file.isNotEmpty) PlatformMenuItemGroup(members: [for (final i in widget.file) _item(i)]),
        PlatformMenuItemGroup(
            members: [_plain('Close Window', AppMenuBar.closeWindowShortcut, widget.onCloseWindow)]),
      ]),
      PlatformMenu(label: AppMenuBar.editMenu, menus: [
        PlatformMenuItemGroup(members: [
          _plain(
            AppMenuBar.undoTitle(widget.undoAction, typing: _typing),
            AppMenuBar.undoShortcut,
            _typing ? () => _text(const UndoTextIntent(cause)) : (_canUndo ? _undo : null),
          ),
          _plain(
            AppMenuBar.redoTitle(widget.redoAction, typing: _typing),
            AppMenuBar.redoShortcut,
            _typing ? () => _text(const RedoTextIntent(cause)) : (widget.redoAction == null ? null : widget.onRedo),
          ),
        ]),
        PlatformMenuItemGroup(members: [
          _plain('Cut', AppMenuBar.cutShortcut, _typing ? () => _text(CopySelectionTextIntent.cut(cause)) : null),
          _plain('Copy', AppMenuBar.copyShortcut, _typing ? () => _text(CopySelectionTextIntent.copy) : null),
          _plain('Paste', AppMenuBar.pasteShortcut, _typing ? () => _text(const PasteTextIntent(cause)) : null),
          _plain('Select All', AppMenuBar.selectAllShortcut,
              _typing ? () => _text(const SelectAllTextIntent(cause)) : null),
        ]),
        if (widget.edit.isNotEmpty) PlatformMenuItemGroup(members: [for (final i in widget.edit) _item(i)]),
      ]),
      PlatformMenu(label: AppMenuBar.viewMenu, menus: [
        if (widget.view.isNotEmpty) PlatformMenuItemGroup(members: [for (final i in widget.view) _item(i)]),
        const PlatformMenuItemGroup(
            members: [PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.toggleFullScreen)]),
      ]),
      const PlatformMenu(label: AppMenuBar.windowMenu, menus: [
        PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.minimizeWindow),
        PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.zoomWindow),
        PlatformMenuItemGroup(
            members: [PlatformProvidedMenuItem(type: PlatformProvidedMenuItemType.arrangeWindowsInFront)]),
      ]),
    ];
  }

  /// Windows and Linux: the items' keys with Control. Undo and Redo give way to a focused text field (whose
  /// own keys are further up the tree), and Delete is the list's ([AppMenuBar.listDeleteActivator]).
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    bool matches(SingleActivator a) => a.accepts(event, keyboard);
    final typing = AppMenuBar.textHasFocus();
    final p = _platform;
    if (!typing) {
      if (_canUndo && matches(AppMenuBar.undoShortcut.activator(p))) {
        _undo();
        return KeyEventResult.handled;
      }
      if (widget.redoAction != null &&
          widget.onRedo != null &&
          (matches(AppMenuBar.redoShortcut.activator(p)) ||
              matches(const SingleActivator(LogicalKeyboardKey.keyY, control: true)))) {
        widget.onRedo!();
        return KeyEventResult.handled;
      }
    }
    if (matches(AppMenuBar.saveShortcut.activator(p)) && _commands.runSave()) return KeyEventResult.handled;
    for (final item in [...widget.file, ...widget.edit, ...widget.view]) {
      final s = item.shortcut;
      if (s == null || s == AppMenuBar.deleteShortcut || item.onSelected == null) continue;
      if (item.textComesFirst && typing) continue;
      if (matches(s.activator(p))) {
        item.onSelected!();
        return KeyEventResult.handled;
      }
    }
    if (widget.onCloseWindow != null && matches(AppMenuBar.closeWindowShortcut.activator(p))) {
      widget.onCloseWindow!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// macOS: the menu owns its items' keys. ⌘S, when no Save item is declared, still reaches a claim.
  KeyEventResult _onMacKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (widget.file.any(_isSave)) return KeyEventResult.ignored;
    if (AppMenuBar.saveShortcut.activator(_platform).accepts(event, HardwareKeyboard.instance) && _commands.runSave()) {
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (_mac) {
      child = PlatformMenuBar(
        menus: _menus(),
        child: Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: _onMacKey, child: widget.child),
      );
    } else if (_platform == TargetPlatform.windows || _platform == TargetPlatform.linux) {
      child = Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: _onKey, child: widget.child);
    } else {
      // Phones have no menu bar: every action is on screen (design/platforms.md "Phones have no menu bar").
      return widget.child;
    }
    return _AppMenuScope(commands: _commands, child: child);
  }
}
