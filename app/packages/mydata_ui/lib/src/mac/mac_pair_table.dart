import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import '../widgets/avatar.dart';
import '../widgets/button.dart';
import '../widgets/duplicate_pair.dart';
import 'mac_controls.dart';
import 'mac_metrics.dart';
import 'mac_theme.dart';

/// [DuplicatePair] in the Mac frame: the same versions, rows, differences, after column and actions, laid
/// out as a Mac table on the content's ground instead of a card (plan section 5: "Lists are lists"; inset
/// groups only in forms and Settings).
///
/// - **Header:** for each version a small [Avatar], the name in `body-emphasized` and its caption in
///   `caption` and `secondary-label`, over a `separator` hairline.
/// - **Rows** in the contact page's order: the kind right-aligned in the label column (`callout`,
///   `secondary-label`), as on a record's page; then a cell per version, each value with its label in
///   `caption` before it, "None" in `tertiary-label`. Hairlines between rows.
/// - **Differences** are marked by a word: "Differs" under the kind in `caption-emphasized` and
///   `secondary-label` (no band: a table of bands reads as a block of grey on the Mac's white ground), only in
///   the comparison rows and only when some shown rows do not differ: when every row differs (two different
///   people, or Compare showing only the differences) the mark says nothing. The after rows hold one value
///   each and are never marked.
/// - **After:** inline from [DuplicatePair.inlineAfterWidth], else a second table under the first with its
///   title in `body-emphasized`; in Changes, each differing row's after cell holds a [MacPopUpButton] of the
///   versions.
/// - Compare and Changes show only the rows that differ until "Show all fields"; Merge shows every row.
///   Then the note, the message (in `danger` when [messageIsError], read at once) and the actions at the end
///   edge (push buttons).
/// - Screen readers hear each row as DuplicatePair's do ("Phone, Differs. Ava Fictional: mobile 555-0142…").
class MacPairTable extends StatefulWidget {
  const MacPairTable({
    super.key,
    required this.versions,
    this.mode = PairMode.compare,
    this.after,
    this.differences,
    this.loading = false,
    this.afterLoading = false,
    this.note,
    this.message,
    this.messageIsError = false,
    this.actions = const [],
  });

  final List<PairVersion> versions;
  final PairMode mode;
  final PairAfter? after;
  final Set<PairField>? differences;
  final bool loading;
  final bool afterLoading;
  final String? note;
  final String? message;
  final bool messageIsError;
  final List<Widget> actions;

  /// Between columns.
  static double columnGap(MyDataLook look) => look.space(4);

  @override
  State<MacPairTable> createState() => _MacPairTableState();
}

class _MacPairTableState extends State<MacPairTable> {
  bool _showAll = false;

  bool get _onlyDifferences => widget.mode != PairMode.merge && !_showAll;

  Set<PairField> get _differs => widget.differences ?? DuplicatePair.differing(widget.versions);

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
    final mac = context.mac;
    final c = context.colors;
    return LayoutBuilder(builder: (context, constraints) {
      final inlineAfter = widget.after != null && constraints.maxWidth >= DuplicatePair.inlineAfterWidth;
      final rows = widget.loading ? PairField.values.take(4).toList() : _rows();
      final differs = _differs;
      final mark = !widget.loading && rows.any((f) => !differs.contains(f));
      final columns = [
        for (final v in widget.versions) _Col.version(v),
        if (inlineAfter) _Col.after(widget.after!),
      ];
      final children = <Widget>[
        _header(context, columns),
        Container(height: 1, color: mac.separator),
        if (rows.isEmpty && !widget.loading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: context.space(2)),
            child: Text(DuplicatePair.nothingDiffers, style: context.macLook.secondary(context.macLook.body).copyWith(color: mac.secondaryLabel)),
          ),
        for (final (i, f) in rows.indexed) ...[
          if (i > 0) _hairline(context),
          _row(context, f, columns, mark: mark),
        ],
      ];
      if (widget.after != null && !inlineAfter && !widget.loading) {
        final after = [_Col.after(widget.after!)];
        children.addAll([
          SizedBox(height: context.space(5)),
          Semantics(
            header: true,
            child: Text(widget.after!.title, style: context.macLook.bodyEmphasized.copyWith(color: mac.label)),
          ),
          Text(widget.after!.caption, style: context.macLook.caption.copyWith(color: mac.secondaryLabel)),
          SizedBox(height: context.space(2)),
          Container(height: 1, color: mac.separator),
          for (final (i, f) in rows.indexed) ...[
            if (i > 0) _hairline(context),
            _row(context, f, after, mark: false),
          ],
        ]);
      }
      if (widget.mode != PairMode.merge && !widget.loading) {
        children.addAll([
          SizedBox(height: context.space(2)),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Button(
              label: _showAll ? DuplicatePair.showDifferencesLabel : DuplicatePair.showAllLabel,
              variant: ButtonVariant.plain,
              onPressed: () => setState(() => _showAll = !_showAll),
            ),
          ),
        ]);
      }
      if (widget.note != null) {
        children.addAll([
          SizedBox(height: context.space(3)),
          Text(widget.note!, style: context.macLook.caption.copyWith(color: mac.secondaryLabel)),
        ]);
      }
      if (widget.message != null) {
        children.addAll([
          SizedBox(height: context.space(4)),
          Semantics(
            liveRegion: true,
            child: Text(widget.message!,
                style: context.macLook.body.copyWith(color: widget.messageIsError ? c.danger : mac.label)),
          ),
        ]);
      }
      if (widget.actions.isNotEmpty) {
        children.addAll([
          SizedBox(height: context.space(5)),
          ButtonRow(alignment: WrapAlignment.end, children: widget.actions),
        ]);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children);
    });
  }

  Widget _hairline(BuildContext context) => Padding(
        padding: EdgeInsetsDirectional.only(start: MyDataMacSize.labelColumn + MacPairTable.columnGap(context.look)),
        child: Container(height: 1, color: context.mac.separator),
      );

  Widget _header(BuildContext context, List<_Col> columns) {
    final mac = context.mac;
    return Padding(
      padding: EdgeInsets.only(bottom: context.space(2)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(width: MyDataMacSize.labelColumn),
        for (final col in columns) ...[
          SizedBox(width: MacPairTable.columnGap(context.look)),
          Expanded(
            child: Semantics(
              header: true,
              label: '${col.title}, ${col.caption}',
              excludeSemantics: true,
              child: Row(children: [
                if (col.version != null && Avatar.shown(context)) ...[
                  Avatar(
                    name: col.version!.personName ?? col.version!.name,
                    givenName: col.version!.givenName,
                    familyName: col.version!.familyName,
                    photo: col.version!.photo,
                  ),
                  SizedBox(width: context.space(2)),
                ],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(col.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: context.macLook.bodyEmphasized.copyWith(color: mac.label)),
                    if (col.caption.isNotEmpty)
                      Text(col.caption,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: context.macLook.caption.copyWith(color: mac.secondaryLabel)),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ]),
    );
  }

  /// One field's row; [mark]: "Differs" under its kind when it differs.
  Widget _row(BuildContext context, PairField f, List<_Col> columns, {required bool mark}) {
    final mac = context.mac;
    final differs = !widget.loading && _differs.contains(f);
    final spoken = [for (final col in columns) '${col.title}: ${col.spoken(f)}'];
    final hasSelect = differs && columns.any((col) => col.after?.onChoose != null);
    return Semantics(
      container: true,
      label: '${f.label}${differs && mark ? ', ${DuplicatePair.differsLabel}' : ''}. ${spoken.join('. ')}',
      excludeSemantics: !hasSelect,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: context.space(1) + MyDataMacSize.tight),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: MyDataMacSize.labelColumn,
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(f.label.toLowerCase(),
                  textAlign: TextAlign.end, style: context.macLook.secondary(context.macLook.callout).copyWith(color: mac.secondaryLabel)),
              if (differs && mark)
                Text(DuplicatePair.differsLabel,
                    textAlign: TextAlign.end,
                    style: context.macLook.captionEmphasized.copyWith(color: mac.secondaryLabel)),
            ]),
          ),
          for (final col in columns) ...[
            SizedBox(width: MacPairTable.columnGap(context.look)),
            Expanded(child: _cell(context, f, col, differs: differs)),
          ],
        ]),
      ),
    );
  }

  Widget _cell(BuildContext context, PairField f, _Col col, {required bool differs}) {
    final mac = context.mac;
    if (widget.loading || (col.after != null && widget.afterLoading)) return const _Bar();
    final after = col.after;
    if (after != null && after.onChoose != null && differs) {
      final chosen = after.choices[f] ?? 0;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        MacPopUpButton<int>(
          label: '${after.chooseLabel} ${f.label.toLowerCase()}',
          items: [
            for (var i = 0; i < widget.versions.length; i++) MacPopUpItem(value: i, title: widget.versions[i].name),
          ],
          value: chosen,
          onChanged: (i) => after.onChoose!(f, i),
        ),
        SizedBox(height: context.space(1)),
        ..._values(context, widget.versions[chosen].valuesOf(f)),
      ]);
    }
    final leftOut = after?.leftOut[f] ?? const <String>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      ..._values(context, col.valuesOf(f)),
      for (final l in leftOut)
        Text('${DuplicatePair.leftOutPrefix}$l', style: context.macLook.caption.copyWith(color: mac.secondaryLabel)),
    ]);
  }

  List<Widget> _values(BuildContext context, List<PairValue> values) {
    final mac = context.mac;
    if (values.isEmpty) {
      return [Text(DuplicatePair.noneLabel, style: context.macLook.body.copyWith(color: mac.tertiaryLabel))];
    }
    return [
      for (final v in values)
        Text.rich(TextSpan(children: [
          if (v.label.isNotEmpty)
            TextSpan(text: '${v.label} ', style: context.macLook.caption.copyWith(color: mac.secondaryLabel)),
          TextSpan(text: v.value, style: context.macLook.body.copyWith(color: mac.label)),
        ])),
    ];
  }
}

class _Col {
  _Col.version(PairVersion this.version)
      : after = null,
        title = version.name,
        caption = version.caption;
  _Col.after(PairAfter this.after)
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

/// A faint bar where a value will be.
class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) => Container(
        height: context.space(3),
        margin: const EdgeInsets.symmetric(vertical: MyDataMacSize.tight),
        decoration: BoxDecoration(color: context.mac.quaternaryLabel, borderRadius: MacControl.radius),
      );
}
