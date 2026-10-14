import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'backend.dart';
import 'contact_editor.dart';
import 'contacts_controller.dart';

/// What the user does to contacts, one place for every way in: the menu bar, the list's Menu, the contact
/// pane's buttons and "More actions", the keys, and the phone's title (design/platforms.md, "The menu bar on
/// macOS" and "Phones have no menu bar"). It asks the questions (Discard changes?, Delete 3 contacts?) and
/// says what happened in a Toast with Undo; [ContactsController] talks to the host.
///
/// - **New** and **Edit** open the inspector (the contact pane's place from 600px, the editor sheet under
///   600px); with an inspector already open with changes, it asks "Discard changes?" first.
/// - **Delete:** one contact goes to Recently deleted at once, with an Undo toast (no dialog); several ask
///   "Delete 3 contacts?" first. Followed contacts are never deleted: the actions count only the contacts
///   the host owns, and say why the others are left out.
/// - **Undo** takes back the newest change this app made ([ContactsController.undoStack]), after its toast
///   too: ⌘Z and Edit, Undo, or "More actions" on a phone.
class ContactActions {
  ContactActions({required this.controller, required this.toasts, required this.context});

  final ContactsController controller;
  final ToastController toasts;

  /// A context under the app's Navigator and its theme, for dialogs, sheets and the layout.
  final BuildContext Function() context;

  bool get _phone => AppLayout.isPhone(context());

  // ---------------------------------------------------------------------------------------------------
  // Words.
  // ---------------------------------------------------------------------------------------------------

  static const newLabel = 'New contact';
  static const editLabel = 'Edit contact';
  static const deleteOneLabel = 'Delete contact';
  static String deleteManyLabel(int n) => 'Delete $n contacts…';
  static const editButton = 'Edit';
  static const nothingToUndo = 'There is nothing to undo.';
  static const fromMacReason = 'Contacts from this Mac are changed in Contacts.';
  static const fromICloudReason = 'Contacts from an iCloud account are changed in that account.';

  /// The reason [id] cannot be changed here.
  String reasonFor(String id) => controller.isFromThisMac(id) ? fromMacReason : fromICloudReason;

  // ---------------------------------------------------------------------------------------------------
  // New and Edit.
  // ---------------------------------------------------------------------------------------------------

  /// Leaves an open inspector, asking first when it has changes. True when none is open now.
  Future<bool> leaveEditor() async {
    final edit = controller.editing;
    if (edit == null) return true;
    final state = edit.inspector.currentState;
    if (state == null) {
      controller.endEdit();
      return true;
    }
    return state.requestClose();
  }

  Future<void> newContact() async {
    if (!await leaveEditor()) return;
    controller.startNew();
    if (_phone) await _sheet();
  }

  /// Opens the inspector on [id] when the host owns it.
  Future<void> edit(String id) async {
    if (!controller.isEditable(id)) return;
    if (controller.editing?.id == id) return;
    if (!await leaveEditor()) return;
    final detail = controller.detailOf(id);
    ContactDetailOut? contact = detail is DetailReady ? detail.contact : null;
    contact ??= await controller.backend.contact(id).catchError((Object _) => null);
    if (contact == null) return;
    controller.startEdit(contact);
    if (_phone) await _sheet();
  }

  /// The editor sheet on a phone. It follows [ContactsController.editing], so Reload swaps the form inside it.
  Future<void> _sheet() => showSheet<void>(
        context: context(),
        builder: (_) => ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final edit = controller.editing;
            if (edit == null) return const SizedBox.shrink();
            return editor(edit);
          },
        ),
      );

  /// The inspector for [edit], wherever it sits.
  Widget editor(ContactEdit edit) => ContactEditor(
        key: ValueKey(edit.serial),
        edit: edit,
        onSave: (form) async {
          final failure = await controller.save(edit, form);
          if (failure == null) _saved(edit);
          return failure;
        },
        onClosed: (_) => controller.endEdit(),
        onReload: () async {
          await controller.reloadEdit();
        },
      );

  void _saved(ContactEdit edit) {
    final entry = controller.lastSaved;
    if (entry == null) return;
    toasts.show(edit.original == null ? 'Contact added' : 'Changes saved', undo: () => _undo(entry));
  }

  // ---------------------------------------------------------------------------------------------------
  // Delete.
  // ---------------------------------------------------------------------------------------------------

  /// The contacts [ids] holds that the host lets this app delete.
  List<String> deletable(List<String> ids) => [for (final id in ids) if (controller.isEditable(id)) id];

  /// The label of the delete action for [ids] ("Delete contact", "Delete 3 contacts…"), counting only those
  /// it can act on.
  String deleteLabelFor(List<String> ids) {
    final n = deletable(ids).length;
    return n <= 1 ? deleteOneLabel : deleteManyLabel(n);
  }

  /// Deletes the selected contacts (or the open one): one at once with Undo, several after a Dialog.
  Future<void> deleteSelected() => delete(controller.selectedIds);

  Future<void> delete(List<String> ids) async {
    final targets = deletable(ids);
    if (targets.isEmpty) return;
    if (!await leaveEditorFor(targets)) return;
    final order = controller.selection.rows.isNotEmpty
        ? controller.selection.rows
        : [for (final e in controller.entries) e.id];
    if (targets.length == 1) {
      final id = targets.single;
      final name = controller.nameOf(id);
      final result = await controller.delete(targets, rowsInOrder: order);
      final entry = result.entry;
      if (result.failure != null || entry == null) {
        controller.showPaneError(id, deleteFailed(name, result.failure));
        return;
      }
      toasts.show('Contact deleted', undo: () => _undo(entry));
      return;
    }
    final names = [for (final id in targets) controller.nameOf(id)];
    final remaining = [...targets];
    final undoIds = <String>[];
    final deletedNames = <String>[];
    await showMyDataDialog(
      context: context(),
      builder: (_) => MyDataDialog(
        title: 'Delete ${targets.length} contacts?',
        message: '${summariseNames(names)} go to Recently deleted. You can restore them from there for 30 days.',
        confirmLabel: 'Delete ${targets.length} contacts',
        destructive: true,
        workingLabel: 'Deleting…',
        workingAnnouncement: 'Deleting ${targets.length} contacts',
        onConfirm: () async {
          final result = await controller.delete([...remaining], rowsInOrder: order, remember: false);
          remaining.removeWhere(result.done.contains);
          if (result.entry != null) {
            undoIds.addAll(result.entry!.undoIds);
            deletedNames.addAll(result.entry!.names);
          }
          if (result.failure == null) return null;
          final done = targets.length - remaining.length;
          return 'The contacts could not all be deleted. ${_reason(result.failure!)} '
              '${done == 0 ? '' : '$done of them went to Recently deleted. '}Check that the host is running, '
              'then try again.';
        },
      ),
    );
    // One toast and one Undo for every contact deleted, even when the dialog's button was pressed again after
    // a failure, or cancelled after deleting some.
    final n = targets.length - remaining.length;
    if (n == 0) return;
    final entry = UndoEntry(
      action: n == 1 ? 'Delete contact' : 'Delete $n contacts',
      undoIds: undoIds,
      names: deletedNames,
      undone: n == 1 ? 'Contact restored' : '$n contacts restored',
    );
    if (undoIds.isNotEmpty) controller.remember(entry);
    toasts.show(n == 1 ? 'Contact deleted' : '$n contacts deleted',
        undo: undoIds.isEmpty ? null : () => _undo(entry));
  }

  /// Before deleting the contact the inspector is open on: leave it (asking when it has changes).
  Future<bool> leaveEditorFor(List<String> ids) async {
    final editing = controller.editing?.id;
    if (editing == null || !ids.contains(editing)) return true;
    return leaveEditor();
  }

  static String _reason(WriteFailure f) => switch (f) {
        NoAnswer() => 'The host did not answer.',
        Gone() => 'One of them is no longer on your host.',
        Refused() => 'One of them cannot be deleted here.',
        ChangedElsewhere() => 'One of them changed since; look at it again first.',
        FieldErrors() => 'The host refused.',
      };

  /// The line in the contact pane when deleting one contact failed.
  static String deleteFailed(String name, WriteFailure? f) => switch (f) {
        ChangedElsewhere() => '$name changed since you opened it, so it was not deleted. Look at it again, then '
            'delete it.',
        Gone() => '$name is no longer on your host.',
        Refused() => '$name cannot be deleted here.',
        _ => '$name could not be deleted. The host did not answer. Check that it is running, then try again.',
      };

  // ---------------------------------------------------------------------------------------------------
  // Undo.
  // ---------------------------------------------------------------------------------------------------

  /// The newest change Undo takes back, or null.
  UndoEntry? get undoable => controller.undoStack.isEmpty ? null : controller.undoStack.last;

  /// ⌘Z, Edit, Undo and "More actions" on a phone, after the toast has gone.
  Future<void> undoLast() async {
    final entry = undoable;
    if (entry == null) return;
    final result = await _undo(entry);
    toasts.show(result.message);
  }

  Future<UndoResult> _undo(UndoEntry entry) async => UndoResult(await controller.undo(entry));

  /// Undo and Redo name the action in the menu bar's title case ("Delete Contact").
  String? get undoTitle => undoable == null ? null : menuTitleCase(undoable!.action);

  /// "Undo delete contact", the first item of a phone's "More actions".
  MenuItem undoMenuItem() {
    final entry = undoable;
    return MenuItem(
      label: entry == null ? 'Undo' : 'Undo ${entry.action[0].toLowerCase()}${entry.action.substring(1)}',
      enabled: entry != null,
      disabledReason: entry == null ? nothingToUndo : null,
      onSelected: () => unawaited(undoLast()),
    );
  }

  // ---------------------------------------------------------------------------------------------------
  // Menus.
  // ---------------------------------------------------------------------------------------------------

  /// A row's Menu, or the contact pane's "More actions": Edit contact, then Delete contact (or "Delete 3
  /// contacts…" when the row is one of several selected). For a followed contact both are disabled with the
  /// reason (design/components/Menu).
  List<MenuEntry> menuFor(String id) {
    final several = controller.selection.count > 1 && controller.selection.isSelected(id);
    final ids = several ? controller.selection.selected : [id];
    final canEdit = controller.isEditable(id) && !several;
    final canDelete = deletable(ids).isNotEmpty;
    final reason = several
        ? (canDelete ? null : 'None of them can be deleted here. They come from sources and are changed there.')
        : reasonFor(id);
    return [
      MenuItem(
        label: editLabel,
        shortcut: AppMenuBar.editShortcut.activator(Theme.of(context()).platform),
        enabled: canEdit,
        disabledReason: canEdit ? null : (several ? 'Edit one contact at a time.' : reason),
        onSelected: () => unawaited(edit(id)),
      ),
      const MenuSeparator(),
      MenuItem(
        label: deleteLabelFor(ids),
        shortcut: AppMenuBar.listDeleteActivator(Theme.of(context()).platform),
        destructive: true,
        enabled: canDelete,
        disabledReason: canDelete || canEdit ? null : (several ? reason : null),
        onSelected: () => unawaited(delete(ids)),
      ),
    ];
  }
}
