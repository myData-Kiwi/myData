// Runs the helper's session and conversions against FakeReader and prints what came out, one JSON object
// per case. host/tests/test_mac_reader_readonly.py compiles this with the helper's sources (all but
// main.swift), runs it, and checks the output. It never touches the Mac's real Contacts or Calendars.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let auckland = TimeZone(identifier: "Pacific/Auckland")!
let utc = TimeZone(identifier: "UTC")!

func date(_ iso: String) -> Date {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime]
  guard let d = formatter.date(from: iso) else { fatalError("bad date in the self-test: \(iso)") }
  return d
}

func iso(_ d: Date) -> String { Formats.utcTimestamp(d) }

func json(_ message: Encodable) -> Any {
  let line = try! Wire.line(message)
  return try! JSONSerialization.jsonObject(with: line)
}

func emit(_ name: String, _ fields: [String: Any]) {
  var object = fields
  object["case"] = name
  let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
  FileHandle.standardOutput.write(data)
  FileHandle.standardOutput.write(Data([0x0A]))
}

final class Harness {
  var now: Date
  let fake = FakeReader()
  var sent: [Any] = []
  var debounced: [String: () -> Void] = [:]
  var quitCalled = false
  var session: ReaderSession!

  init(now: String = "2026-03-18T09:00:00+13:00") {
    self.now = date(now)
    let hooks = SessionHooks(
      now: { [unowned self] in self.now },
      perform: { $0() },
      debounce: { [unowned self] kind, run in self.debounced[kind.rawValue] = run },
      quit: { [unowned self] in self.quitCalled = true },
      localCalendar: { Formats.gregorian(auckland) })
    session = ReaderSession(reader: fake, send: { [unowned self] in self.sent.append(json($0)) }, hooks: hooks)
  }

  func take() -> [Any] {
    defer { sent = [] }
    return sent
  }

  func queries() -> [[String: Any]] {
    fake.occurrenceQueries.map { ["start": iso($0.start), "end": iso($0.end), "ids": ($0.ids as Any?) ?? NSNull()] }
  }

  func runDebounced() {
    let pending = debounced
    debounced = [:]
    for key in pending.keys.sorted() { pending[key]!() }
  }
}

@main
struct SelfTest {
  static func main() {
    sessionCases()
    changeCases()
    tickCases()
    commandCases()
    conversionCases()
  }

  static func sessionCases() {
    var h = Harness()
    h.session.start()
    emit("hello", ["messages": h.take(), "calls": h.fake.calls])

    h = Harness()
    h.session.handle(line: #"{"cmd":"read","what":"all","containers":null,"calendars":null}"#)
    emit("read_all", ["messages": h.take(), "calls": h.fake.calls, "queries": h.queries()])

    h = Harness()
    h.session.handle(line: #"{"cmd":"read","what":"all","containers":["container-local"],"calendars":["cal-home","cal-gone"]}"#)
    emit("read_selected", ["messages": h.take(), "calls": h.fake.calls, "queries": h.queries()])

    h = Harness()
    h.session.handle(line: #"{"cmd":"read","what":"calendars"}"#)
    emit("read_calendars_only", ["messages": h.take(), "calls": h.fake.calls])

    h = Harness()
    h.session.partBytes = 1  // every item in a part of its own
    h.session.handle(line: #"{"cmd":"read","what":"all"}"#)
    let small = h.take()
    h.session.partBytes = ReaderSession.defaultPartBytes
    let sizes = [1, 4096 + 200, 4096 + 2000, 1 << 30].map { bytes -> Int in
      h.session.partBytes = bytes
      return h.session.parts(h.fake.events).count
    }
    emit("read_in_parts", ["messages": small, "part_counts": sizes, "empty_parts": h.session.parts([Occurrence]()).count])

    h = Harness()
    h.session.handle(line: #"{"cmd":"read","what":"all","containers":[],"calendars":[]}"#)
    emit("read_none_chosen", ["messages": h.take(), "calls": h.fake.calls, "queries": h.queries()])

    h = Harness()
    h.fake.contactsState = "notDetermined"
    h.fake.calendarsState = "denied"
    h.session.start()
    h.session.handle(line: #"{"cmd":"read","what":"all"}"#)
    emit("not_allowed", ["messages": h.take(), "calls": h.fake.calls])

    h = Harness()
    h.fake.contactsState = "notDetermined"
    h.session.start()
    _ = h.take()
    h.session.handle(line: #"{"cmd":"request_access","what":"contacts"}"#)
    emit("request_access", ["messages": h.take(), "calls": h.fake.calls])

    h = Harness()
    h.fake.contactsState = "notDetermined"
    h.session.start()
    h.session.handle(line: #"{"cmd":"read","what":"contacts"}"#)
    _ = h.take()
    h.session.handle(line: #"{"cmd":"request_access","what":"contacts"}"#)
    emit("request_after_read", ["messages": h.take(), "calls": h.fake.calls])

    h = Harness()
    h.fake.calendarsState = "notDetermined"
    h.fake.grantCalendars = "denied"
    h.session.start()
    _ = h.take()
    h.session.handle(line: #"{"cmd":"request_access","what":"calendars"}"#)
    emit("request_denied", ["messages": h.take(), "calls": h.fake.calls])
  }

  static func changeCases() {
    var h = Harness()
    h.session.handle(line: #"{"cmd":"read","what":"all"}"#)
    _ = h.take()
    h.fake.onChange?(.contacts)  // macOS's notice at start: ignored
    let duringGrace = Array(h.debounced.keys)
    h.now = h.now.addingTimeInterval(3)
    h.fake.onChange?(.contacts)
    h.fake.onChange?(.contacts)
    h.fake.onChange?(.calendars)
    let afterGrace = Array(h.debounced.keys).sorted()
    h.fake.forget()
    h.runDebounced()
    emit(
      "changes",
      [
        "during_grace": duringGrace, "after_grace": afterGrace, "messages": h.take(), "calls": h.fake.calls,
      ])

    h = Harness()
    h.session.handle(line: #"{"cmd":"read","what":"contacts"}"#)
    h.now = h.now.addingTimeInterval(3)
    h.fake.onChange?(.calendars)
    emit("change_not_followed", ["debounced": Array(h.debounced.keys)])
  }

  static func tickCases() {
    var h = Harness()
    h.session.start()
    h.session.handle(line: #"{"cmd":"read","what":"all"}"#)
    _ = h.take()
    h.fake.forget()
    h.now = h.now.addingTimeInterval(60)
    h.session.tick()
    emit("tick_quiet", ["messages": h.take(), "calls": h.fake.calls])

    h.fake.forget()
    h.now = h.now.addingTimeInterval(15 * 60)
    h.session.tick()
    emit("tick_safety", ["messages": h.take(), "calls": h.fake.calls])

    h = Harness(now: "2026-03-18T23:59:00+13:00")
    h.session.start()
    h.session.handle(line: #"{"cmd":"read","what":"all"}"#)
    _ = h.take()
    h.fake.forget()
    h.now = h.now.addingTimeInterval(120)
    h.session.tick()
    emit("tick_new_day", ["messages": h.take(), "calls": h.fake.calls, "queries": h.queries()])

    h = Harness()
    h.session.handle(line: #"{"cmd":"read","what":"all"}"#)
    _ = h.take()
    h.fake.forget()
    h.session.tick()
    emit("tick_before_start", ["messages": h.take(), "calls": h.fake.calls])

    h = Harness()
    h.session.start()
    _ = h.take()
    h.fake.calendarsState = "denied"
    h.now = h.now.addingTimeInterval(60)
    h.session.tick()
    let revoked = h.take()
    h.session.tick()
    emit("tick_status", ["revoked": revoked, "again": h.take()])
  }

  static func commandCases() {
    let h = Harness()
    var errors: [Any] = []
    for line in [
      "not json at all", #"{"cmd":"read"}"#, #"{"cmd":"read","what":"everything"}"#,
      #"{"cmd":"drop","what":"Ava Fictional"}"#, #"{"cmd":"request_access","what":"mail"}"#, #"["cmd"]"#,
    ] {
      h.session.handle(line: line)
      errors.append(h.take())
    }
    h.session.handle(line: "   ")
    let blank = h.take()
    h.session.handle(line: #"{"cmd":"status"}"#)
    let status = h.take()
    h.session.handle(line: #"{"cmd":"quit"}"#)
    emit(
      "commands",
      ["errors": errors, "blank": blank, "status": status, "quit": h.quitCalled, "calls": h.fake.calls])
  }

  static func conversionCases() {
    let nz = Formats.gregorian(auckland)
    let spans = SystemPersonalDataReader.spans(from: date("2019-01-01T00:00:00Z"), to: date("2031-01-01T00:00:00Z"))
    let window = EventWindow.around(date("2026-03-18T09:00:00+13:00"), calendar: nz)
    let windowSpans = SystemPersonalDataReader.spans(from: window.start, to: window.end)
    let leap = EventWindow.around(date("2028-02-29T12:00:00+13:00"), calendar: nz)

    var withYear = DateComponents()
    withYear.year = 1990
    withYear.month = 4
    withYear.day = 9
    var noYear = DateComponents()
    noYear.month = 4
    noYear.day = 9
    var noMonth = DateComponents()
    noMonth.day = 9

    func allDay(_ s: String, _ e: String) -> [String] {
      let r = Formats.allDayRange(start: date(s), end: date(e), calendar: nz)
      return [r.start, r.end]
    }

    let png = makeImage(UTType.png)
    let jpeg = makeImage(UTType.jpeg)
    let converted = Formats.jpeg(png)
    func orNull(_ value: String?) -> Any { value.map { $0 as Any } ?? NSNull() }
    let kiwi = CGColor(srgbRed: 169 / 255, green: 204 / 255, blue: 78 / 255, alpha: 1)

    var out: [String: Any] = [:]
    out["spans"] = spans.map { [iso($0.start), iso($0.end), $0.duration] as [Any] }
    out["max_span"] = SystemPersonalDataReader.maxSpan
    out["window"] = [iso(window.start), iso(window.end), window.firstDay, window.lastDay]
    out["window_spans"] = windowSpans.count
    out["leap_window"] = [leap.firstDay, leap.lastDay]
    out["all_day_one"] = allDay("2026-04-09T00:00:00+12:00", "2026-04-09T23:59:59+12:00")
    out["all_day_midnight_end"] = allDay("2026-04-09T00:00:00+12:00", "2026-04-11T00:00:00+12:00")
    out["all_day_zero"] = allDay("2026-04-09T00:00:00+12:00", "2026-04-09T00:00:00+12:00")
    out["timestamp"] = Formats.timestamp(date("2026-03-19T21:00:00Z"), auckland)
    out["timestamp_utc"] = Formats.utcTimestamp(date("2026-03-20T10:00:00+13:00"))
    out["timestamp_in_utc_zone"] = Formats.timestamp(date("2026-03-19T21:00:00Z"), utc)
    out["birthday"] = [withYear, noYear, noMonth].map { orNull(Formats.birthday($0)) }
    out["labels"] = ["_$!<Mobile>!$_", "_$!<HomePage>!$_", "Gym", "", nil].map { orNull(Formats.plainLabel($0)) }
    out["colors"] = [kiwi, CGColor(gray: 0, alpha: 1), CGColor(gray: 1, alpha: 1)].map {
      orNull(Formats.hexColor($0))
    }
    out["jpeg_from_png"] = converted.map { Array($0.prefix(3)) } ?? []
    out["jpeg_kept"] = Formats.jpeg(jpeg) == jpeg
    out["jpeg_garbage"] = Formats.jpeg(Data("not an image".utf8)) == nil
    out["jpeg_empty"] = Formats.jpeg(Data()) == nil && Formats.jpeg(nil) == nil
    out["text"] = ["x", "", nil].map { orNull(Formats.text($0)) }
    out["selection"] = [
      Selection(nil).includes("anything"), Selection(["a"]).includes("a"), Selection(["a"]).includes("b"),
    ]
    emit("conversions", out)
  }

  static func makeImage(_ type: UTType) -> Data {
    let context = CGContext(
      data: nil, width: 2, height: 2, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(srgbRed: 0.66, green: 0.8, blue: 0.3, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    let image = context.makeImage()!
    let out = NSMutableData()
    let destination = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    _ = CGImageDestinationFinalize(destination)
    return out as Data
  }
}
