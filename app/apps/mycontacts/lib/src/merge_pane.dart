import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mydata_core/mydata_core.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'merge.dart';

/// The Merge pane (design/components/DuplicatePair, "Merge"): a title naming the question, the Select "Keep
/// the name and details of", the DuplicatePair of the contacts with "After merging" (the host's preview,
/// H6c), the note on what is left out, then the plain button and "Merge" (filled).
///
/// - From a multi-selection the title is "Merge 2 contacts?" and the plain button is Cancel (Escape too);
///   in Review the title is "Same person?" and the plain button is "Not the same person".
/// - ⌘Return presses Merge while focus is in the pane and no Select is open.
/// - Merging: the button says "Merging…" at its old width and the Select is read-only.
class MergePane extends StatelessWidget {
  const MergePane({
    super.key,
    required this.session,
    required this.title,
    this.reason,
    required this.plainLabel,
    required this.onPlain,
    required this.onMerge,
    this.escapeCancels = true,
  });

  final MergeSession session;
  final String title;

  /// The line under the title in Review: why the two may be one person ("They share an email address.").
  final String? reason;

  /// "Cancel" or "Not the same person".
  final String plainLabel;
  final VoidCallback onPlain;
  final VoidCallback onMerge;

  /// Escape is Cancel (the multi-selection pane); Review's plain button has no key.
  final bool escapeCancels;

  static const keepLabel = 'Keep the name and details of';
  static const mergeLabel = 'Merge';
  static const mergingLabel = 'Merging…';
  static const leftOutNote = 'What is left out stays with the originals in Recently deleted for 30 days.';

  /// "Merge 2 contacts?"
  static String mergeTitle(int n) => 'Merge $n contacts?';

  /// "Added 2 Oct 2026".
  static String added(ContactDetailOut c) {
    final d = DateTime.tryParse(c.createdAt);
    return d == null ? '' : 'Added ${MyDataDates.day(d.toLocal())}';
  }

  /// "A new contact. These two go to Recently deleted."
  static String afterCaption(int n) =>
      'A new contact. ${n == 2 ? 'These two go' : 'These $n go'} to Recently deleted.';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final c = context.colors;
          final s = session;
          final contacts = s.inOrder;
          final apple = Theme.of(context).platform == TargetPlatform.macOS;
          final canMerge = !s.loading && !s.gone && s.preview != null && !s.previewing;
          final versions = [
            for (final x in contacts) ContactPair.ofContact(x, caption: added(x)),
          ];
          final preview = s.preview;
          final mac = MacWindow.of(context);
          final after = preview == null
              ? (s.loading ? null : PairAfter(title: PairAfter.mergingTitle, caption: afterCaption(s.ids.length), fields: const {}))
              : ContactPair.afterOfMerge(
                  preview,
                  caption: afterCaption(s.ids.length),
                  notes: contacts.where((x) => x.note.trim().isNotEmpty).length,
                );
          final shown = versions.isEmpty
              ? [for (final id in s.ids) PairVersion(name: id, caption: '', fields: const {})]
              : versions;
          final actions = [
            // The Mac frame: push buttons, the plain one grey.
            Button(
              label: plainLabel,
              variant: mac ? ButtonVariant.tonal : ButtonVariant.plain,
              onPressed: s.working ? _inert : onPlain,
            ),
            SteadyWidthButton(
              label: mergeLabel,
              shown: s.working ? mergingLabel : mergeLabel,
              variant: ButtonVariant.filled,
              onPressed: !canMerge ? null : (s.working ? _inert : onMerge),
            ),
          ];
          // The Mac frame: the same pair as a Mac table on the pane's ground (MacPairTable).
          final Widget pair = mac
              ? MacPairTable(
                  mode: PairMode.merge,
                  loading: s.loading || versions.isEmpty,
                  versions: shown,
                  after: after,
                  afterLoading: s.previewing,
                  note: leftOutNote,
                  message: s.message,
                  messageIsError: s.messageIsError,
                  // The Mac frame: the buttons sit at the top, beside the choice, always in view.
                  actions: const [],
                )
              : DuplicatePair(
                  mode: PairMode.merge,
                  loading: s.loading || versions.isEmpty,
                  versions: shown,
                  after: after,
                  afterLoading: s.previewing,
                  note: leftOutNote,
                  message: s.message,
                  messageIsError: s.messageIsError,
                  actions: actions,
                );
          final names = contacts.length == s.ids.length && contacts.isNotEmpty;
          return CallbackShortcuts(
            bindings: {
              SingleActivator(LogicalKeyboardKey.enter, meta: apple, control: !apple): () {
                if (canMerge && !s.working) onMerge();
              },
              if (escapeCancels) const SingleActivator(LogicalKeyboardKey.escape): () {
                if (!s.working) onPlain();
              },
            },
            child: FocusScope(
              child: FormBusy(
                busy: s.working,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                  Semantics(header: true, child: Text(title, style: context.type(MyDataTypeRole.displayLg).copyWith(color: c.ink))),
                  if (reason != null) ...[
                    SizedBox(height: context.space(2)),
                    Text(reason!, style: context.type(MyDataTypeRole.body).copyWith(color: c.inkMuted)),
                  ],
                  SizedBox(height: context.space(4)),
                  if (names && mac)
                    // The Mac frame: a pop-up button after its label, as a Mac form writes it.
                    Row(children: [
                      Text('$keepLabel:', style: MyDataMacType.body.copyWith(color: context.mac.label)),
                      SizedBox(width: context.space(2)),
                      Flexible(
                        child: MacPopUpButton<String>(
                          label: keepLabel,
                          items: [for (final x in contacts) MacPopUpItem(value: x.id, title: x.displayName)],
                          value: s.namesFrom,
                          onChanged: s.working ? null : (id) => unawaited(s.keepDetailsOf(id)),
                          disabledReason: s.working ? 'The contacts are being merged.' : null,
                          autofocus: true,
                        ),
                      ),
                      SizedBox(width: context.space(4)),
                      const Spacer(),
                      ButtonRow(alignment: WrapAlignment.end, children: actions),
                    ])
                  else if (mac)
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: ButtonRow(alignment: WrapAlignment.end, children: actions),
                    )
                  else if (names)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: MyDataSize.inspectorWidth),
                        child: MyDataSelect<String>(
                          label: keepLabel,
                          items: [
                            for (final x in contacts) SelectItem(value: x.id, title: x.displayName, caption: added(x)),
                          ],
                          value: s.namesFrom,
                          onChanged: s.working ? null : (id) => unawaited(s.keepDetailsOf(id)),
                          disabledReason: s.working ? 'The contacts are being merged.' : null,
                          autofocus: true,
                        ),
                      ),
                    ),
                  SizedBox(height: mac ? context.space(5) : context.space(4)),
                  pair,
                ]),
              ),
            ),
          );
        },
      );

  static void _inert() {}
}

/// The toast after a merge: "Contacts merged", and what the host left out, in words ("Contacts merged. 1
/// birthday and 1 job title were left out.").
String mergedToast(MergeOut out) {
  final words = ContactPair.leftOutWords(out.leftOut);
  if (words.isEmpty) return 'Contacts merged';
  final n = out.leftOut.fold<int>(0, (a, l) => a + l.count);
  return 'Contacts merged. $words ${n == 1 ? 'was' : 'were'} left out.';
}
