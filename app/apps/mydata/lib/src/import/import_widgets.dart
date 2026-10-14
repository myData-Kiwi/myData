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
  });

  final String title;

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
    final pad = PageScaffold.paddingFor(layout);
    final insets = MediaQuery.paddingOf(context);
    final frameName = AppFrame.phoneAppNameOf(context);
    final titleStyle = frameName != null ? MyDataType.title : MyDataType.displayLg;
    final column = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Focus(
        focusNode: titleFocus,
        child: Semantics(header: true, child: Text(title, style: titleStyle.copyWith(color: c.ink))),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: MyDataSpace.s2),
        Text(subtitle!, style: MyDataType.body.copyWith(color: c.inkMuted)),
      ],
      for (var i = 0; i < children.length; i++) ...[
        SizedBox(height: i == 0 ? PageScaffold.titleGap : PageScaffold.gap),
        children[i],
      ],
    ]);
    final body = DefaultTextStyle.merge(
      style: MyDataType.body.copyWith(color: c.ink),
      child: SingleChildScrollView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(pad + insets.left, pad + insets.top, pad + insets.right,
            footer == null ? pad + insets.bottom : pad),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: MyDataSize.contentMax), child: column),
        ),
      ),
    );
    if (footer == null) return body;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: body),
      Container(height: 1, color: c.line),
      Padding(
        padding: EdgeInsets.fromLTRB(pad + insets.left, MyDataSpace.s4, pad + insets.right, MyDataSpace.s4 + insets.bottom),
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
        ? Semantics(liveRegion: true, child: Text(failure!, style: MyDataType.body.copyWith(color: c.danger)))
        : reason != null
            ? Text(reason!, style: MyDataType.caption.copyWith(color: c.inkMuted))
            : null;
    if (phone) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        if (line != null) ...[line, const SizedBox(height: MyDataSpace.s2)],
        for (var i = buttons.length - 1; i >= 0; i--) ...[
          buttons[i],
          if (i > 0) const SizedBox(height: ButtonRow.gap),
        ],
      ]);
    }
    return Row(children: [
      Expanded(child: line ?? const SizedBox.shrink()),
      const SizedBox(width: MyDataSpace.s4),
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
      constraints: const BoxConstraints(minHeight: MyDataSize.rowHeight),
      child: Padding(
        padding: GroupedRow.padding,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) Text(title!, style: MyDataType.bodyStrong.copyWith(color: c.ink)),
            Text(text, style: (title == null ? MyDataType.body : MyDataType.caption).copyWith(
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
        padding: GroupedList.headingPadding,
        child: Semantics(
          header: true,
          child: Text(text, style: MyDataType.label.copyWith(color: context.colors.inkMuted)),
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
  });

  final String title;
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
          semanticLabel: title,
          child: ExcludeSemantics(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: MyDataSize.rowHeight),
              child: Padding(
                padding: GroupedRow.padding,
                child: Row(children: [
                  Expanded(child: Text(title, style: MyDataType.bodyStrong.copyWith(color: c.ink))),
                  AnimatedRotation(
                    turns: open ? 0.25 : 0,
                    duration: MyDataMotion.reduced(context) ? Duration.zero : MyDataMotion.fast,
                    curve: MyDataMotion.standard,
                    child: Icon(Icons.chevron_right_rounded, size: MyDataSize.icon, color: c.inkMuted),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
      if (open)
        Padding(
          padding: const EdgeInsets.fromLTRB(MyDataSpace.s4, 0, MyDataSpace.s4, MyDataSpace.s4),
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
    final style = MyDataType.body.copyWith(color: c.ink);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (before != null) ...[Text(before!, style: style), const SizedBox(height: MyDataSpace.s2)],
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: MyDataSpace.s1),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: MyDataSpace.s6, child: Text('${i + 1}.', style: style)),
            Expanded(child: Text(steps[i], style: style)),
          ]),
        ),
      if (after != null) ...[
        const SizedBox(height: MyDataSpace.s2),
        Text(after!, style: MyDataType.caption.copyWith(color: c.inkMuted)),
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
