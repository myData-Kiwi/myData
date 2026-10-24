A field for a time of day in a form. The time can be typed in the ways people write times, stepped with the arrow keys, or picked from a list. This spec also covers the "When" group of the event editor, which puts All-day, the dates, the times, the time zone and Repeat together.

- **Use it** for the start and end times of a timed event.
- **Do not use it** for a length of time ("1 hour") or an alert ("10 minutes before"), which are Selects with presets; for a date (DatePicker beside it); or for a moment that is not a time of day.
- **A wall time.** The field holds a time as the clock on the wall shows it in the event's time zone, with no zone of its own. The app sends the dates, the wall times and the event's zone id to the host, and the host does every conversion, so the app needs no time zone database.

- **The field looks like a TextField** and can be typed into:
  - the label above in the `label` style and `ink`, `space-2` above the field; optional help `space-2` below in `caption` and `ink-muted`;
  - `surface` fill, 1px `line-strong` border, `radius-md`, `control-height`, `space-4` padding across;
  - the value in `body` and `ink`, written as the locale writes a time, with its 12-hour or 24-hour clock ("09:30" or "9:30 am"), never with seconds;
  - at the end, a clock icon at `icon` size in `ink-muted`, `space-2` from the value. It is decoration, like DatePicker's calendar icon;
  - it is as wide as the longest time in the locale ("12:45 pm"), not the full width of the form.
- **The list** is the Select's list (the Menu's panel and rows, as a list box): under the field, `surface-raised`, `shadow-2`, `radius-md`, rows `control-height` tall, the highlight `surface-hover`, a check mark in `accent` at the end of the current time's row.
  - It holds a time every 15 minutes. It opens scrolled so the field's time is in the middle. When the field's time is not on a step (9:37), the nearest step is in the middle and no row has a check.
  - About eight rows show, then it scrolls.
  - **In the end field** the list starts 15 minutes after the start time and runs for 24 hours, and each row adds the length from the start in `ink-muted`, `space-2` after the time: "10:30  1 hr", "11:15  1 hr 45 min". The length is written as the locale writes a short duration. Picking a row past midnight also moves the end date to the next day, because the row names the length the user chose. Typing a time never moves a date.
- **States of the field:**
  - Hover: none beyond the text cursor, as TextField.
  - Focused: the 2px `focus` ring, 2px outside the field, when focus came from the keyboard. It stays while the list is open. On a field in error the ring is `ink` (design/README.md, "Focus and danger").
  - Disabled: the field at 45% opacity, not focusable, announced as disabled, with the reason as its help, which is not faded (platforms.md, "Disabled controls"). A field is never disabled without a reason.
  - Error: TextField's error state, a 2px `danger` border and the help replaced by the error in `danger` (below).

- **Typing.** The field reads what people actually type:

  | Typed | 24-hour locale shows | 12-hour locale shows |
  |---|---|---|
  | `9:30`, `9.30`, `09:30`, `930` | 09:30 | 9:30 am |
  | `21:30`, `21.30`, `2130` | 21:30 | 9:30 pm |
  | `9.30pm`, `9:30 PM`, `9:30p`, `930pm`, `9.30 p.m.` | 21:30 | 9:30 pm |
  | `9`, `9am`, `9 a.m.` | 09:00 | 9:00 am |
  | `9pm` | 21:00 | 9:00 pm |
  | `12am`, `0:00`, `00:00` | 00:00 | 12:00 am |
  | `12pm`, `12:00` | 12:00 | 12:00 pm |

  - The parts can be split by ":", "." or the locale's own time separator, or not split at all. Digits alone: one or two digits are the hour; three or four digits end with the minutes ("930", "2130").
  - Hours run from 0 to 23 and minutes from 00 to 59.
  - "am" and "pm" can be in any case, with or without dots and a space, or shortened to "a" and "p". The locale's own words for morning and afternoon are read too. Both work in every locale, including 24-hour ones, because people type what they say.
  - With no "am" or "pm", an hour from 13 to 23 is read on the 24-hour clock in every locale. On a 24-hour locale an hour from 0 to 12 is read as written. On a 12-hour locale an hour from 1 to 11 is read as morning ("9:30" is 9:30 am) and 12 as noon, except **in the end field, where it is the first such time after the start**: "5" after a 2 pm start is 5 pm. The text is rewritten at once, so the user sees what was understood.
  - "am" or "pm" after an hour from 13 to 23 ("13pm") is an error, not a guess.
  - Return, Tab or leaving the field commits the time and rewrites it in the locale's form. Escape puts back the time from before the typing.
  - **Error:** "That is not a time. Type it like 9:30 or 21:30." in every locale. While a field is in error, the form keeps its last good time and cannot be saved.
- **Keyboard (desktop):**
  - Up and Down arrows step the time by 15 minutes, to the next or previous quarter hour (9:37 goes to 9:45 or 9:30), and the new time is announced. A step past midnight wraps the clock and leaves the date alone: the date is its own field.
  - Option-Down (Alt-Down elsewhere) opens the list, and so does a click on the field, which also puts the caret in the text. In these fields Option-Down no longer moves the caret to the end of the text; End and ⌘→ still do. In the list, the keys are Select's: Up and Down move the highlight and stop at the ends (it is a list box), Return picks and closes, Escape closes with no change, typing moves the highlight to the next time that starts with what was typed. Focus returns to the field.
- **Screen readers:** the field is a text field named "Start time" or "End time" (the visible label "Starts" covers the date and the time; each field's name says which). Its value is read as the locale says the time ("9:30 am", "21:30"), and its hint is "Type a time, or press Up or Down arrow to change it by 15 minutes". The list is a list box; an end time's row reads its length too ("10:30, 1 hour"). An error is the field's description and is announced when it appears.
- **Motion:** the list opens and closes as Select's (a `base` fade in with the `standard` curve, a `fast` fade out). Stepping and typing change the text at once, with no animation. With reduced motion, the list only fades over `fast`.
- **Light and dark, Kiwi and Hairline:** only tokens. The check mark in the list is `accent`, close to `ink` in Hairline's Graphite, so the check itself, not its colour, marks the current time (as in Select).
- **Phone (under 600px):** the field is the same, with `body` at 16px. Tapping it opens a picker sheet (Sheet), titled with the field's name ("Start time"), with Cancel and Done in its header because it holds a field for typing. At the top of the sheet is that field, with the keyboard for numbers and punctuation; under it, the same list of quarter hours as rows `row-height` tall. Typing and Done, or tapping a row, sets the time and closes the sheet; Cancel closes it with no change. The arrow-key steps do not apply.
- **Sizes:** the field and the list rows are `control-height`; in the Compact density on desktop, `control-height-compact`. On phones the sheet's rows are `row-height`.
- **Token needed:** none.
- **Copy:** labels in sentence case with no full stop. Times as the locale writes them; "am" and "pm" as the locale writes them. Lengths short: "30 min", "1 hr", "1 hr 45 min". The error is a sentence with full stops.

- **The "When" group of the event editor** (phase 6). The event editor is an Inspector, so When is a FormRow group sitting straight on the panel, with no card and no GroupedSection (those belong on a page's `bg` only). Its heading is "When", and its rows, in this order, are:
  1. **All-day:** a Switch in a form (Switch, "In a form"): the title at the start and the switch at the end, not a label above.
  2. **Starts:** a DatePicker and a TimePicker on one line, `space-2` apart, the same height, under the label "Starts". Each field has its own accessible name ("Start date", "Start time").
  3. **Ends:** the same.
  4. **Time zone:** only when the event's zone is not this device's zone (below).
  5. **Repeat:** a Select (Select, "Presets in use"). It belongs to When because it says when the event happens again.
- **Under 600px,** or whenever the date and the time do not fit side by side at the field's width (a long date such as "Wed 14 Oct 2026" beside a 12-hour time needs about 340px at 16px), the time goes under the date, `space-2` below it, still under the one label. Nothing is cut short.
- **All-day on:** the two time fields and the time zone go away, and the dates stay. The rows close up over `base` with a fade; with reduced motion, a `fast` fade only. Turning All-day off brings back the times the event had; a new event gets the next whole hour, one hour long. An all-day event has no time zone (EventRow).
- **Start and end move together.** Changing the start date or time moves the end by the same amount, so the length stays. Changing the end changes the length.
- **An end before the start** is an error on the end field, never moved for the user: "Ends before it starts. Change the end date or time." A timed event that runs past midnight needs its end date changed, or a row past midnight picked from the list; a typed time never moves it to the next day. An end equal to the start is allowed.
- **Time zone:**
  - Times are shown and edited in the event's zone. A new event starts in this device's zone, and an imported event keeps its own.
  - While the event's zone is this device's zone, no zone is shown. A plain Button, "Set time zone", sits after Ends.
  - Pressing it, or opening an event whose zone differs, shows the "Time zone" field: Select's long-list variant (search), showing the zone in the locale's generic form ("New York time"). Under the Ends line, a `caption` in `ink-muted` gives the same times in this device's zone, written as EventRow writes them: "15:00 to 16:00 London time". The host works out these times.
  - Choosing this device's zone again hides the field and the caption, and brings back "Set time zone".
  - The device's zone comes from the platform, as myCalendar reads it today.
- **Used by:**
  - myCalendar edit event and new event: "Start time", "End time", All-day, "Set time zone", "Time zone" and Repeat, in the When group (phase 6).
- **Why these rules.** The 15-minute step for the arrow keys and the list covers almost every meeting time in a list short enough to scroll (96 rows a day); typing any minute works whatever the step. A bare hour in a start field is read as written ("9" is 9 am, "5" is 5 am), because a rule that guesses pm from the hour is right for an office and wrong for an early flight, and the text is rewritten at once so the user sees what was understood. The end field reads a bare hour as the first one after the start.
- **Decided 2026-10-14:** the step is 15 minutes; a bare hour is read as written ("9" = 9 am).
- You provide the label and the accessible name, the time or none, the locale's clock, and for an end field the start (date and time) it is measured from.
