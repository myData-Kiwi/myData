import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// A label the app writes, in the `label` or `caption` role: a control's or a field's name, a heading, a
/// tab, a status word, a weekday. Where the theme sets that role in upper case (`case: upper`), it is shown
/// in upper case with the role's tracking, unless it [holdsName] (a person, an app such as myAssistant, a
/// calendar, a file), which always keeps its own case (design/themes/ARCHITECTURE.md 2.3). Screen readers
/// hear the text as written.
///
/// Sentences (help, errors, descriptions) and the user's data are drawn as plain `Text` and never change
/// case. Every widget that draws a label of its own in these roles draws it through this (or through
/// `context.typeScale.cased` where it measures the text first), and a widget whose label may be a name
/// offers `holdsName` to its caller.
class RoleLabel extends StatelessWidget {
  const RoleLabel(
    this.text, {
    super.key,
    this.role = MyDataTypeRole.label,
    this.color,
    this.style,
    this.holdsName = false,
    this.maxLines,
    this.softWrap,
    this.overflow,
    this.textAlign,
  });

  final String text;

  /// `label` or `caption` (another role never changes case).
  final MyDataTypeRole role;

  /// The text's colour, over [style].
  final Color? color;

  /// The style; the look's style for [role] (`context.typeScale`) when null. A widget that draws the Mac
  /// type under System passes `context.type(role)`.
  final TextStyle? style;

  /// The text is a name and keeps its own case.
  final bool holdsName;

  final int? maxLines;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final shown = context.typeScale.cased(role, text, holdsName: holdsName);
    return Text(
      shown,
      semanticsLabel: shown == text ? null : text,
      maxLines: maxLines,
      softWrap: softWrap,
      overflow: overflow,
      textAlign: textAlign,
      style: (style ?? context.typeScale(role)).copyWith(color: color),
    );
  }
}
