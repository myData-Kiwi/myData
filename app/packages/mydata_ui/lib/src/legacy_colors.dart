import 'package:flutter/widgets.dart';

/// The palette from CLAUDE.md (the website's tokens). Light theme only.
abstract final class LegacyColors {
  static const bg = Color(0xFFFCFDF7);
  static const surface = Color(0xFFFFFFFF);
  static const band = Color(0xFFE3EFBF);
  static const fg = Color(0xFF2A2018);
  static const muted = Color(0xFF655646);
  static const line = Color(0xFFD6E0BD);
  static const kiwi = Color(0xFFA9CC4E);
  static const kiwiDeep = Color(0xFF4C7814);
  static const skin = Color(0xFF6B4F35);
  static const cream = Color(0xFFFBF7EC);

  /// Not in the website palette: errors need a colour that reads as "wrong" at a glance.
  static const danger = Color(0xFFA33A21);
  static const dangerBg = Color(0xFFFBEDE7);
}

abstract final class LegacyFonts {
  static const display = 'PlusJakartaSans';
  static const body = 'Figtree';
  static const mono = 'JetBrainsMono';
  static const package = 'mydata_ui';
}
