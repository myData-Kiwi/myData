// The only file that touches Contacts and Calendars.
//
// Everything the helper does with them goes through `PersonalDataReader`, which can only read. There is no
// method that changes a contact, an event or a calendar, and a host test scans the helper's sources for the
// frameworks' write calls (tests/test_mac_reader_readonly.py).
//
// Contact notes are never asked for: macOS gives them only to apps with an entitlement Apple grants on
// request, and asking without it makes the fetch fail. Contacts are not read as vCards either, because a
// vCard's required keys include the notes.

import Contacts
import CoreGraphics
import EventKit
import Foundation

enum ReaderError: Error {
  /// Reading was asked for before the user allowed it. Reading then could make macOS ask, and the helper
  /// asks only when the user presses Allow in the myData app.
  case notAllowed(DataKind)
}

/// Read-only access to the Mac's Contacts and Calendars.
protocol PersonalDataReader: AnyObject {
  /// notDetermined | restricted | denied | authorized. Never asks the user.
  func contactsStatus() -> String
  /// notDetermined | restricted | denied | fullAccess | writeOnly. Never asks the user.
  func calendarsStatus() -> String
  /// Shows the system's permission prompt if the user has not decided yet.
  func requestContactsAccess(_ completion: @escaping (Bool) -> Void)
  /// Shows the system's permission prompt (full access) if the user has not decided yet.
  func requestCalendarsAccess(_ completion: @escaping (Bool) -> Void)
  /// Every contacts account on this Mac (iCloud, Exchange, Google, On My Mac, ...).
  func contactContainers() throws -> [ContactContainer]
  /// The contacts in one account, not merged with the same person in other accounts.
  func contacts(inContainer id: String) throws -> [ContactRecord]
  /// Every event calendar.
  func calendars() throws -> [CalendarInfo]
  /// Occurrences overlapping [start, end) in the given calendars (nil: all), recurring events expanded.
  func occurrences(start: Date, end: Date, calendarIds: [String]?) throws -> [Occurrence]
  /// Calls `onChange` (on any thread) when contacts or calendars change on this Mac or arrive from another
  /// device.
  func observeChanges(_ onChange: @escaping (DataKind) -> Void)
}

final class SystemPersonalDataReader: PersonalDataReader {
  // Created on first use, so that `status-only` never makes a store.
  private lazy var contactStore = CNContactStore()
  private lazy var eventStore = EKEventStore()
  private var observers: [NSObjectProtocol] = []

  // MARK: Permission

  func contactsStatus() -> String {
    Self.describe(CNContactStore.authorizationStatus(for: .contacts))
  }

  func calendarsStatus() -> String {
    Self.describe(EKEventStore.authorizationStatus(for: .event))
  }

  static func describe(_ status: CNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .authorized: return "authorized"
    @unknown default: return "unknown"
    }
  }

  static func describe(_ status: EKAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .fullAccess: return "fullAccess"
    case .writeOnly: return "writeOnly"
    @unknown default: return "unknown"
    }
  }

  func requestContactsAccess(_ completion: @escaping (Bool) -> Void) {
    contactStore.requestAccess(for: .contacts) { granted, _ in completion(granted) }
  }

  func requestCalendarsAccess(_ completion: @escaping (Bool) -> Void) {
    eventStore.requestFullAccessToEvents { granted, _ in completion(granted) }
  }

  private func requireContacts() throws {
    guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
      throw ReaderError.notAllowed(.contacts)
    }
  }

  private func requireCalendars() throws {
    guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
      throw ReaderError.notAllowed(.calendars)
    }
  }

  // MARK: Contacts

  /// The fields myData shows. Not the note (see the top of the file).
  static let contactKeys: [CNKeyDescriptor] =
    [
      CNContactIdentifierKey, CNContactGivenNameKey, CNContactFamilyNameKey, CNContactMiddleNameKey,
      CNContactNicknameKey, CNContactOrganizationNameKey, CNContactJobTitleKey, CNContactEmailAddressesKey,
      CNContactPhoneNumbersKey, CNContactPostalAddressesKey, CNContactBirthdayKey, CNContactUrlAddressesKey,
      CNContactTypeKey, CNContactImageDataAvailableKey, CNContactThumbnailImageDataKey,
    ].map { $0 as CNKeyDescriptor } + [CNContactFormatter.descriptorForRequiredKeys(for: .fullName)]

  func contactContainers() throws -> [ContactContainer] {
    try requireContacts()
    return try contactStore.containers(matching: nil).map {
      ContactContainer(id: $0.identifier, name: $0.name, kind: Self.kind($0.type))
    }
  }

  static func kind(_ type: CNContainerType) -> String {
    switch type {
    case .local: return "local"
    case .exchange: return "exchange"
    case .cardDAV: return "cardDAV"
    case .unassigned: return "unassigned"
    @unknown default: return "unassigned"
    }
  }

  func contacts(inContainer id: String) throws -> [ContactRecord] {
    try requireContacts()
    let request = CNContactFetchRequest(keysToFetch: Self.contactKeys)
    request.predicate = CNContact.predicateForContactsInContainer(withIdentifier: id)
    request.unifyResults = false
    var records: [ContactRecord] = []
    try contactStore.enumerateContacts(with: request) { contact, _ in
      records.append(Self.record(contact))
    }
    return records
  }

  static func record(_ c: CNContact) -> ContactRecord {
    ContactRecord(
      id: c.identifier,
      givenName: c.givenName,
      familyName: c.familyName,
      middleName: c.middleName,
      nickname: c.nickname,
      organisation: c.organizationName,
      jobTitle: c.jobTitle,
      kind: c.contactType == .organization ? "organisation" : "person",
      emails: c.emailAddresses.map { LabeledValue(value: $0.value as String, label: Formats.plainLabel($0.label)) },
      phones: c.phoneNumbers.map { LabeledValue(value: $0.value.stringValue, label: Formats.plainLabel($0.label)) },
      addresses: c.postalAddresses.map {
        PostalAddress(
          label: Formats.plainLabel($0.label), street: $0.value.street, city: $0.value.city,
          region: $0.value.state, postcode: $0.value.postalCode, country: $0.value.country)
      },
      birthday: c.birthday.flatMap(Formats.birthday),
      urls: c.urlAddresses.map { LabeledValue(value: $0.value as String, label: Formats.plainLabel($0.label)) },
      photoJpegBase64: c.imageDataAvailable ? Formats.jpeg(c.thumbnailImageData)?.base64EncodedString() : nil)
  }

  // MARK: Calendars

  func calendars() throws -> [CalendarInfo] {
    try requireCalendars()
    return eventStore.calendars(for: .event).map { calendar in
      CalendarInfo(
        id: calendar.calendarIdentifier,
        name: calendar.title,
        sourceId: calendar.source?.sourceIdentifier ?? "",
        sourceName: calendar.source?.title ?? "",
        sourceKind: Self.kind(calendar.source?.sourceType),
        color: calendar.cgColor.flatMap(Formats.hexColor))
    }
  }

  static func kind(_ type: EKSourceType?) -> String {
    switch type {
    case .local?: return "local"
    case .exchange?: return "exchange"
    case .calDAV?: return "calDAV"
    case .mobileMe?: return "mobileMe"
    case .subscribed?: return "subscribed"
    case .birthdays?: return "birthdays"
    default: return "local"
    }
  }

  /// EventKit matches at most four years per query and silently cuts a longer range, so a longer range is
  /// asked for in pieces. 4 × 365 days is never more than four calendar years.
  static let maxSpan: TimeInterval = 4 * 365 * 86_400

  /// [start, end) in consecutive pieces of at most `maxSpan`.
  static func spans(from start: Date, to end: Date, maxSpan: TimeInterval = maxSpan) -> [DateInterval] {
    var pieces: [DateInterval] = []
    var from = start
    while from < end {
      let to = min(from.addingTimeInterval(maxSpan), end)
      pieces.append(DateInterval(start: from, end: to))
      from = to
    }
    return pieces
  }

  func occurrences(start: Date, end: Date, calendarIds: [String]?) throws -> [Occurrence] {
    try requireCalendars()
    var chosen: [EKCalendar]? = nil
    if let ids = calendarIds {
      let wanted = Set(ids)
      let found = eventStore.calendars(for: .event).filter { wanted.contains($0.calendarIdentifier) }
      if found.isEmpty { return [] }  // nil would mean every calendar
      chosen = found
    }
    let local = Formats.gregorian()
    var seen = Set<String>()
    var result: [Occurrence] = []
    for piece in Self.spans(from: start, to: end) {
      let predicate = eventStore.predicateForEvents(withStart: piece.start, end: piece.end, calendars: chosen)
      for event in eventStore.events(matching: predicate) {
        guard let occurrence = Self.occurrence(event, local: local) else { continue }
        // An event that crosses a piece boundary comes back in both pieces.
        let key = [occurrence.calendarId, occurrence.externalId, occurrence.occurrenceDate].joined(separator: "\u{1F}")
        if seen.insert(key).inserted { result.append(occurrence) }
      }
    }
    return result
  }

  static func occurrence(_ e: EKEvent, local: Calendar) -> Occurrence? {
    guard let calendar = e.calendar, let start = e.startDate, let end = e.endDate else { return nil }
    let original = e.occurrenceDate ?? start
    let startText: String
    let endText: String
    let occurrenceDate: String
    if e.isAllDay {
      (startText, endText) = Formats.allDayRange(start: start, end: end, calendar: local)
      occurrenceDate = Formats.day(original, local)
    } else {
      let zone = e.timeZone ?? local.timeZone
      startText = Formats.timestamp(start, zone)
      endText = Formats.timestamp(max(end, start), zone)
      occurrenceDate = Formats.utcTimestamp(original)
    }
    return Occurrence(
      calendarId: calendar.calendarIdentifier,
      externalId: e.calendarItemExternalIdentifier ?? e.calendarItemIdentifier,
      occurrenceDate: occurrenceDate,
      start: startText,
      end: endText,
      allDay: e.isAllDay,
      timeZone: e.isAllDay ? nil : e.timeZone?.identifier,
      title: e.title ?? "",
      location: Formats.text(e.location),
      notes: Formats.text(e.notes),
      detached: e.isDetached,
      recurring: e.hasRecurrenceRules)
  }

  // MARK: Changes

  func observeChanges(_ onChange: @escaping (DataKind) -> Void) {
    guard observers.isEmpty else { return }
    let center = NotificationCenter.default
    observers = [
      center.addObserver(forName: .CNContactStoreDidChange, object: nil, queue: nil) { _ in onChange(.contacts) },
      center.addObserver(forName: .EKEventStoreChanged, object: eventStore, queue: nil) { _ in onChange(.calendars) },
    ]
    _ = contactStore  // the contacts notification is posted only while a store exists
  }
}
