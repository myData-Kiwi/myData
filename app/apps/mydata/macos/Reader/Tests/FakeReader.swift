// A stand-in for the Mac's Contacts and Calendars, with invented data only (example.com addresses,
// 555-01xx numbers). It records what the session asked for, so the self-test can check that nothing is read
// before it is allowed and that nothing asks for permission unless told to.

import Foundation

final class FakeReader: PersonalDataReader {
  var contactsState = "authorized"
  var calendarsState = "fullAccess"
  /// What a permission request turns the status into.
  var grantContacts = "authorized"
  var grantCalendars = "fullAccess"

  private(set) var calls: [String] = []
  private(set) var occurrenceQueries: [(start: Date, end: Date, ids: [String]?)] = []
  private(set) var onChange: ((DataKind) -> Void)?

  let containerList = [
    ContactContainer(id: "container-icloud", name: "iCloud", kind: "cardDAV"),
    ContactContainer(id: "container-local", name: "On My Mac", kind: "local"),
  ]

  let people: [String: [ContactRecord]] = [
    "container-icloud": [
      ContactRecord(
        id: "person-ava", givenName: "Ava", familyName: "Fictional", middleName: "", nickname: "Avi",
        organisation: "Example Widgets", jobTitle: "Tester", kind: "person",
        emails: [LabeledValue(value: "ava@example.com", label: "home")],
        phones: [LabeledValue(value: "+1 202 555 0101", label: "mobile")],
        addresses: [
          PostalAddress(
            label: "home", street: "1 Example Street", city: "Exampleton", region: "", postcode: "0000",
            country: "Nowhere")
        ],
        birthday: "--04-09", urls: [LabeledValue(value: "https://example.org/ava", label: nil)],
        photoJpegBase64: nil)
    ],
    "container-local": [
      ContactRecord(
        id: "org-widgets", givenName: "", familyName: "", middleName: "", nickname: "",
        organisation: "Example Widgets", jobTitle: "", kind: "organisation", emails: [],
        phones: [LabeledValue(value: "+1 202 555 0199", label: nil)], addresses: [], birthday: nil, urls: [],
        photoJpegBase64: "/9j/AA==")
    ],
  ]

  let calendarList = [
    CalendarInfo(
      id: "cal-home", name: "Home", sourceId: "source-icloud", sourceName: "iCloud", sourceKind: "calDAV",
      color: "#A9CC4E"),
    CalendarInfo(
      id: "cal-birthdays", name: "Birthdays", sourceId: "source-other", sourceName: "Other",
      sourceKind: "birthdays", color: nil),
  ]

  let events = [
    Occurrence(
      calendarId: "cal-home", externalId: "event-dentist", occurrenceDate: "2026-03-19T21:00:00Z",
      start: "2026-03-20T10:00:00+13:00", end: "2026-03-20T11:00:00+13:00", allDay: false,
      timeZone: "Pacific/Auckland", title: "Dentist", location: "1 Example Street", notes: "Invented note",
      detached: false, recurring: false),
    Occurrence(
      calendarId: "cal-birthdays", externalId: "birthday-ava", occurrenceDate: "2026-04-09",
      start: "2026-04-09", end: "2026-04-10", allDay: true, timeZone: nil, title: "Ava Fictional's Birthday",
      location: nil, notes: nil, detached: false, recurring: true),
  ]

  func contactsStatus() -> String { contactsState }
  func calendarsStatus() -> String { calendarsState }

  func requestContactsAccess(_ completion: @escaping (Bool) -> Void) {
    calls.append("requestContactsAccess")
    contactsState = grantContacts
    completion(contactsState == "authorized")
  }

  func requestCalendarsAccess(_ completion: @escaping (Bool) -> Void) {
    calls.append("requestCalendarsAccess")
    calendarsState = grantCalendars
    completion(calendarsState == "fullAccess")
  }

  func contactContainers() throws -> [ContactContainer] {
    calls.append("contactContainers")
    guard contactsState == "authorized" else { throw ReaderError.notAllowed(.contacts) }
    return containerList
  }

  func contacts(inContainer id: String) throws -> [ContactRecord] {
    calls.append("contacts:\(id)")
    guard contactsState == "authorized" else { throw ReaderError.notAllowed(.contacts) }
    return people[id] ?? []
  }

  func calendars() throws -> [CalendarInfo] {
    calls.append("calendars")
    guard calendarsState == "fullAccess" else { throw ReaderError.notAllowed(.calendars) }
    return calendarList
  }

  func occurrences(start: Date, end: Date, calendarIds: [String]?) throws -> [Occurrence] {
    calls.append("occurrences")
    guard calendarsState == "fullAccess" else { throw ReaderError.notAllowed(.calendars) }
    occurrenceQueries.append((start, end, calendarIds))
    return events.filter { calendarIds?.contains($0.calendarId) ?? true }
  }

  func observeChanges(_ onChange: @escaping (DataKind) -> Void) {
    calls.append("observeChanges")
    self.onChange = onChange
  }

  func forget() {
    calls = []
    occurrenceQueries = []
  }
}
