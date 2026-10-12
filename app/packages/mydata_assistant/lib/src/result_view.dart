import 'package:flutter/material.dart';
import 'package:mydata_ui/mydata_ui.dart';

/// A tool's result as the host sent it: shown the moment the tool returns, before (or instead of) any
/// sentence from the model. The header is written by the host's code.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.kind, required this.header, required this.items});

  /// events, mail, contacts, photos or event_created.
  final String kind;
  final String header;
  final List<Map<String, Object?>> items;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon, size: 18, color: MyDataColors.kiwiDeep),
                const SizedBox(width: 8),
                Expanded(child: Text(header, style: t.titleSmall)),
              ],
            ),
            if (items.isNotEmpty && kind != 'event_created') ...[
              const SizedBox(height: 10),
              if (kind == 'photos')
                Wrap(spacing: 8, runSpacing: 8, children: [for (final p in items) _PhotoTile(p)])
              else
                for (final (i, item) in items.indexed) ...[if (i > 0) const Divider(height: 14), _row(context, item)],
            ],
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (kind) {
    'events' => Icons.event_outlined,
    'event_created' => Icons.event_available_outlined,
    'mail' => Icons.mail_outline,
    'contacts' => Icons.person_outline,
    'photos' => Icons.photo_library_outlined,
    _ => Icons.list_alt,
  };

  Widget _row(BuildContext context, Map<String, Object?> item) {
    final t = Theme.of(context).textTheme;
    String s(String k) => item[k] is String ? item[k] as String : '';
    final muted = t.bodySmall;
    return switch (kind) {
      'events' => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              [
                s('day'),
                [s('start'), s('end')].where((x) => x.isNotEmpty).join('–'),
              ].join('\n'),
              style: muted,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s('title'), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                if (s('location').isNotEmpty) Text(s('location'), style: muted),
              ],
            ),
          ),
        ],
      ),
      'mail' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s('from'), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
              Text(s('day'), style: muted),
            ],
          ),
          Text(s('subject'), style: t.bodyMedium),
          if (s('snippet').isNotEmpty) Text(s('snippet'), style: muted, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      'contacts' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s('name'), style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (s('email').isNotEmpty) SelectableText(s('email'), style: monoStyle(size: 12)),
          if (s('phone').isNotEmpty) SelectableText(s('phone'), style: monoStyle(size: 12)),
        ],
      ),
      _ => Text(item.toString(), style: muted),
    };
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile(this.photo);
  final Map<String, Object?> photo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final people = (photo['people'] is List ? photo['people'] as List : const []).join(', ');
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: MyDataColors.cream, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.photo_outlined, size: 28, color: MyDataColors.muted),
          const SizedBox(height: 6),
          Text('${photo['place'] ?? ''}', style: t.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('${photo['day'] ?? ''}', style: t.bodySmall),
          if (people.isNotEmpty) Text(people, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
