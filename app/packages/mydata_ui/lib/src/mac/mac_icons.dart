import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';

/// The Mac frame's icons: Lucide (ISC), bundled cut down to these (tool/subset_lucide.sh), in place of SF
/// Symbols, which may only be used through Apple's own frameworks. Their 2px stroke on a 24px grid draws at
/// about 1.3px at the frame's 16px, close to SF Symbols' regular weight at 13pt.
abstract final class MacIcons {
  static const _family = MyDataMacFont.icons;
  static const _package = 'mydata_ui';

  static const people = IconData(0xe46e, fontFamily: _family, fontPackage: _package); // users-round
  static const person = IconData(0xe468, fontFamily: _family, fontPackage: _package); // user-round
  static const trash = IconData(0xe18e, fontFamily: _family, fontPackage: _package); // trash-2
  static const review = IconData(0xe1d0, fontFamily: _family, fontPackage: _package); // list-checks
  static const add = IconData(0xe13d, fontFamily: _family, fontPackage: _package); // plus
  static const search = IconData(0xe151, fontFamily: _family, fontPackage: _package); // search
  static const clear = IconData(0xe084, fontFamily: _family, fontPackage: _package); // circle-x
  static const message = IconData(0xe116, fontFamily: _family, fontPackage: _package); // message-circle
  static const call = IconData(0xe133, fontFamily: _family, fontPackage: _package); // phone
  static const mail = IconData(0xe10f, fontFamily: _family, fontPackage: _package); // mail
  static const map = IconData(0xe111, fontFamily: _family, fontPackage: _package); // map-pin
  static const video = IconData(0xe1a5, fontFamily: _family, fontPackage: _package); // video
  static const edit = IconData(0xe1f9, fontFamily: _family, fontPackage: _package); // pencil
  static const info = IconData(0xe0f9, fontFamily: _family, fontPackage: _package); // info
  static const check = IconData(0xe06c, fontFamily: _family, fontPackage: _package); // check
  static const copy = IconData(0xe09e, fontFamily: _family, fontPackage: _package); // copy
  static const sidebar = IconData(0xe12a, fontFamily: _family, fontPackage: _package); // panel-left
  static const back = IconData(0xe048, fontFamily: _family, fontPackage: _package); // arrow-left

  /// Every icon, for the test that checks each is in the bundled font.
  static const all = [
    people, person, trash, review, add, search, clear, message, call, mail, map, video, edit, info, check, copy, //
    sidebar, back,
  ];
}
