import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../generated/tokens.g.dart';
import '../theme/theme.dart';
import 'mac_theme.dart';

/// What the Mac widgets draw with here (`context.macLook`, design/themes/ARCHITECTURE.md 3.4): in the System
/// look the Mac's own type, sizes and corners (the `macos` tokens, unchanged); in a drawn theme inside the
/// Mac window the theme's:
///
/// - **type:** each Mac role is the theme role it stands for: `body`, `body-emphasized` as `body-strong`,
///   `callout` and `caption-emphasized` as `label`, `caption` and the quick actions' `action` as `caption`,
///   the toolbar's `title` and a section's header as `heading`, a pane's title and a record's name as
///   `title` (the display face where the theme sets titles in it: Journal's Fraunces); secondary text is
///   italic where the theme says so ([secondary]);
/// - **density:** a list's rows are the theme's rows, a sidebar's rows and the toolbar's items its controls
///   (never taller than the toolbar band leaves room for), icons its icon size;
/// - **shape:** a selected row's corners are the theme's small radius, toolbar items and the search field
///   its controls' (a capsule where controls are pills, else the small radius; square in Journal), all in
///   its corner style ([decorate]); a toolbar item's outline is the theme's control outline where it draws
///   one.
///
/// The window's skeleton stays the Mac's in every theme: column widths, the toolbar band's height, the
/// sidebar's margins and insets (decision 9, layout stays out of themes).
@immutable
class MacLookMetrics {
  const MacLookMetrics._({
    required this.system,
    required this.body,
    required this.bodyEmphasized,
    required this.callout,
    required this.caption,
    required this.captionEmphasized,
    required this.action,
    required this.title,
    required this.paneTitle,
    required this.sectionHeader,
    required this.name,
    required this.rowHeight,
    required this.sectionHeight,
    required this.sidebarRowHeight,
    required this.controlHeight,
    required this.pushButtonHeight,
    required this.toolbarItemHeight,
    required this.icon,
    required this.selectionRadius,
    required this.sidebarSelectionRadius,
    required this.controlRadius,
    required this.groupRadius,
    this.shape,
    required this.secondaryItalic,
    this.itemSide,
  });

  /// The System look: the Mac's own tokens.
  final bool system;

  final TextStyle body, bodyEmphasized, callout, caption, captionEmphasized, action, title, paneTitle,
      sectionHeader, name;

  /// A list row (`row-height`).
  final double rowHeight;

  /// A list's letter heading (`section-height`).
  final double sectionHeight;

  /// A source list's row (`sidebar-row-height`).
  final double sidebarRowHeight;

  /// A form row's control (`control-height`).
  final double controlHeight;

  /// A push button and a form's segmented control (`push-button-height`).
  final double pushButtonHeight;

  /// A toolbar item and the search field (`toolbar-item-height`).
  final double toolbarItemHeight;

  /// An icon's box (`icon`).
  final double icon;

  /// A selected list row (`selection`).
  final BorderRadius selectionRadius;

  /// A selected source list row (`sidebar-selection`).
  final BorderRadius sidebarSelectionRadius;

  /// Toolbar items, the search field and the switch's track (`field`, a capsule on the Mac).
  final BorderRadius controlRadius;

  /// A form's group and a sidebar panel's corners.
  final BorderRadius groupRadius;

  /// The corner style the radii are drawn in; null in System, whose corners are round boxes.
  final MyDataShape? shape;

  final bool secondaryItalic;

  /// A toolbar item's outline at rest in a drawn theme that outlines its controls; null: the Mac's
  /// `separator` hairline.
  final BorderSide? itemSide;

  /// [style] as secondary text (a job title, a field's label, a row's line): italic where the theme sets
  /// secondary text in italic (Journal, Paperback), never in System.
  TextStyle secondary(TextStyle style) => secondaryItalic ? style.copyWith(fontStyle: FontStyle.italic) : style;

  /// [d] in this look's corner style (a box in System and wherever a box draws it).
  Decoration decorate(BoxDecoration d) => shape?.decorate(d) ?? d;

  /// The System look's metrics: the `macos` tokens.
  static const _system = MacLookMetrics._(
    system: true,
    body: MyDataMacType.body,
    bodyEmphasized: MyDataMacType.bodyEmphasized,
    callout: MyDataMacType.callout,
    caption: MyDataMacType.caption,
    captionEmphasized: MyDataMacType.captionEmphasized,
    action: MyDataMacType.action,
    title: MyDataMacType.title,
    paneTitle: MyDataMacType.paneTitle,
    sectionHeader: MyDataMacType.sectionHeader,
    name: MyDataMacType.name,
    rowHeight: MyDataMacSize.rowHeight,
    sectionHeight: MyDataMacSize.sectionHeight,
    sidebarRowHeight: MyDataMacSize.sidebarRowHeight,
    controlHeight: MyDataMacSize.controlHeight,
    pushButtonHeight: MyDataMacSize.pushButtonHeight,
    toolbarItemHeight: MyDataMacSize.toolbarItemHeight,
    icon: MyDataMacSize.icon,
    selectionRadius: BorderRadius.all(Radius.circular(MyDataMacRadius.selection)),
    sidebarSelectionRadius: BorderRadius.all(Radius.circular(MyDataMacRadius.sidebarSelection)),
    controlRadius: BorderRadius.all(Radius.circular(MyDataMacRadius.field)),
    groupRadius: BorderRadius.all(Radius.circular(MyDataMacRadius.sidebar)),
    shape: null,
    secondaryItalic: false,
  );

  static final _drawn = Expando<MacLookMetrics>('mac metrics');

  /// The tallest a toolbar item may be: the band less its insets above and below.
  static const toolbarItemMax = MyDataMacSize.toolbarHeight - 2 * MyDataMacSize.toolbarInset;

  /// The metrics for [look]: System's tokens, or the drawn theme's (kept per look).
  static MacLookMetrics forLook(MyDataLook look, {required bool system}) {
    if (system) return _system;
    return _drawn[look] ??= () {
      final s = look.typeScale;
      final d = look.density;
      final shape = look.shape;
      final small = BorderRadius.all(Radius.circular(shape.sm));
      return MacLookMetrics._(
        system: false,
        body: s.body,
        bodyEmphasized: s.bodyStrong,
        callout: s.label,
        caption: s.caption,
        captionEmphasized: s.label,
        action: s.caption,
        title: s.heading,
        paneTitle: s.title,
        sectionHeader: s.heading,
        name: s.title,
        rowHeight: d.rowHeight,
        sectionHeight: math.max(MyDataMacSize.sectionHeight, look.space(6)),
        sidebarRowHeight: d.controlHeight,
        controlHeight: d.controlHeight,
        pushButtonHeight: d.controlHeightCompact,
        toolbarItemHeight: math.min(d.controlHeight, toolbarItemMax),
        icon: d.icon,
        selectionRadius: small,
        sidebarSelectionRadius: small,
        controlRadius: BorderRadius.all(Radius.circular(shape.control)),
        groupRadius: BorderRadius.all(Radius.circular(shape.md)),
        shape: shape,
        secondaryItalic: s.secondaryItalic,
        itemSide: look.edges.controls ? look.edges.controlSide : null,
      );
    }();
  }
}

/// `context.macLook`: the Mac widgets' type, sizes and corners here ([MacLookMetrics]).
extension MacLookContext on BuildContext {
  MacLookMetrics get macLook => MacLookMetrics.forLook(look, system: isSystemLook);
}
