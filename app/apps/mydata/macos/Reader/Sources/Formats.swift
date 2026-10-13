// Plain conversions from framework values to the strings in the protocol. Nothing here touches Contacts or
// Calendars, so the self-test can check every one of them with invented values.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum Formats {
  /// A Gregorian calendar in `timeZone`. Dates on the wire are always Gregorian, whatever calendar the user
  /// has chosen in System Settings.
  static func gregorian(_ timeZone: TimeZone = .current) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
  }

  /// YYYY-MM-DD of `date` in the calendar's time zone.
  static func day(_ date: Date, _ calendar: Calendar) -> String {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  /// ISO 8601 with the offset of `timeZone`, for example 2026-03-18T10:00:00+13:00.
  static func timestamp(_ date: Date, _ timeZone: TimeZone) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = timeZone
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
  }

  /// ISO 8601 in UTC, for example 2026-03-17T21:00:00Z. Used for occurrence keys, which must not change
  /// when the Mac's time zone does.
  static func utcTimestamp(_ date: Date) -> String {
    timestamp(date, TimeZone(identifier: "UTC")!)
  }

  /// The days an all-day event covers, end exclusive. EventKit ends an all-day event at 23:59:59 of its
  /// last day (some accounts at midnight after it); both give the same answer here.
  static func allDayRange(start: Date, end: Date, calendar: Calendar) -> (start: String, end: String) {
    let first = calendar.startOfDay(for: start)
    let lastInstant = end > start ? end.addingTimeInterval(-1) : start
    let last = calendar.startOfDay(for: lastInstant)
    let after = calendar.date(byAdding: .day, value: 1, to: last) ?? last
    return (day(first, calendar), day(after, calendar))
  }

  /// "YYYY-MM-DD", "--MM-DD" when the year is not known, or nil when there is no usable month and day.
  static func birthday(_ components: DateComponents) -> String? {
    guard let month = components.month, let dayOfMonth = components.day,
      (1...12).contains(month), (1...31).contains(dayOfMonth)
    else { return nil }
    if let year = components.year, year != NSDateComponentUndefined, year > 0 {
      return String(format: "%04d-%02d-%02d", year, month, dayOfMonth)
    }
    return String(format: "--%02d-%02d", month, dayOfMonth)
  }

  /// Apple's built-in labels look like "_$!<Mobile>!$_"; they become "mobile". A label the user typed is
  /// kept as it is. Empty or missing: nil.
  static func plainLabel(_ raw: String?) -> String? {
    guard let raw, !raw.isEmpty else { return nil }
    if raw.hasPrefix("_$!<"), raw.hasSuffix(">!$_"), raw.count > 8 {
      return String(raw.dropFirst(4).dropLast(4)).lowercased()
    }
    return raw
  }

  /// "#RRGGBB" in sRGB, or nil when the colour cannot be converted.
  static func hexColor(_ color: CGColor) -> String? {
    guard let srgb = CGColorSpace(name: CGColorSpace.sRGB),
      let converted = color.converted(to: srgb, intent: .defaultIntent, options: nil),
      let parts = converted.components, parts.count >= 3
    else { return nil }
    func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
    return String(format: "#%02X%02X%02X", byte(parts[0]), byte(parts[1]), byte(parts[2]))
  }

  /// The photo as JPEG: kept as it is when it already is one, converted otherwise. Nil when it is not an
  /// image.
  static func jpeg(_ data: Data?) -> Data? {
    guard let data, !data.isEmpty else { return nil }
    if data.starts(with: [0xFF, 0xD8, 0xFF]) { return data }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    let out = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)
    else { return nil }
    CGImageDestinationAddImage(
      destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return out as Data
  }

  /// Nil for nil or empty text.
  static func text(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
  }
}

/// The events the Mac source mirrors: one year back and two years ahead of today, whole local days.
struct EventWindow: Equatable {
  /// Midnight starting `firstDay`.
  let start: Date
  /// Midnight after `lastDay`: the query end, exclusive.
  let end: Date
  /// window_start: the first day covered.
  let firstDay: String
  /// window_end: the last day covered.
  let lastDay: String

  static let yearsBack = 1
  static let yearsAhead = 2

  static func around(_ now: Date, calendar: Calendar) -> EventWindow {
    let today = calendar.startOfDay(for: now)
    let first = calendar.startOfDay(
      for: calendar.date(byAdding: .year, value: -yearsBack, to: today) ?? today)
    let last = calendar.startOfDay(
      for: calendar.date(byAdding: .year, value: yearsAhead, to: today) ?? today)
    let end = calendar.date(byAdding: .day, value: 1, to: last) ?? last
    return EventWindow(
      start: first, end: end, firstDay: Formats.day(first, calendar), lastDay: Formats.day(last, calendar))
  }
}
