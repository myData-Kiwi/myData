import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';
import '../theme/motion.dart';
import '../theme/theme.dart';
import 'badge.dart';
import 'button.dart';
import 'pressable.dart';
import 'status.dart';

/// Where an irreversible action stands.
enum ApprovalState {
  /// Held until the user decides: the "Needs approval" chip, `shadow-2` and the three actions.
  pending,

  /// Approved and done: the card's past-tense label ("Sent", "Deleted") on `success-soft`.
  approved,

  /// Rejected: "Rejected" on `surface-sunken`. Nothing was done.
  rejected,

  /// Approved, but running it failed: "Failed" on `danger-soft`, with the error.
  failed,
}

/// The card that asks the user before the assistant does something that cannot be undone
/// (design/components/ApprovalCard).
///
/// - A solid `surface` card with `radius-lg`, a 1px `line-strong` edge and `shadow-2`, so it stands above the
///   conversation; after a decision the shadow drops to `shadow-1`. This structure is the same in every
///   theme: a theme gives it its colours, fonts and corners only, never a pattern, glass or another button
///   style (the Approve is filled, or outlined where the theme's primary is an outline; [Button.approval]).
/// - The [question] ("Send this email?") in the `title` style, with a chip beside it: "Needs approval"
///   (`warning`) while [ApprovalState.pending]; then [decidedLabel] (`success`), "Rejected" (neutral) or
///   "Failed" (`danger`, with [error] below the source line). Decided 2026-10-12.
/// - Every argument in full, exactly as it will run, in a `surface-sunken` well with `radius-md`. Nothing is
///   summarised or shortened. Names are `caption` in `ink-muted`; values are `body`, or `mono` when they
///   look like an address or a path ([looksLikeAddress]).
/// - A `caption` line names the source of the facts, with an underlined `link` ([onSourceTap]).
/// - Actions in order, `space-2` apart: the filled [approveLabel] ("Approve and send"), a tonal Edit (only
///   when [onEdit] is given) and a plain Reject. They are removed after a decision.
/// - The chip and shadow change over `fast`; with reduced motion only fades remain and the card's height
///   jumps instead of easing.
///
/// - The card is a region named [pendingRegionLabel] ("Approval needed", as in the preview) while pending and
///   [decidedRegionLabel] after.
/// - When a decision removes the actions while one of them has keyboard focus, focus moves to the card
///   itself (not a Tab stop of its own; it shows the focus ring), so the next Tab continues inside the card
///   instead of starting again at the top of the window.
///
/// Presentation only: approval is given by the user in an app, never by an "always allow". The host holds
/// the call; the assistant package passes its state in.
class ApprovalCard extends StatefulWidget {
  const ApprovalCard({
    super.key,
    required this.question,
    required this.arguments,
    required this.approveLabel,
    required this.decidedLabel,
    required this.onApprove,
    required this.onReject,
    this.state = ApprovalState.pending,
    this.onEdit,
    this.sourceNote,
    this.sourceLabel,
    this.onSourceTap,
    this.error,
  });

  /// What will happen, as a question in sentence case: "Send this email?".
  final String question;

  /// Every argument of the held call as (name, value), in order, exactly as it will run. Shown in full.
  final List<(String name, String value)> arguments;

  /// The filled button: "Approve and" plus the action ("Approve and send").
  final String approveLabel;

  /// The chip after approval: the past tense of the action ("Sent", "Deleted").
  final String decidedLabel;

  /// Approves the held call. Null disables the button (for example while a decision is being sent).
  final VoidCallback? onApprove;

  /// Rejects the held call. Null disables the button.
  final VoidCallback? onReject;

  final ApprovalState state;

  /// Opens the call for editing. Null leaves the Edit button out.
  final VoidCallback? onEdit;

  /// An optional sentence before the source ("Every fact in this message came from your data.").
  final String? sourceNote;

  /// The source the facts came from ("Train booking confirmation"). Null leaves "Source:" out.
  final String? sourceLabel;

  /// Opens the source. With it [sourceLabel] is a link; without it, plain text.
  final VoidCallback? onSourceTap;

  /// What went wrong, for [ApprovalState.failed]: what happened and what to do next.
  final String? error;

  /// The card region's accessible name while pending (preview: `aria-label="Approval needed"`).
  static const pendingRegionLabel = 'Approval needed';

  /// The card region's accessible name after a decision; the chip says which one.
  static const decidedRegionLabel = 'Approval request';

  /// The chip while pending (decided 2026-10-12: a `warning` chip).
  static const pendingLabel = 'Needs approval';

  /// The chip after a rejection, on `surface-sunken`.
  static const rejectedLabel = 'Rejected';

  /// The chip after a failure, on `danger-soft`.
  static const failedLabel = 'Failed';

  /// The tonal button's label.
  static const editLabel = 'Edit';

  /// The plain button's label.
  static const rejectLabel = 'Reject';

  /// Before [sourceLabel] on the source line.
  static const sourcePrefix = 'Source: ';

  /// Card padding: `space-5` (design/README.md "Cards have space-5 padding"; the preview's 20px).
  static double padding(MyDataLook look) => look.space(5);

  /// The card's bottom padding when the source line has a link: `space-2`, plus the link target's own air.
  static double linkedBottomPadding(MyDataLook look) => look.space(2);

  /// Between the header, the well, the source line and the actions. The preview's 14px; the nearest
  /// token, `space-3`.
  static double gap(MyDataLook look) => look.space(3);

  /// Between the question and the chip (the preview's 12px).
  static double headerGap(MyDataLook look) => look.space(3);

  /// The well's padding. The preview's 14px 16px: `space-3` (nearest to 14) by `space-4`.
  static EdgeInsets wellPadding(MyDataLook look) => EdgeInsets.symmetric(vertical: look.space(3), horizontal: look.space(4));

  /// Preview: the argument names sit in a 72px column. A minimum: a longer name widens the column, up to
  /// [nameMaxFraction] of the well.
  static const nameWidth = 72.0;

  /// The card's edge, in `line-strong`, in every theme.
  static const edgeWidth = 1.0;

  /// The widest the name column grows, as a fraction of the well. Not in the spec.
  static const nameMaxFraction = 0.4;

  /// Preview: 8px between arguments (`space-2`) and 12px between a name and its value (`space-3`).
  static double rowGap(MyDataLook look) => look.space(2);
  static double columnGap(MyDataLook look) => look.space(3);

  /// Whether [value] reads as an address or a path, so it is shown in `mono` (design/README.md "Type":
  /// mono for paths, addresses and copied values): an email address (`Name <a@b.c>` too), a URL, an
  /// absolute or home-relative path, or a comma-separated list of these.
  static bool looksLikeAddress(String value) {
    final v = value.trim();
    if (v.isEmpty || v.contains('\n')) return false;
    return v
        .split(RegExp(r',\s*'))
        .every((part) => _email.hasMatch(part) || _named.hasMatch(part) || _url.hasMatch(part) || _path.hasMatch(part));
  }

  static final _email = RegExp(r'^[^\s@<>,]+@[^\s@<>,]+\.[^\s@<>,]+$');
  static final _named = RegExp(r'^[^<>@]*<[^\s@<>,]+@[^\s@<>,]+\.[^\s@<>,]+>$');
  static final _url = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*:\/\/\S+$');
  static final _path = RegExp(r'^(?:~|\.{1,2})?\/[^\s\/]|^[A-Za-z]:\\|^\\\\\S');

  @override
  State<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<ApprovalCard> {
  /// Holds no focus itself; tells whether one of the actions has it.
  final _actionsNode = FocusNode(debugLabel: 'ApprovalCard actions', canRequestFocus: false, skipTraversal: true);

  /// The card: focused only by code, after a decision removes the focused action.
  final _cardNode = FocusNode(debugLabel: 'ApprovalCard', skipTraversal: true);

  bool _ring = false;

  @override
  void didUpdateWidget(ApprovalCard old) {
    super.didUpdateWidget(old);
    if (old.state == ApprovalState.pending && widget.state != ApprovalState.pending && _actionsNode.hasFocus) {
      // The focused button is about to be excluded and removed. Move focus after this frame, when it is gone.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cardNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _actionsNode.dispose();
    _cardNode.dispose();
    super.dispose();
  }

  double get padding => ApprovalCard.padding(context.look);
  double get linkedBottomPadding => ApprovalCard.linkedBottomPadding(context.look);
  double get gap => ApprovalCard.gap(context.look);
  double get headerGap => ApprovalCard.headerGap(context.look);
  double get rowGap => ApprovalCard.rowGap(context.look);
  double get columnGap => ApprovalCard.columnGap(context.look);
  static const sourcePrefix = ApprovalCard.sourcePrefix;

  bool get _pending => widget.state == ApprovalState.pending;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = MyDataMotion.reduced(context);
    final linked = widget.sourceLabel != null && widget.onSourceTap != null;
    final hasSource = widget.sourceNote != null || widget.sourceLabel != null;

    // A link line is control-height tall, which leaves about `space-3` of air above and below its text. So
    // after it the actions need no gap, and the card's bottom padding gives up that air: when the link line
    // is last (after a decision) the card still ends about `space-5` below the text.
    final lastPadding = linked
        ? EdgeInsets.only(bottom: padding - linkedBottomPadding)
        : EdgeInsets.only(top: gap);
    final Widget bottom = switch (widget.state) {
      ApprovalState.pending => Padding(
        key: const ValueKey('actions'),
        padding: lastPadding,
        child: Focus(
          focusNode: _actionsNode,
          includeSemantics: false,
          child: ButtonRow(
            children: [
              Button(
                  label: widget.approveLabel, variant: ButtonVariant.filled, approval: true, onPressed: widget.onApprove),
              if (widget.onEdit != null) Button(label: ApprovalCard.editLabel, onPressed: widget.onEdit),
              Button(label: ApprovalCard.rejectLabel, variant: ButtonVariant.plain, onPressed: widget.onReject),
            ],
          ),
        ),
      ),
      ApprovalState.failed when widget.error != null => Padding(
        key: const ValueKey('error'),
        padding: lastPadding,
        child: Text(widget.error!, style: context.typeScale.body.copyWith(color: c.danger)),
      ),
      _ => const SizedBox(key: ValueKey('none'), width: double.infinity),
    };
    final bottomKey = bottom.key;

    Widget bottomSwitcher = AnimatedSwitcher(
      duration: context.motion.fast,
      switchInCurve: context.motion.standard,
      switchOutCurve: context.motion.standard,
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
      // Outgoing actions fade out but can no longer be pressed, focused or read.
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: child.key == bottomKey
            ? child
            : IgnorePointer(
                child: ExcludeFocus(child: ExcludeSemantics(child: child)),
              ),
      ),
      child: bottom,
    );
    if (!reduced) {
      bottomSwitcher = AnimatedSize(
        duration: context.motion.fast,
        curve: context.motion.standard,
        alignment: Alignment.topLeft,
        child: bottomSwitcher,
      );
    }

    final card = AnimatedContainer(
      duration: context.motion.fast,
      curve: context.motion.standard,
      padding: EdgeInsets.fromLTRB(padding, padding, padding, linked ? linkedBottomPadding : padding),
      decoration: context.radius.decorate(BoxDecoration(
        color: c.surface,
        borderRadius: MyDataRadii.lg(context.look),
        boxShadow: _pending ? context.shadows.shadow2 : context.shadows.shadow1,
      )),
      // Over the content, so the edge takes no room from it.
      foregroundDecoration: context.radius.decorate(BoxDecoration(
        borderRadius: MyDataRadii.lg(context.look),
        border: Border.all(color: c.lineStrong, width: ApprovalCard.edgeWidth),
      )),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(c, reduced),
          SizedBox(height: gap),
          _well(c),
          if (hasSource) ...[if (!linked) SizedBox(height: gap), _source(c)],
          bottomSwitcher,
        ],
      ),
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _pending ? ApprovalCard.pendingRegionLabel : ApprovalCard.decidedRegionLabel,
      child: FocusableActionDetector(
        focusNode: _cardNode,
        // The region's semantics stay as they are; this node exists for keyboard focus only.
        includeFocusSemantics: false,
        onShowFocusHighlight: (v) => setState(() => _ring = v),
        child: FocusRing(visible: _ring, borderRadius: MyDataRadii.lg(context.look), child: card),
      ),
    );
  }

  Widget _header(MyDataColors c, bool reduced) {
    final chip = switch (widget.state) {
      ApprovalState.pending => const MyDataBadge(
        ApprovalCard.pendingLabel,
        key: ValueKey(ApprovalState.pending),
        tone: MyDataTone.warning,
      ),
      ApprovalState.approved => MyDataBadge(
        widget.decidedLabel,
        key: const ValueKey(ApprovalState.approved),
        tone: MyDataTone.success,
      ),
      ApprovalState.rejected => const MyDataBadge(
        ApprovalCard.rejectedLabel,
        key: ValueKey(ApprovalState.rejected),
        tone: MyDataTone.neutral,
      ),
      ApprovalState.failed => const MyDataBadge(
        ApprovalCard.failedLabel,
        key: ValueKey(ApprovalState.failed),
        tone: MyDataTone.danger,
      ),
    };
    Widget switcher = AnimatedSwitcher(
      duration: context.motion.fast,
      switchInCurve: context.motion.standard,
      switchOutCurve: context.motion.standard,
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerRight, children: [...previous, ?current]),
      child: chip,
    );
    if (!reduced) {
      switcher = AnimatedSize(
        duration: context.motion.fast,
        curve: context.motion.standard,
        alignment: Alignment.centerRight,
        child: switcher,
      );
    }
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(widget.question, style: context.typeScale.title.copyWith(color: c.ink)),
          ),
        ),
        SizedBox(width: headerGap),
        // The chip changes when the decision lands; screen readers announce the new word.
        Semantics(liveRegion: true, child: switcher),
      ],
    );
  }

  Widget _well(MyDataColors c) {
    final nameStyle = context.typeScale.caption.copyWith(color: c.inkMuted);
    TableRow row(int i, String name, String value) {
      final top = i == 0 ? 0.0 : rowGap;
      final Widget shown = value.isEmpty
          // An empty value is still shown, so the row is not mistaken for a missing one.
          ? Text('Empty', style: nameStyle)
          : Text(
              value,
              style: ApprovalCard.looksLikeAddress(value)
                  ? context.typeScale.mono.copyWith(color: c.ink)
                  : context.typeScale.body.copyWith(color: c.ink),
            );
      return TableRow(
        children: [
          Padding(
            padding: EdgeInsets.only(top: top, right: columnGap),
            child: Text(name, style: nameStyle),
          ),
          Padding(
            padding: EdgeInsets.only(top: top),
            child: shown,
          ),
        ],
      );
    }

    return Container(
      padding: ApprovalCard.wellPadding(context.look),
      decoration: context.radius.decorate(BoxDecoration(color: c.surfaceSunken, borderRadius: MyDataRadii.md(context.look))),
      child: Table(
        columnWidths: {
          0: MinColumnWidth(
            MaxColumnWidth(FixedColumnWidth(ApprovalCard.nameWidth + columnGap), IntrinsicColumnWidth()),
            FractionColumnWidth(ApprovalCard.nameMaxFraction),
          ),
          1: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [for (final (i, (name, value)) in widget.arguments.indexed) row(i, name, value)],
      ),
    );
  }

  Widget _source(MyDataColors c) {
    final style = context.typeScale.caption.copyWith(color: c.inkMuted);
    if (widget.sourceLabel == null || widget.onSourceTap == null) {
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            if (widget.sourceNote != null)
              TextSpan(text: widget.sourceLabel == null ? widget.sourceNote : '${widget.sourceNote!} '),
            if (widget.sourceLabel != null) TextSpan(text: '$sourcePrefix${widget.sourceLabel}'),
          ],
        ),
      );
    }
    final link = _SourceLink(label: widget.sourceLabel!, onTap: widget.onSourceTap!);
    // The link's target is control-height tall. On one line with the note, that line is 44px and its text
    // sits about `space-3` from the well and the actions, as in the preview. When the note does not fit
    // beside the link, the note takes its own line after a `space-3` gap and the link follows.
    return LayoutBuilder(
      builder: (context, constraints) {
        final one = '${widget.sourceNote == null ? '' : '${widget.sourceNote!} '}$sourcePrefix${widget.sourceLabel!}';
        final painter = TextPainter(
          text: TextSpan(text: one, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final fits = painter.width <= constraints.maxWidth;
        painter.dispose();
        Widget line(String prefix) => Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(prefix, style: style),
            Flexible(child: link),
          ],
        );
        if (fits) return line(widget.sourceNote == null ? sourcePrefix : '${widget.sourceNote!} $sourcePrefix');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: gap),
            if (widget.sourceNote != null) Text(widget.sourceNote!, style: style),
            line(sourcePrefix),
          ],
        );
      },
    );
  }
}

/// The source link: `link`, underlined (design/README.md "Links"), with a control-height target.
class _SourceLink extends StatelessWidget {
  const _SourceLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

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
        borderRadius: MyDataRadii.sm(context.look),
        semanticLabel: label,
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: context.density.controlHeight, minWidth: context.density.controlHeight),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                label,
                style: context.typeScale.caption.copyWith(
                  color: c.link,
                  decoration: TextDecoration.underline,
                  decorationColor: c.link,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
