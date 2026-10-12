import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'colors.dart';
import 'theme.dart';

/// The kiwi logo.
class KiwiLogo extends StatelessWidget {
  const KiwiLogo({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset('assets/logo/kiwi.svg',
      package: MyDataFonts.package, width: size * 210 / 180, height: size, semanticsLabel: 'myData');
}

/// The header of every app window: kiwi logo, app name, optional actions.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key, required this.title, this.actions = const []});
  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => Container(
        height: preferredSize.height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(
            color: MyDataColors.bg, border: Border(bottom: BorderSide(color: MyDataColors.line))),
        child: Row(children: [
          const KiwiLogo(size: 34),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const Spacer(),
          ...actions,
        ]),
      );
}

enum PanelKind { working, info, error }

/// A full message instead of a blank screen: what is happening (or what went wrong), and what to do.
/// Every error state in the apps is one of these, with a Retry.
class MessagePanel extends StatelessWidget {
  const MessagePanel({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.detail,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.progress,
  });

  final PanelKind kind;
  final String title;
  final String message;

  /// Technical detail (an error text, a path), shown in monospace.
  final String? detail;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  /// 0..1 for a determinate bar while working; null for an indeterminate one.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final icon = switch (kind) {
      PanelKind.error => const Icon(Icons.error_outline, color: MyDataColors.danger, size: 36),
      PanelKind.info => const Icon(Icons.info_outline, color: MyDataColors.kiwiDeep, size: 36),
      PanelKind.working => const KiwiLogo(size: 48),
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            icon,
            const SizedBox(height: 16),
            Text(title, style: t.headlineSmall),
            const SizedBox(height: 8),
            Text(message, style: t.bodyLarge),
            if (kind == PanelKind.working) ...[
              const SizedBox(height: 18),
              LinearProgressIndicator(value: progress, minHeight: 6, borderRadius: BorderRadius.circular(3)),
            ],
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: kind == PanelKind.error ? MyDataColors.dangerBg : MyDataColors.cream,
                    borderRadius: BorderRadius.circular(8)),
                child: SelectableText(detail!,
                    style: monoStyle(size: 12, color: kind == PanelKind.error ? MyDataColors.danger : MyDataColors.fg)),
              ),
            ],
            if (onPrimary != null || onSecondary != null) ...[
              const SizedBox(height: 20),
              Wrap(spacing: 10, runSpacing: 10, children: [
                if (onPrimary != null) FilledButton(onPressed: onPrimary, child: Text(primaryLabel ?? 'Retry')),
                if (onSecondary != null) OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel ?? '')),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

/// A titled card section.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              ?trailing,
            ]),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );
}

/// A label and a value on one line; the value can be monospace.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value, this.mono = false});
  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 160, child: Text(label, style: t.bodyMedium?.copyWith(color: MyDataColors.muted))),
        Expanded(child: SelectableText(value, style: mono ? monoStyle() : t.bodyMedium)),
      ]),
    );
  }
}

/// A small coloured badge ("ready", "demo date", "revoked").
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, this.tone = PillTone.neutral});
  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.good => (MyDataColors.band, MyDataColors.kiwiDeep),
      PillTone.warn => (MyDataColors.cream, MyDataColors.skin),
      PillTone.bad => (MyDataColors.dangerBg, MyDataColors.danger),
      PillTone.neutral => (MyDataColors.cream, MyDataColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
    );
  }
}

enum PillTone { good, warn, bad, neutral }

/// Byte counts for people: "9.3 GB".
String formatBytes(int? bytes) {
  if (bytes == null) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1000 && i < units.length - 1) {
    v /= 1000;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}
