import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// One step of the Import page: its title (`display-lg`, a heading that takes focus when the step changes),
/// an optional line under it, the step's sections in a reading column (`content-max`) on `bg`, and an
/// optional footer bar that stays put while the column scrolls (design/components/ImportFlow, "The page").
class StepPage extends StatelessWidget {
  const StepPage({
    super.key,
    required this.title,
    required this.titleFocus,
    this.subtitle,
    required this.children,
    this.footer,
    this.scroll,
    this.macTitleShown = true,
  });

  final String title;

  /// False: in the Mac frame the title is not drawn (the toolbar's "Import" says it), only read and
  /// focused: the Choose step, whose title would repeat the toolbar's.
  final bool macTitleShown;

  /// Focus moves here when the step changes (ImportFlow, "Keyboard": "Every step change moves focus to
  /// the new title").
  final FocusNode titleFocus;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;
  final ScrollController? scroll;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final layout = AppLayout.of(context);
    // The Mac frame: Mac margins, the step's title as the pane's title (`pane-title`) under the toolbar's
    // "Import", and the steps in a centred column at `content-width`, as a Settings-style form.
    final mac = MacWindow.of(context);
    final pad = mac ? context.space(5) : PageScaffold.paddingFor(context.look, layout);
    final insets = MediaQuery.paddingOf(context);
    final frameName = AppFrame.phoneAppNameOf(context);
    final titleStyle = context.type(frameName != null ? MyDataTypeRole.title : MyDataTypeRole.displayLg);
    final hidden = mac && !macTitleShown;
    final column = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Focus(
        focusNode: titleFocus,
        child: hidden
            ? Semantics(header: true, label: title, child: const SizedBox.shrink())
            : Semantics(header: true, child: Text(title, style: titleStyle.copyWith(color: c.ink))),
      ),
      if (subtitle != null) ...[
        SizedBox(height: context.space(2)),
        Text(subtitle!, style: context.type(MyDataTypeRole.body).copyWith(color: c.inkMuted)),
      ],
      for (var i = 0; i < children.length; i++) ...[
        SizedBox(height: i == 0 ? (hidden ? 0 : PageScaffold.titleGap(context.look)) : PageScaffold.gap(context.look)),
        children[i],
      ],
    ]);
    final body = DefaultTextStyle.merge(
      style: context.type(MyDataTypeRole.body).copyWith(color: c.ink),
      child: SingleChildScrollView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(pad + insets.left, pad + insets.top, pad + insets.right,
            footer == null ? pad + insets.bottom : pad),
        child: Align(
          alignment: mac ? AlignmentDirectional.topCenter : AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: mac ? MyDataMacSize.contentWidth : MyDataSize.contentMax),
            child: column,
          ),
        ),
      ),
    );
    if (footer == null) return body;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: body),
      Container(height: 1, color: c.line),
      Padding(
        padding: EdgeInsets.fromLTRB(pad + insets.left, context.space(4), pad + insets.right, context.space(4) + insets.bottom),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: MyDataSize.contentMax), child: footer),
        ),
      ),
    ]);
  }
}

/// The footer bar of a step with a main action: the reason line (when the main action is disabled) or the
/// failure line at the start, then the plain button, then the filled one at the end edge, `space-2` apart.
/// On a phone the filled button is full width and the plain one is under it.
class StepFooter extends StatelessWidget {
  const StepFooter({super.key, this.reason, this.failure, required this.buttons});

  /// Why the main action is disabled, a full sentence in `ink-muted`.
  final String? reason;

  /// A failure, in `danger`, read at once.
  final String? failure;

  /// The plain button, then the filled one.
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final phone = AppLayout.isPhone(context);
    final line = failure != null
        ? Semantics(liveRegion: true, child: Text(failure!, style: context.type(MyDataTypeRole.body).copyWith(color: c.danger)))
        : reason != null
            ? Text(reason!, style: context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted))
            : null;
    if (phone) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (line != null) ...[line, SizedBox(height: context.space(2))],
        for (var i = buttons.length - 1; i >= 0; i--) ...[
          buttons[i],
          if (i > 0) SizedBox(height: ButtonRow.gap(context.look)),
        ],
      ]);
    }
    return Row(children: [
      Expanded(child: line ?? const SizedBox.shrink()),
      SizedBox(width: context.space(4)),
      ButtonRow(alignment: WrapAlignment.end, children: buttons),
    ]);
  }
}

/// A part of a GroupedSection that is one sentence (or a name over a sentence), with a row's padding: the
/// loss report's rows, "Changed on the way in", "Not updated".
class TextRowPart extends StatelessWidget {
  const TextRowPart(this.text, {super.key, this.title});
  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: context.density.rowHeight),
      child: Padding(
        padding: GroupedRow.padding(context.look),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) Text(title!, style: context.type(MyDataTypeRole.bodyStrong).copyWith(color: c.ink)),
            Text(text, style: context.type(title == null ? MyDataTypeRole.body : MyDataTypeRole.caption).copyWith(
                color: title == null ? c.ink : c.inkMuted)),
          ]),
        ),
      ),
    );
  }
}

/// A small heading over something that is not a group (the DropZone), placed as a group's heading is.
class PlainHeading extends StatelessWidget {
  const PlainHeading(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: GroupedList.headingPadding(context.look),
        child: Semantics(
          header: true,
          child: Text(text, style: context.type(MyDataTypeRole.label).copyWith(color: context.colors.inkMuted)),
        ),
      );
}

/// A disclosure in a group: its title and a chevron at the end that turns a quarter on opening
/// (`aria-expanded`); open, the [child] shows under it in place. Return or Space opens and closes it.
class DisclosurePart extends StatelessWidget {
  const DisclosurePart({
    super.key,
    required this.title,
    required this.open,
    required this.onToggle,
    required this.child,
    this.focusNode,
    this.action,
  });

  final String title;

  /// A word before the chevron saying what opening does, when the title is a fact ("2 cards could not be
  /// read" … "Show which").
  final String? action;
  final bool open;
  final VoidCallback onToggle;
  final Widget child;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shape = GroupedRow.shapeOf(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Semantics(
        expanded: open,
        child: Pressable(
          onPressed: onToggle,
          borderRadius: open ? BorderRadius.only(topLeft: shape.topLeft, topRight: shape.topRight) : shape,
          scaleOnPress: false,
          hoverFill: c.surfaceHover,
          focusNode: focusNode,
          semanticLabel: action == null ? title : '$title, $action',
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: MacWindow.of(context) ? MacFormRow.minHeight(context.look) : context.density.rowHeight),
              child: Padding(
                padding: MacWindow.of(context) ? MacFormRow.padding(context.look) : GroupedRow.padding(context.look),
                child: Row(children: [
                  Expanded(child: Text(title, style: context.type(MyDataTypeRole.bodyStrong).copyWith(color: c.ink))),
                  if (action != null) ...[
                    SizedBox(width: context.space(3)),
                    Text(action!, style: context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted)),
                    SizedBox(width: context.space(1)),
                  ],
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: MyDataMotion.reduced(context) ? Duration.zero : context.motion.fast,
                    curve: context.motion.standard,
                    child: Icon(context.icon(MyDataIcon.chevronRight), size: context.density.icon, color: c.inkMuted),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
      if (open)
        Padding(
          padding: EdgeInsets.fromLTRB(context.space(4), 0, context.space(4), context.space(4)),
          child: child,
        ),
    ]);
  }
}

/// Numbered steps quoting a vendor's own menu names, with an optional line before and after.
class NumberedSteps extends StatelessWidget {
  const NumberedSteps({super.key, required this.steps, this.before, this.after});
  final List<String> steps;
  final String? before;
  final String? after;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = context.type(MyDataTypeRole.body).copyWith(color: c.ink);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (before != null) ...[Text(before!, style: style), SizedBox(height: context.space(2))],
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: context.space(1)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: context.space(6), child: Text('${i + 1}.', style: style)),
            Expanded(child: Text(steps[i], style: style)),
          ]),
        ),
      if (after != null) ...[
        SizedBox(height: context.space(2)),
        Text(after!, style: context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted)),
      ],
    ]);
  }
}

/// Announces [message] politely (a step's new title, an undone import) or at once (a failure).
void announce(BuildContext context, String message, {bool assertive = false}) {
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
    assertiveness: assertive ? Assertiveness.assertive : Assertiveness.polite,
  );
}
