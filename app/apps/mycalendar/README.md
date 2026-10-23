# myCalendar

The calendar app: a month, the selected day's events, and which calendars this device shows. Read-only. It can start the host but never stops it. See `../../README.md`.

On macOS it draws the Mac frame (`MacShell`, see `mydata_ui`'s README), laid out as Calendar.app's month view: the calendar list with colour checkboxes in the translucent sidebar (`mac_calendar_list.dart`), the view switch and "‹ Today ›" in the toolbar, the month filling the window (`mac_month_grid.dart`) and the selected day beside it (`mac_day_list.dart`). Elsewhere it keeps the branded frame with the Month and Calendars sections. Both layouts show what `MonthContent` works out. Mac screenshots: `test/mac_frame_test.dart`.
