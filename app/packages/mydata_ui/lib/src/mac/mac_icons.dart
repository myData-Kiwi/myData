import 'package:flutter/widgets.dart';

import '../generated/tokens.g.dart';

/// The Mac shell's icons, one set for every app: Lucide (ISC), bundled cut down to these
/// (tool/subset_lucide.sh), in place of SF Symbols, which may only be used through Apple's own frameworks.
/// Their 2px stroke on a 24px grid draws at about 1.3px at the frame's 16px, close to SF Symbols' regular
/// weight at 13pt. Named by meaning, not by the Lucide name (in the comment), so an icon can be swapped here
/// alone. Add one: its code point from lucide-static's font/codepoints.json, here, in [all] and in the
/// script's list, then run the script.
abstract final class MacIcons {
  static const _family = MyDataMacFont.icons;
  static const _package = 'mydata_ui';

  // Sections and records.
  static const people = IconData(0xe46e, fontFamily: _family, fontPackage: _package); // users-round
  static const person = IconData(0xe468, fontFamily: _family, fontPackage: _package); // user-round
  static const personAdd = IconData(0xe1a2, fontFamily: _family, fontPackage: _package); // user-plus
  static const contact = IconData(0xe09c, fontFamily: _family, fontPackage: _package); // contact
  static const calendar = IconData(0xe063, fontFamily: _family, fontPackage: _package); // calendar
  static const calendarMonth = IconData(0xe2b9, fontFamily: _family, fontPackage: _package); // calendar-days
  static const calendarCheck = IconData(0xe2b7, fontFamily: _family, fontPackage: _package); // calendar-check
  static const clock = IconData(0xe087, fontFamily: _family, fontPackage: _package); // clock
  static const photo = IconData(0xe0f6, fontFamily: _family, fontPackage: _package); // image
  static const assistant = IconData(0xe412, fontFamily: _family, fontPackage: _package); // sparkles
  static const chat = IconData(0xe117, fontFamily: _family, fontPackage: _package); // message-square
  static const status = IconData(0xe038, fontFamily: _family, fontPackage: _package); // activity
  static const importFile = IconData(0xe0f7, fontFamily: _family, fontPackage: _package); // inbox
  static const settings = IconData(0xe154, fontFamily: _family, fontPackage: _package); // settings
  static const layers = IconData(0xe529, fontFamily: _family, fontPackage: _package); // layers
  static const review = IconData(0xe1d0, fontFamily: _family, fontPackage: _package); // list-checks
  static const list = IconData(0xe106, fontFamily: _family, fontPackage: _package); // list
  static const note = IconData(0xe172, fontFamily: _family, fontPackage: _package); // square-pen
  static const trash = IconData(0xe18e, fontFamily: _family, fontPackage: _package); // trash-2

  // Sources and the host.
  static const thisMac = IconData(0xe1cd, fontFamily: _family, fontPackage: _package); // laptop
  static const host = IconData(0xe153, fontFamily: _family, fontPackage: _package); // server
  static const cloud = IconData(0xe088, fontFamily: _family, fontPackage: _package); // cloud
  static const sync = IconData(0xe145, fontFamily: _family, fontPackage: _package); // refresh-cw
  static const agents = IconData(0xe125, fontFamily: _family, fontPackage: _package); // network
  static const key = IconData(0xe4a3, fontFamily: _family, fontPackage: _package); // key-round

  // Actions.
  static const add = IconData(0xe13d, fontFamily: _family, fontPackage: _package); // plus
  static const remove = IconData(0xe07e, fontFamily: _family, fontPackage: _package); // circle-minus
  static const edit = IconData(0xe1f9, fontFamily: _family, fontPackage: _package); // pencil
  static const copy = IconData(0xe09e, fontFamily: _family, fontPackage: _package); // copy
  static const search = IconData(0xe151, fontFamily: _family, fontPackage: _package); // search
  static const clear = IconData(0xe084, fontFamily: _family, fontPackage: _package); // circle-x
  static const close = IconData(0xe1b2, fontFamily: _family, fontPackage: _package); // x
  static const more = IconData(0xe0b6, fontFamily: _family, fontPackage: _package); // ellipsis
  static const send = IconData(0xe04a, fontFamily: _family, fontPackage: _package); // arrow-up
  static const check = IconData(0xe06c, fontFamily: _family, fontPackage: _package); // check
  static const fileCheck = IconData(0xe0c1, fontFamily: _family, fontPackage: _package); // file-check
  static const report = IconData(0xe0d1, fontFamily: _family, fontPackage: _package); // flag

  // Quick actions on a record.
  static const message = IconData(0xe116, fontFamily: _family, fontPackage: _package); // message-circle
  static const call = IconData(0xe133, fontFamily: _family, fontPackage: _package); // phone
  static const video = IconData(0xe1a5, fontFamily: _family, fontPackage: _package); // video
  static const mail = IconData(0xe10f, fontFamily: _family, fontPackage: _package); // mail
  static const map = IconData(0xe111, fontFamily: _family, fontPackage: _package); // map-pin

  // States.
  static const info = IconData(0xe0f9, fontFamily: _family, fontPackage: _package); // info
  static const warning = IconData(0xe193, fontFamily: _family, fontPackage: _package); // triangle-alert
  static const error = IconData(0xe077, fontFamily: _family, fontPackage: _package); // circle-alert
  static const success = IconData(0xe226, fontFamily: _family, fontPackage: _package); // circle-check

  // Navigation.
  static const sidebar = IconData(0xe12a, fontFamily: _family, fontPackage: _package); // panel-left
  static const back = IconData(0xe048, fontFamily: _family, fontPackage: _package); // arrow-left
  static const chevronLeft = IconData(0xe06e, fontFamily: _family, fontPackage: _package); // chevron-left
  static const chevronRight = IconData(0xe06f, fontFamily: _family, fontPackage: _package); // chevron-right
  static const chevronDown = IconData(0xe06d, fontFamily: _family, fontPackage: _package); // chevron-down
  static const upDown = IconData(0xe211, fontFamily: _family, fontPackage: _package); // chevrons-up-down

  /// Every icon, for the test that checks each is in the bundled font.
  static const all = [
    people, person, personAdd, contact, calendar, calendarMonth, calendarCheck, clock, photo, assistant,
    chat, status, importFile, settings, layers, review, list, note, trash, thisMac, host, cloud, sync,
    agents, key, add, remove, edit, copy, search, clear, close, more, send, check, fileCheck, report,
    message, call, video, mail, map, info, warning, error, success, sidebar, back, chevronLeft,
    chevronRight, chevronDown, upDown,
  ];
}
