import 'package:flutter/widgets.dart';

import '../mac/mac_theme.dart';
import '../theme/theme.dart';
import 'app_frame.dart' show AppLayout;
import 'avatar.dart';
import 'button.dart';
import 'pressable.dart' show MyDataRadii;
import 'segmented_control.dart';
import 'select.dart';
import 'role_label.dart';

/// The kinds of value a [DuplicatePair] compares, one row each, in the contact page's order
/// (design/components/DuplicatePair, "Field rows").
enum PairField {
  name('Name'),
  company('Company'),
  jobTitle('Job title'),
  phone('Phone'),
  email('Email'),
  address('Address'),
  birthday('Birthday'),
  links('Links'),
  notes('Notes'),
  photo('Photo');

  const PairField(this.label);

  /// The row's label, in sentence case.
  final String label;

  /// [value] as it is compared: emails in lower case, phones as their digits (with a leading +), and the
  /// spacing of every value made single, so "Differs" is not set by case or spacing alone. The app's own
  /// approximation of the host's normalising: a phone written with and without its country code still
  /// differs.
  String normalise(String value) {
    final spaced = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return switch (this) {
      email => spaced.toLowerCase(),
      phone => '${spaced.startsWith('+') ? '+' : ''}${spaced.replaceAll(RegExp(r'[^0-9]'), '')}',
      _ => spaced,
    };
  }
}

/// One value in a [DuplicatePair] cell: its [label] ("mobile", "work") in `caption` before it, as FieldRow
/// writes them, then the [value].
@immutable
class PairValue {
  const PairValue(this.value, {this.label = ''});
  final String value;
  final String label;

  String get spoken => label.isEmpty ? value : '$label $value';
}

/// One version of a contact: a column of a [DuplicatePair].
@immutable
class PairVersion {
  const PairVersion({
    required this.name,
    required this.caption,
    required this.fields,
    this.givenName = '',
    this.familyName = '',
    this.photo,
    this.personName,
  });

  /// The column header: the contact's name, or where this version is ("In the file", "In myData").
  final String name;

  /// The person's name for the avatar's initials when [name] says where the version is; null uses [name].
  final String? personName;

  /// How it came and when: "Added 2 Oct 2026", "Imported 14 Oct 2026", "Changed in iCloud 20 Oct 2026".
  final String caption;

  final String givenName;
  final String familyName;
  final ImageProvider? photo;

  /// Its values by kind; a kind left out, or empty, shows "None".
  final Map<PairField, List<PairValue>> fields;

  List<PairValue> valuesOf(PairField f) => fields[f] ?? const [];
}

/// The last column: what merging gives ("After merging", from the host's merge preview), or what saving
/// the changes writes ("After").
@immutable
class PairAfter {
  const PairAfter({
    required this.title,
    required this.caption,
    required this.fields,
    this.leftOut = const {},
    this.choices = const {},
    this.onChoose,
    this.chooseLabel = defaultChooseLabel,
  });

  /// "After merging" (Merge) or "After" (Changes).
  final String title;

  /// "A new contact. These two go to Recently deleted."
  final String caption;

  /// The values it holds, by kind (the host's word for a merge; never worked out by the app).
  final Map<PairField, List<PairValue>> fields;

  /// Values it leaves out, by kind, each written under the kept one as "Left out: 18 March 1990".
  final Map<PairField, List<String>> leftOut;

  /// Changes: for each differing kind, which version's values it takes (an index into the versions).
  final Map<PairField, int> choices;

  /// Changes: a Select in each differing row picks the version; null shows no Select.
  final void Function(PairField field, int version)? onChoose;

  /// The Select's accessible name, before the row's label in lower case: "Keep phone".
  final String chooseLabel;

  static const defaultChooseLabel = 'Keep';
  static const mergingTitle = 'After merging';
  static const changesTitle = 'After';

  List<PairValue> valuesOf(PairField f) => fields[f] ?? const [];
}

/// The three uses of a [DuplicatePair] (design/components/DuplicatePair, "Uses").
enum PairMode {
  /// Read-only: an import's "In the file" beside "In myData". Shows only the rows that differ until the
  /// user asks for all.
  compare,

  /// Two to twenty contacts and "After merging". Shows every row: the result is a whole contact.
  merge,

  /// "In myData", "In iCloud now" and "After", with a Select in each differing row. Shows only the rows that
  /// differ until the user asks for all.
  changes,
}

/// Two versions of a contact side by side, with the fields that differ marked, so the user can tell
/// whether they are the same person and what merging them gives (design/components/DuplicatePair).
///
/// - **One card** (`surface`, `radius-lg`, `shadow-1`), never a card per contact. Inside, a grid with a
///   label column ([labelWidth], `label` style, `ink-muted`) and one column per version, `space-4` apart,
///   `space-5` padding across.
/// - **Header row:** for each version a 36px [Avatar], the name in `body-strong` and its caption in
///   `caption` and `ink-muted`; a 1px `line` under it.
/// - **Field rows** in the contact page's order ([PairField]), each value on its own line with its label in
///   `caption` before it. A side with no value shows "None" in `ink-muted`.
/// - **Differences are marked by a word and a band:** a row whose values differ (after normalising: case of
///   emails, phones' digits, spacing; one side only also counts) has a `surface-sunken` band across the
///   whole row, `radius-sm`, and its label gains a second line, "Differs", in `caption` and `ink`. The band
///   is never the only sign. [differences] overrides the app's comparison (the host's, for Changes).
/// - **Compare and Changes** show only the rows that differ, with a plain "Show all fields" ("Show
///   differences only") under the grid; **Merge** shows every row.
/// - **The [after] column** (from [inlineAfterWidth] of content width; under it, a separate group with the
///   same rows titled with [PairAfter.title]), in `ink`: a value it leaves out is written under the kept one
///   in `caption` and `ink-muted`, "Left out: 18 March 1990", so nothing goes without being seen. In
///   Changes, each differing row's cell holds a Select of the versions.
/// - [note] under the grid ("What is left out stays with the originals in Recently deleted for 30 days."),
///   then [message] above the actions (in `danger` when [messageIsError]: a failure, read at once), then
///   [actions] at the end edge, `space-2` apart: the plain one, then the filled one.
/// - **Loading:** the card at its final shape with the header's names and grey bars where values will be;
///   no spinner.
/// - **Under 600px** the versions are stacked: a [SegmentedControl] at the top switches between them (and
///   the after column), and differing rows keep their band and "Differs" in every segment.
/// - Screen readers: each row reads its label, "Differs", then each value with its column ("Phone, Differs.
///   Ava Fictional: mobile 555-0142. Ava M. Fictional: mobile 555-0142, work 555-0177").
class DuplicatePair extends StatefulWidget {
  const DuplicatePair({
    super.key,
    required this.versions,
    this.mode = PairMode.compare,
    this.after,
    this.differences,
    this.loading = false,
    this.note,
    this.message,
    this.messageIsError = false,
    this.actions = const [],
    this.afterLoading = false,
    this.framed = true,
  });

  /// False inside a group that is already a card (the import's Compare, under a list row): the grid without
  /// its own card, so there is never a card on a card.
  final bool framed;

  final List<PairVersion> versions;
  final PairMode mode;
  final PairAfter? after;

  /// The kinds that differ, when the host says (H7); null compares the versions here.
  final Set<PairField>? differences;

  /// The pair is being read: names and grey bars.
  final bool loading;

  /// The after column is being read again (the merge preview after the Select changed): its cells are bars.
  final bool afterLoading;

  final String? note;
  final String? message;
  final bool messageIsError;

  /// The plain button, then the filled one.
  final List<Widget> actions;

  /// Spec: "a label column (`label` style, `ink-muted`, 84px)".
  static const labelWidth = 84.0;

  /// Spec: "'After merging' column (from 900px of content width)".
  static const inlineAfterWidth = 900.0;

  static const differsLabel = 'Differs';
  static const noneLabel = 'None';
  static const showAllLabel = 'Show all fields';
  static const showDifferencesLabel = 'Show differences only';
  static const leftOutPrefix = 'Left out: ';
  static const nothingDiffers = 'Nothing differs.';

  /// The kinds whose values differ among [versions], after normalising ([PairField.normalise]); a value
  /// on one side only counts.
  static Set<PairField> differing(List<PairVersion> versions) => {
        for (final f in PairField.values)
          if (versions.map((v) => _key(f, v.valuesOf(f))).toSet().length > 1) f,
      };

  static String _key(PairField f, List<PairValue> values) {
    final normal = [for (final v in values) f.normalise(v.value)]..removeWhere((s) => s.isEmpty);
    normal.sort();
    return normal.join('\u0001');
  }

  @override
  State<DuplicatePair> createState() => _DuplicatePairState();
}

class _DuplicatePairState extends State<DuplicatePair> {
  bool _showAll = false;
  int _segment = 0;

  bool get _onlyDifferences => widget.mode != PairMode.merge && !_showAll;

  Set<PairField> get _differs => widget.differences ?? DuplicatePair.differing(widget.versions);

  /// The rows shown: every kind any version (or the after column) has, in order; only those that differ
  /// in Compare and Changes until the user asks for all.
  List<PairField> _rows() {
    final differs = _differs;
    return [
      for (final f in PairField.values)
        if (widget.versions.any((v) => v.valuesOf(f).isNotEmpty) ||
            (widget.after?.valuesOf(f).isNotEmpty ?? false) ||
            differs.contains(f))
          if (!_onlyDifferences || differs.contains(f)) f,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final phone = AppLayout.isPhone(context);
    return LayoutBuilder(builder: (context, constraints) {
      final inner = constraints.maxWidth - (widget.framed ? 2 * context.space(5) : 0);
      final inlineAfter = widget.after != null && constraints.maxWidth >= DuplicatePair.inlineAfterWidth;
      final rows = _rows();
      final children = <Widget>[];
      if (phone && widget.versions.length + (widget.after == null ? 0 : 1) <= SegmentedControl.maxSegments) {
        children.addAll(_phoneBody(context, rows));
      } else {
        final columns = [
          for (final v in widget.versions) _Column.version(v),
          if (inlineAfter) _Column.after(widget.after!),
        ];
        children.add(_header(context, columns, inner));
        children.add(Container(height: 1, color: c.line));
        children.add(SizedBox(height: context.space(2)));
        if (rows.isEmpty && !widget.loading) {
          children.add(_plain(context, DuplicatePair.nothingDiffers));
        }
        for (final f in widget.loading ? PairField.values.take(4).toList() : rows) {
          children.add(_row(context, f, columns));
        }
        if (widget.after != null && !inlineAfter && !widget.loading) {
          children.add(SizedBox(height: context.space(4)));
          children.add(Semantics(
            header: true,
            child: RoleLabel(widget.after!.title, style: context.type(MyDataTypeRole.label), color: c.inkMuted),
          ));
          children.add(Text(widget.after!.caption, style: context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted)));
          children.add(SizedBox(height: context.space(2)));
          final afterOnly = [_Column.after(widget.after!)];
          for (final f in rows) {
            children.add(_row(context, f, afterOnly));
          }
        }
      }
      if (widget.mode != PairMode.merge && !widget.loading) {
        children.add(SizedBox(height: context.space(2)));
        children.add(Align(
          alignment: AlignmentDirectional.centerStart,
          child: Button(
            label: _showAll ? DuplicatePair.showDifferencesLabel : DuplicatePair.showAllLabel,
            variant: ButtonVariant.plain,
            onPressed: () => setState(() => _showAll = !_showAll),
          ),
        ));
      }
      if (widget.note != null) {
        children.add(SizedBox(height: context.space(3)));
        children.add(Text(widget.note!, style: context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted)));
      }
      if (widget.message != null) {
        children.add(SizedBox(height: context.space(4)));
        children.add(Semantics(
          liveRegion: true,
          child: Text(widget.message!,
              style: context.type(MyDataTypeRole.body).copyWith(color: widget.messageIsError ? c.danger : c.ink)),
        ));
      }
      if (widget.actions.isNotEmpty) {
        children.add(SizedBox(height: context.space(4)));
        children.add(phone
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var i = widget.actions.length - 1; i >= 0; i--) ...[
                  widget.actions[i],
                  if (i > 0) SizedBox(height: ButtonRow.gap(context.look)),
                ],
              ])
            : ButtonRow(alignment: WrapAlignment.end, children: widget.actions));
      }
      final column =
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children);
      if (!widget.framed) return column;
      return Container(
        padding: EdgeInsets.all(context.space(5)),
        decoration: context.radius.decorate(BoxDecoration(color: c.surface, borderRadius: MyDataRadii.lg(context.look), boxShadow: context.shadows.shadow1)),
        child: column,
      );
    });
  }

  Widget _plain(BuildContext context, String text) => Padding(
        padding: EdgeInsets.symmetric(vertical: context.space(2)),
        child: Text(text, style: context.type(MyDataTypeRole.body).copyWith(color: context.colors.inkMuted)),
      );

  Widget _header(BuildContext context, List<_Column> columns, double inner) {
    final c = context.colors;
    return Padding(
      padding: EdgeInsets.only(bottom: context.space(3)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(width: DuplicatePair.labelWidth),
        for (final col in columns) ...[
          SizedBox(width: context.space(4)),
          Expanded(
            child: Semantics(
              header: true,
              label: '${col.title}, ${col.caption}',
              excludeSemantics: true,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (col.version != null && Avatar.shown(context)) ...[
                  Avatar(
                    name: col.version!.personName ?? col.version!.name,
                    givenName: col.version!.givenName,
                    familyName: col.version!.familyName,
                    photo: col.version!.photo,
                  ),
                  SizedBox(width: context.space(3)),
                ],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(col.title, style: context.type(MyDataTypeRole.bodyStrong).copyWith(color: c.ink)),
                    Text(col.caption, style: context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted)),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  /// One field row: the label (with "Differs"), then a cell per column, on the band when it differs.
  Widget _row(BuildContext context, PairField f, List<_Column> columns) {
    final c = context.colors;
    final differs = !widget.loading && _differs.contains(f);
    final cells = <Widget>[];
    final spoken = <String>[];
    for (final col in columns) {
      cells.add(SizedBox(width: context.space(4)));
      cells.add(Expanded(child: _cell(context, f, col, differs: differs)));
      spoken.add('${col.title}: ${col.spoken(f)}');
    }
    final label = '${f.label}${differs ? ', ${DuplicatePair.differsLabel}' : ''}. ${spoken.join('. ')}';
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: !_hasSelect(columns, differs),
      child: Container(
        margin: EdgeInsets.only(bottom: context.space(1)),
        padding: EdgeInsets.symmetric(horizontal: context.space(2), vertical: context.space(2)),
        decoration: context.radius.decorate(BoxDecoration(
          color: differs ? c.surfaceSunken : c.surfaceSunken.withValues(alpha: 0),
          borderRadius: MyDataRadii.sm(context.look),
        )),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: DuplicatePair.labelWidth - context.space(2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RoleLabel(f.label, style: context.type(MyDataTypeRole.label), color: c.inkMuted),
              if (differs) Text(DuplicatePair.differsLabel, style: context.type(MyDataTypeRole.caption).copyWith(color: c.ink)),
            ]),
          ),
          ...cells,
        ]),
      ),
    );
  }

  /// A differing row with a Select in its after cell keeps its children for screen readers: the Select is
  /// a control of its own.
  bool _hasSelect(List<_Column> columns, bool differs) => differs && columns.any((col) => col.after?.onChoose != null);

  Widget _cell(BuildContext context, PairField f, _Column col, {required bool differs}) {
    final c = context.colors;
    if (widget.loading || (col.after != null && widget.afterLoading)) return const _Bar();
    final after = col.after;
    if (after != null && after.onChoose != null && differs) {
      final chosen = after.choices[f] ?? 0;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MyDataSelect<int>(
          label: '${after.chooseLabel} ${f.label.toLowerCase()}',
          showLabel: false,
          items: [
            for (var i = 0; i < widget.versions.length; i++)
              SelectItem(value: i, title: widget.versions[i].name),
          ],
          value: chosen,
          onChanged: (i) => after.onChoose!(f, i),
        ),
        SizedBox(height: context.space(1)),
        ..._values(context, widget.versions[chosen].valuesOf(f)),
      ]);
    }
    final values = col.valuesOf(f);
    final leftOut = after?.leftOut[f] ?? <String>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ..._values(context, values),
      for (final l in leftOut)
        Text('${DuplicatePair.leftOutPrefix}$l', style: context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted)),
    ]);
  }

  List<Widget> _values(BuildContext context, List<PairValue> values) {
    final c = context.colors;
    if (values.isEmpty) return [Text(DuplicatePair.noneLabel, style: context.type(MyDataTypeRole.body).copyWith(color: c.inkMuted))];
    return [
      for (final v in values)
        Text.rich(TextSpan(children: [
          if (v.label.isNotEmpty)
            TextSpan(text: '${v.label} ', style: context.type(MyDataTypeRole.caption).copyWith(color: c.inkMuted)),
          TextSpan(text: v.value, style: context.type(MyDataTypeRole.body).copyWith(color: c.ink)),
        ])),
    ];
  }

  /// Under 600px: a segmented control picks one column; the rows show that column alone.
  List<Widget> _phoneBody(BuildContext context, List<PairField> rows) {
    final columns = [
      for (final v in widget.versions) _Column.version(v),
      if (widget.after != null) _Column.after(widget.after!),
    ];
    final at = _segment.clamp(0, columns.length - 1);
    final col = columns[at];
    return [
      if (columns.length >= SegmentedControl.minSegments)
        SegmentedControl<int>(
          segments: [for (var i = 0; i < columns.length; i++) (i, columns[i].title)],
          selected: at,
          onChanged: (i) => setState(() => _segment = i),
          semanticLabel: 'Version',
        ),
      SizedBox(height: context.space(3)),
      Text(col.caption, style: context.type(MyDataTypeRole.caption).copyWith(color: context.colors.inkMuted)),
      SizedBox(height: context.space(2)),
      for (final f in widget.loading ? PairField.values.take(4).toList() : rows) _row(context, f, [col]),
    ];
  }
}

/// A column of the grid: a version, or the after column.
class _Column {
  _Column.version(PairVersion this.version)
      : after = null,
        title = version.name,
        caption = version.caption;
  _Column.after(PairAfter this.after)
      : version = null,
        title = after.title,
        caption = after.caption;

  final PairVersion? version;
  final PairAfter? after;
  final String title;
  final String caption;

  List<PairValue> valuesOf(PairField f) => version?.valuesOf(f) ?? after!.valuesOf(f);

  String spoken(PairField f) {
    final values = valuesOf(f);
    final said = values.isEmpty ? DuplicatePair.noneLabel : values.map((v) => v.spoken).join(', ');
    final left = after?.leftOut[f] ?? const [];
    return left.isEmpty ? said : '$said. ${left.map((l) => '${DuplicatePair.leftOutPrefix}$l').join('. ')}';
  }
}

/// A grey bar where a value will be.
class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) => Container(
        height: context.space(4),
        margin: EdgeInsets.symmetric(vertical: context.space(1)),
        decoration: context.radius.decorate(BoxDecoration(color: context.colors.surfaceSunken, borderRadius: MyDataRadii.xs(context.look))),
      );
}
