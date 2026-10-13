// What the helper does with the host's commands and with change notices. It reaches Contacts and
// Calendars only through `PersonalDataReader`, so the self-test runs it against a fake with invented data.
//
// Not thread-safe: every method runs on one serial queue (main.swift's work queue; the caller in tests).

import Foundation

/// Which ids the host wants: all of them (including ones added later), or a list.
enum Selection: Equatable {
  case all
  case only(Set<String>)

  init(_ ids: [String]?) {
    self = ids.map { .only(Set($0)) } ?? .all
  }

  func includes(_ id: String) -> Bool {
    switch self {
    case .all: return true
    case .only(let ids): return ids.contains(id)
    }
  }
}

struct SessionHooks {
  var now: () -> Date = Date.init
  /// Runs a closure on the session's queue. Permission answers arrive on other threads.
  var perform: (@escaping () -> Void) -> Void
  /// Runs `reread` once changes of `kind` have stopped arriving for a short while; the latest call wins.
  var debounce: (DataKind, @escaping () -> Void) -> Void
  var quit: () -> Void
  /// The calendar for local days. A function, so that a change of the Mac's time zone is picked up.
  var localCalendar: () -> Calendar = { Formats.gregorian() }
}

final class ReaderSession {
  /// Ignore change notices this long after starting to watch: macOS posts one for contacts as soon as a
  /// store is made, before anything changed.
  static let startupGrace: TimeInterval = 2
  /// Read everything again this often even without a change notice.
  static let safetyInterval: TimeInterval = 15 * 60
  /// The most bytes one snapshot part takes on the wire. The host takes lines of up to 64 MB; parts stay
  /// far below that.
  static let defaultPartBytes = 4 << 20

  /// See `defaultPartBytes`. The self-test makes it small to check the splitting.
  var partBytes = ReaderSession.defaultPartBytes

  private let reader: PersonalDataReader
  private let send: (Encodable) -> Void
  private let hooks: SessionHooks

  /// nil until the host asks for that kind; from then on the helper keeps it current.
  private(set) var contactsSelection: Selection?
  private(set) var calendarsSelection: Selection?
  private var lastStatus: (contacts: String, calendars: String)?
  private var lastFullRead: Date?
  /// window_start of the last events snapshot.
  private(set) var windowFirstDay: String?
  private var watching = false
  private var ignoreChangesUntil = Date.distantPast

  init(reader: PersonalDataReader, send: @escaping (Encodable) -> Void, hooks: SessionHooks) {
    self.reader = reader
    self.send = send
    self.hooks = hooks
  }

  // MARK: Start, commands

  func start() {
    let status = currentStatus()
    lastStatus = status
    send(HelloMessage(contacts: status.contacts, calendars: status.calendars))
  }

  func handle(line: String) {
    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    do {
      handle(try Command.parse(trimmed))
    } catch let error as CommandError {
      send(ErrorMessage(message: error.message))
    } catch {
      send(ErrorMessage(message: "could not read a command"))
    }
  }

  func handle(_ command: Command) {
    switch command {
    case .status:
      sendStatus()
    case .requestAccess(let kind):
      let answered: (Bool) -> Void = { [weak self] _ in
        self?.hooks.perform { self?.statusMayHaveChanged(force: true) }
      }
      switch kind {
      case .contacts: reader.requestContactsAccess(answered)
      case .calendars: reader.requestCalendarsAccess(answered)
      }
    case .read(let scope, let containers, let calendars):
      if scope != .calendars {
        contactsSelection = Selection(containers)
        readContacts()
      }
      if scope != .contacts {
        calendarsSelection = Selection(calendars)
        readCalendars()
      }
      if contactsSelection != nil, calendarsSelection != nil { lastFullRead = hooks.now() }
    case .quit:
      hooks.quit()
    }
  }

  // MARK: Changes and the timer

  /// A change notice from macOS. Re-reads after the notices stop, if the host follows that kind.
  func changeNoticed(_ kind: DataKind) {
    guard hooks.now() >= ignoreChangesUntil else { return }
    guard selection(kind) != nil else { return }
    hooks.debounce(kind) { [weak self] in self?.reread(kind) }
  }

  /// Says what changed, then sends a fresh snapshot of it.
  func reread(_ kind: DataKind) {
    guard selection(kind) != nil else { return }
    send(ChangedMessage(what: kind.rawValue))
    switch kind {
    case .contacts: readContacts()
    case .calendars: readCalendars()
    }
  }

  /// Runs about once a minute. Uses the wall clock, so it catches up after the Mac sleeps.
  func tick() {
    statusMayHaveChanged(force: false)
    let now = hooks.now()
    if let last = lastFullRead, now.timeIntervalSince(last) >= Self.safetyInterval || now < last {
      readFollowed()
      return
    }
    if calendarsSelection != nil, let first = windowFirstDay,
      EventWindow.around(now, calendar: hooks.localCalendar()).firstDay != first
    {
      readCalendars()  // a new day: the window moves
    }
  }

  // MARK: Reading

  private func selection(_ kind: DataKind) -> Selection? {
    kind == .contacts ? contactsSelection : calendarsSelection
  }

  private func readFollowed() {
    if contactsSelection != nil { readContacts() }
    if calendarsSelection != nil { readCalendars() }
    lastFullRead = hooks.now()
  }

  private func readContacts() {
    guard let selection = contactsSelection else { return }
    guard reader.contactsStatus() == "authorized" else {
      send(ErrorMessage(message: "contacts are not allowed yet"))
      statusMayHaveChanged(force: false)
      return
    }
    watchChanges()
    let containers: [ContactContainer]
    do {
      containers = try reader.contactContainers()
    } catch {
      send(ErrorMessage(message: "could not list contact accounts (\(Self.describe(error)))"))
      return
    }
    send(ContactContainersMessage(items: containers))
    for container in containers where selection.includes(container.id) {
      do {
        let chunks = parts(try reader.contacts(inContainer: container.id))
        for (index, chunk) in chunks.enumerated() {
          send(
            ContactsSnapshotMessage(
              containerId: container.id, part: index, last: index == chunks.count - 1, items: chunk))
        }
      } catch {
        send(ErrorMessage(message: "could not read the contacts of one account (\(Self.describe(error)))"))
      }
    }
    if lastFullRead == nil { lastFullRead = hooks.now() }
  }

  private func readCalendars() {
    guard let selection = calendarsSelection else { return }
    guard reader.calendarsStatus() == "fullAccess" else {
      send(ErrorMessage(message: "calendars are not allowed yet"))
      statusMayHaveChanged(force: false)
      return
    }
    watchChanges()
    do {
      let calendars = try reader.calendars()
      send(CalendarsMessage(items: calendars))
      let ids: [String]?
      switch selection {
      case .all: ids = nil
      case .only: ids = calendars.map(\.id).filter(selection.includes)
      }
      let window = EventWindow.around(hooks.now(), calendar: hooks.localCalendar())
      let chunks = parts(try reader.occurrences(start: window.start, end: window.end, calendarIds: ids))
      for (index, chunk) in chunks.enumerated() {
        send(
          EventsSnapshotMessage(
            windowStart: window.firstDay, windowEnd: window.lastDay, part: index, last: index == chunks.count - 1,
            items: chunk))
      }
      windowFirstDay = window.firstDay
      if lastFullRead == nil { lastFullRead = hooks.now() }
    } catch {
      send(ErrorMessage(message: "could not read calendars (\(Self.describe(error)))"))
    }
  }

  /// `items` in consecutive parts of at most `partBytes` on the wire (an item larger than that goes alone).
  /// Always at least one part, so an empty snapshot still tells the host to remove what it holds.
  func parts<Item: Encodable>(_ items: [Item]) -> [[Item]] {
    let budget = max(partBytes - 4096, 1)  // room for the message's other fields
    var out: [[Item]] = []
    var current: [Item] = []
    var size = 0
    for item in items {
      let bytes = ((try? Wire.size(item)) ?? 0) + 1
      if !current.isEmpty && size + bytes > budget {
        out.append(current)
        current = []
        size = 0
      }
      current.append(item)
      size += bytes
    }
    out.append(current)
    return out
  }

  private func watchChanges() {
    guard !watching else { return }
    watching = true
    ignoreChangesUntil = hooks.now().addingTimeInterval(Self.startupGrace)
    let perform = hooks.perform
    reader.observeChanges { [weak self] kind in
      perform { self?.changeNoticed(kind) }
    }
  }

  // MARK: Status

  private func currentStatus() -> (contacts: String, calendars: String) {
    (reader.contactsStatus(), reader.calendarsStatus())
  }

  private func sendStatus() {
    let status = currentStatus()
    lastStatus = status
    send(StatusMessage(contacts: status.contacts, calendars: status.calendars))
  }

  /// Sends the status when it changed (or always, with `force`). A kind that has just been allowed and that
  /// the host already asked for is read straight away.
  private func statusMayHaveChanged(force: Bool) {
    let before = lastStatus
    let now = currentStatus()
    guard force || before == nil || before! != now else { return }
    lastStatus = now
    send(StatusMessage(contacts: now.contacts, calendars: now.calendars))
    guard let before else { return }
    if now.contacts == "authorized", before.contacts != "authorized", contactsSelection != nil { readContacts() }
    if now.calendars == "fullAccess", before.calendars != "fullAccess", calendarsSelection != nil { readCalendars() }
  }

  /// An error as a domain and a code. Never the error's text, which can quote a name.
  static func describe(_ error: Error) -> String {
    if case ReaderError.notAllowed(let kind) = error { return "\(kind.rawValue) not allowed" }
    let ns = error as NSError
    return "\(ns.domain) \(ns.code)"
  }
}
