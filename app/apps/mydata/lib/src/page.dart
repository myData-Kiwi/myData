import 'package:flutter/material.dart';

/// A screen's scrolling column of sections under its title, at a readable width.
class PageList extends StatelessWidget {
  const PageList({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          for (final child in children) ...[const SizedBox(height: 16), child],
        ],
      ),
    ),
  );
}
