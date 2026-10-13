// The messages between myData Reader and the host.
//
// JSON lines over a Unix socket in the host folder (<home>/run/reader.sock): UTF-8, one object per line.
// The host starts the helper with `open` and passes `--socket <path>`; the helper connects to it, says
// hello, and from then on answers commands. Snapshots are complete for what was asked: the host replaces
// that container's (or those calendars') rows. A snapshot is sent in parts of a few MB each ("part" from 0,
// "last" true on the final one; one part when it is small), so that a large address book with photos or a
// busy calendar never makes a line longer than the host takes. The helper exits when the socket closes.
//
// helper -> host
//   {"type":"hello","version":1,"contacts":"<status>","calendars":"<status>"}
//   {"type":"status","contacts":"<status>","calendars":"<status>"}
//   {"type":"contact_containers","items":[{"id","name","kind"}]}
//   {"type":"calendars","items":[{"id","name","source_id","source_name","source_kind","color"}]}
//   {"type":"contacts_snapshot","container_id","part","last","items":[ContactRecord]}
//   {"type":"events_snapshot","window_start","window_end","part","last","items":[Occurrence]}
//   {"type":"changed","what":"contacts"|"calendars"}
//   {"type":"error","message"}                      never holds personal data
// host -> helper
//   {"cmd":"status"}
//   {"cmd":"request_access","what":"contacts"|"calendars"}
//   {"cmd":"read","what":"contacts"|"calendars"|"all","containers":[ids]|null,"calendars":[ids]|null}
//   {"cmd":"quit"}
//
// Statuses: contacts notDetermined | restricted | denied | authorized;
//           calendars notDetermined | restricted | denied | fullAccess | writeOnly. ("unknown" for a value
//           a later macOS adds.)
// Events: window_start and window_end are local days and both are covered. A timed occurrence has
// start and end in ISO 8601 with the event's offset, and occurrence_date in UTC ("...Z"). An all-day
// occurrence has YYYY-MM-DD for all three, with end exclusive. The key of an occurrence is
// (calendar_id, external_id, occurrence_date).

import Foundation

enum ReaderProtocol {
  static let version = 1
}

/// What a command or a change is about.
enum DataKind: String {
  case contacts
  case calendars
}

// MARK: - Values that encode nil as null

/// Encodes `nil` as JSON `null`. A plain optional is left out of the object instead, and the host expects
/// every key to be there.
@propertyWrapper
struct Nullable<Value: Encodable & Equatable>: Encodable, Equatable {
  var wrappedValue: Value?

  init(wrappedValue: Value?) {
    self.wrappedValue = wrappedValue
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    if let value = wrappedValue {
      try container.encode(value)
    } else {
      try container.encodeNil()
    }
  }
}

// MARK: - Items

struct ContactContainer: Encodable, Equatable {
  let id: String
  let name: String
  /// cardDAV | exchange | local | unassigned
  let kind: String
}

struct CalendarInfo: Encodable, Equatable {
  let id: String
  let name: String
  let sourceId: String
  let sourceName: String
  /// local | exchange | calDAV | mobileMe | subscribed | birthdays
  let sourceKind: String
  /// "#RRGGBB" in sRGB
  @Nullable var color: String?
}

struct LabeledValue: Encodable, Equatable {
  let value: String
  @Nullable var label: String?
}

struct PostalAddress: Encodable, Equatable {
  @Nullable var label: String?
  let street: String
  let city: String
  let region: String
  let postcode: String
  let country: String
}

/// One contact as it is in one container. There is no notes field: macOS gives contact notes only to apps
/// with an entitlement Apple grants on request, and myData does not read them.
struct ContactRecord: Encodable, Equatable {
  let id: String
  let givenName: String
  let familyName: String
  let middleName: String
  let nickname: String
  let organisation: String
  let jobTitle: String
  /// person | organisation
  let kind: String
  let emails: [LabeledValue]
  let phones: [LabeledValue]
  let addresses: [PostalAddress]
  /// "YYYY-MM-DD", or "--MM-DD" without a year
  @Nullable var birthday: String?
  let urls: [LabeledValue]
  @Nullable var photoJpegBase64: String?
}

struct Occurrence: Encodable, Equatable {
  let calendarId: String
  let externalId: String
  let occurrenceDate: String
  let start: String
  let end: String
  let allDay: Bool
  @Nullable var timeZone: String?
  let title: String
  @Nullable var location: String?
  @Nullable var notes: String?
  let detached: Bool
  let recurring: Bool
}

// MARK: - Messages, helper -> host

struct HelloMessage: Encodable {
  let type = "hello"
  let version = ReaderProtocol.version
  let contacts: String
  let calendars: String
}

struct StatusMessage: Encodable {
  let type = "status"
  let contacts: String
  let calendars: String
}

struct ContactContainersMessage: Encodable {
  let type = "contact_containers"
  let items: [ContactContainer]
}

struct CalendarsMessage: Encodable {
  let type = "calendars"
  let items: [CalendarInfo]
}

struct ContactsSnapshotMessage: Encodable {
  let type = "contacts_snapshot"
  let containerId: String
  /// 0 for the first part of the snapshot.
  let part: Int
  /// True on the snapshot's final part: the host replaces the rows then.
  let last: Bool
  let items: [ContactRecord]
}

struct EventsSnapshotMessage: Encodable {
  let type = "events_snapshot"
  let windowStart: String
  let windowEnd: String
  let part: Int
  let last: Bool
  let items: [Occurrence]
}

struct ChangedMessage: Encodable {
  let type = "changed"
  let what: String
}

struct ErrorMessage: Encodable {
  let type = "error"
  /// A fixed sentence, at most with an error domain and code. Never a name, title or address.
  let message: String
}

// MARK: - Commands, host -> helper

enum ReadScope: String {
  case contacts
  case calendars
  case all
}

enum Command: Equatable {
  case status
  case requestAccess(DataKind)
  /// `containers` and `calendars`: the ids to include, or nil for all of them (including ones added later).
  case read(ReadScope, containers: [String]?, calendars: [String]?)
  case quit
}

struct CommandError: Error, Equatable {
  /// Safe to send back: it never repeats what the host sent.
  let message: String
}

extension Command {
  private struct Raw: Decodable {
    let cmd: String
    let what: String?
    let containers: [String]?
    let calendars: [String]?
  }

  static func parse(_ line: String) throws -> Command {
    let raw: Raw
    do {
      raw = try JSONDecoder().decode(Raw.self, from: Data(line.utf8))
    } catch {
      throw CommandError(message: "could not read a command: not a JSON object with a \"cmd\" string")
    }
    switch raw.cmd {
    case "status":
      return .status
    case "quit":
      return .quit
    case "request_access":
      guard let what = raw.what.flatMap(DataKind.init(rawValue:)) else {
        throw CommandError(message: "request_access needs \"what\": \"contacts\" or \"calendars\"")
      }
      return .requestAccess(what)
    case "read":
      guard let scope = raw.what.flatMap(ReadScope.init(rawValue:)) else {
        throw CommandError(message: "read needs \"what\": \"contacts\", \"calendars\" or \"all\"")
      }
      return .read(scope, containers: raw.containers, calendars: raw.calendars)
    default:
      throw CommandError(message: "unknown command")
    }
  }
}

// MARK: - Wire format

enum Wire {
  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return encoder
  }()

  /// How many bytes `value` takes on the wire.
  static func size(_ value: Encodable) throws -> Int {
    try encoder.encode(AnyMessage(value)).count
  }

  /// One message as one line, newline included.
  static func line(_ message: Encodable) throws -> Data {
    var data = try encoder.encode(AnyMessage(message))
    data.append(0x0A)
    return data
  }

  private struct AnyMessage: Encodable {
    let message: Encodable
    init(_ message: Encodable) { self.message = message }
    func encode(to encoder: Encoder) throws { try message.encode(to: encoder) }
  }
}
