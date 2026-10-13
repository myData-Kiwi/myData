import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'contact_page.dart';
import 'contacts_controller.dart';

/// The contacts screen (design/components/ContactList):
///
/// - **From 600px:** the list pane (search, letter groups) beside the contact pane, `space-8` apart. The
///   contact pane shows the selected contact; Up and Down in the list move the selection and the pane
///   follows at once.
/// - **Under 600px:** the list fills the screen, and pressing a contact pushes its page in, with a back
///   button. A link that opens a contact pushes its page too.
/// - A link to a contact the host does not have is one plain line: in the contact pane from 600px, above
///   the list under 600px.
class ContactsView extends StatefulWidget {
  const ContactsView({super.key, required this.controller, required this.onOpenLink});

  final ContactsController controller;
  final WebOpener onOpenLink;

  /// The list's content width at its widest (preview: `.list{flex:0 1 340px}`).
  static const listMaxWidth = 340.0;

  /// The list's content width at its narrowest, in a narrow window.
  static const listMinWidth = 240.0;

  /// The share of the window's content the list pane takes before it reaches [listMaxWidth].
  static const listShare = 0.4;

  /// Between the list and the contact pane (preview: `.two{gap:32px}`), split between their paddings so
  /// neither cuts off the groups' shadows.
  static const paneGap = MyDataSpace.s8;

  static const missingLinkText =
      'The contact that link opens is not on your host. It may have been deleted, '
      'or its source turned off in myData.';

  /// The back button of a pushed contact page.
  static const backLabel = 'Contacts';

  @override
  State<ContactsView> createState() => _ContactsViewState();
}

class _ContactsViewState extends State<ContactsView> {
  StreamSubscription<String>? _links;
  final _paneScroll = ScrollController();

  ContactsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _links = _controller.linkOpened.listen(_linkOpened);
  }

  @override
  void dispose() {
    _links?.cancel();
    _paneScroll.dispose();
    super.dispose();
  }

  bool get _phone => AppLayout.of(context) == AppLayout.phone;

  void _linkOpened(String id) {
    if (!mounted) return;
    if (_phone) {
      // One contact page at a time: a link replaces the page already open.
      Navigator.of(context).popUntil((route) => route.isFirst);
      _push(id);
    } else if (_paneScroll.hasClients) {
      _paneScroll.jumpTo(0);
    }
  }

  void _open(String id) {
    final changed = _controller.selectedId != id;
    _controller.open(id);
    if (_phone) {
      _push(id);
    } else if (changed && _paneScroll.hasClients) {
      _paneScroll.jumpTo(0);
    }
  }

  void _push(String id) {
    Widget page(BuildContext _) => _PushedContactPage(controller: _controller, id: id, onOpenLink: widget.onOpenLink);
    Navigator.of(context).push(
      // With reduced motion the page simply appears.
      MyDataMotion.reduced(context)
          ? PageRouteBuilder<void>(
              pageBuilder: (context, _, _) => page(context),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            )
          : MaterialPageRoute<void>(builder: page),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      final layout = AppLayout.of(context);
      final pad = PageScaffold.paddingFor(layout);
      final insets = MediaQuery.paddingOf(context);
      final missing = _controller.missingLinkId != null;

      if (layout == AppLayout.phone) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (missing)
              Padding(
                padding: EdgeInsets.fromLTRB(pad + insets.left, pad + insets.top, pad + insets.right, 0),
                child: const _PlainLine(ContactsView.missingLinkText),
              ),
            Expanded(
              child: ContactList(
                contacts: _controller.entries,
                selectedId: _controller.selectedId,
                onOpen: _open,
                padding: EdgeInsets.fromLTRB(
                  pad + insets.left,
                  (missing ? MyDataSpace.s4 : pad) + (missing ? 0 : insets.top),
                  pad + insets.right,
                  pad + insets.bottom,
                ),
              ),
            ),
          ],
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final half = ContactsView.paneGap / 2;
          final listWidth = (constraints.maxWidth * ContactsView.listShare - pad - half).clamp(
            ContactsView.listMinWidth,
            ContactsView.listMaxWidth,
          );
          final selected = _controller.selectedId;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: listWidth + pad + half + insets.left,
                child: ContactList(
                  contacts: _controller.entries,
                  selectedId: selected,
                  onOpen: _open,
                  padding: EdgeInsets.fromLTRB(pad + insets.left, pad + insets.top, half, pad + insets.bottom),
                ),
              ),
              Expanded(
                child: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  child: SingleChildScrollView(
                    controller: _paneScroll,
                    padding: EdgeInsets.fromLTRB(half, pad + insets.top, pad + insets.right, pad + insets.bottom),
                    child: Align(
                      alignment: AlignmentDirectional.topStart,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: MyDataSize.contentMax),
                        child: missing
                            ? const _PlainLine(ContactsView.missingLinkText)
                            : selected == null
                            ? const SizedBox.shrink()
                            : ContactPage(
                                key: ValueKey(selected),
                                controller: _controller,
                                id: selected,
                                onOpenLink: widget.onOpenLink,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// One sentence in `body` and `ink-muted`.
class _PlainLine extends StatelessWidget {
  const _PlainLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: MyDataType.body.copyWith(color: context.colors.inkMuted));
}

/// A contact's page pushed over the list under 600px, with a back button to the list. If the window
/// grows past 600px while it is open, it closes: the two panes then show the same contact.
class _PushedContactPage extends StatelessWidget {
  const _PushedContactPage({required this.controller, required this.id, required this.onOpenLink});

  final ContactsController controller;
  final String id;
  final WebOpener onOpenLink;

  @override
  Widget build(BuildContext context) {
    final layout = AppLayout.of(context);
    if (layout != AppLayout.phone) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
    }
    final pad = PageScaffold.paddingFor(layout);
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad + insets.left, pad + insets.top, pad + insets.right, pad + insets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Button(
                  label: ContactsView.backLabel,
                  icon: Icons.arrow_back_ios_new_rounded,
                  variant: ButtonVariant.plain,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: MyDataSpace.s4),
              ContactPage(controller: controller, id: id, onOpenLink: onOpenLink),
            ],
          ),
        ),
      ),
    );
  }
}
