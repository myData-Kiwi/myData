// myData Reader: reads this Mac's Contacts and Calendars for the host. It lives inside the myData app
// (myData.app/Contents/Helpers/myDataReader.app), so macOS asks the user about "myData" and the permission
// belongs to the myData app.
//
// The host starts it through LaunchServices, never by running the binary itself (that would make the
// host's own process the one macOS asks about):
//   open -g -j -n -a <myDataReader.app> --args --socket <home>/run/reader.sock
// It connects to that socket and speaks the protocol in Protocol.swift until the socket closes.
//
//   open -W -n -a <myDataReader.app> --args status-only --out <file>
// writes the two permission statuses as one JSON line to <file> and exits. It never asks the user and never
// reads a contact or an event.

import AppKit
import Darwin
import Foundation

enum Mode {
  case serve(socket: String)
  case statusOnly(out: String?)
}

func parseArguments(_ args: [String]) -> Mode? {
  var socket: String?
  var out: String?
  var statusOnly = false
  var i = 1
  while i < args.count {
    switch args[i] {
    case "status-only":
      statusOnly = true
    case "--socket" where i + 1 < args.count:
      socket = args[i + 1]
      i += 1
    case "--out" where i + 1 < args.count:
      out = args[i + 1]
      i += 1
    default:
      break  // LaunchServices may add arguments of its own
    }
    i += 1
  }
  if statusOnly { return .statusOnly(out: out) }
  return socket.map { .serve(socket: $0) }
}

func fail(_ message: String, code: Int32) -> Never {
  FileHandle.standardError.write(Data(("myDataReader: " + message + "\n").utf8))
  exit(code)
}

// MARK: - status-only

func runStatusOnly(out: String?) -> Never {
  let reader = SystemPersonalDataReader()
  let message = StatusMessage(contacts: reader.contactsStatus(), calendars: reader.calendarsStatus())
  guard let line = try? Wire.line(message) else { fail("could not encode the status", code: 70) }
  if let out {
    guard FileManager.default.createFile(atPath: out, contents: line, attributes: [.posixPermissions: 0o600])
    else { fail("could not write the status file", code: 73) }
  } else {
    FileHandle.standardOutput.write(line)
  }
  exit(0)
}

// MARK: - The socket

/// A connected Unix socket that carries JSON lines. Writes are serialised; reads run on their own thread.
final class LineSocket {
  private let fd: Int32
  private let writeLock = NSLock()
  /// Commands are a few hundred bytes. Anything far longer is not from the host.
  private static let maxLine = 1 << 20

  init(connectingTo path: String) throws {
    try Self.checkSocketPath(path)
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    var on: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    let bytes = Array(path.utf8)
    let capacity = MemoryLayout.size(ofValue: address.sun_path)
    guard bytes.count < capacity else {
      close(fd)
      throw POSIXError(.ENAMETOOLONG)
    }
    withUnsafeMutableBytes(of: &address.sun_path) { buffer in
      buffer.copyBytes(from: bytes)
      buffer[bytes.count] = 0
    }
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    let connected = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    guard connected == 0 else {
      let code = errno
      close(fd)
      throw POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
    }
    // The other end must be this user's process.
    var uid: uid_t = 0
    var gid: gid_t = 0
    guard getpeereid(fd, &uid, &gid) == 0, uid == getuid() else {
      close(fd)
      throw POSIXError(.EPERM)
    }
    self.fd = fd
  }

  /// The socket must be this user's, in a folder only this user can write to (the host makes it 0700).
  private static func checkSocketPath(_ path: String) throws {
    var info = stat()
    guard lstat(path, &info) == 0, info.st_mode & S_IFMT == S_IFSOCK, info.st_uid == getuid() else {
      throw POSIXError(.EPERM)
    }
    let folder = (path as NSString).deletingLastPathComponent
    var folderInfo = stat()
    guard stat(folder, &folderInfo) == 0, folderInfo.st_uid == getuid(),
      folderInfo.st_mode & (S_IWGRP | S_IWOTH) == 0
    else { throw POSIXError(.EPERM) }
  }

  func send(_ message: Encodable) {
    guard let line = try? Wire.line(message) else {
      if !(message is ErrorMessage) { send(ErrorMessage(message: "could not encode a message")) }
      return
    }
    writeLock.lock()
    defer { writeLock.unlock() }
    line.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
      guard let base = raw.baseAddress else { return }
      var offset = 0
      while offset < raw.count {
        let n = Darwin.write(fd, base + offset, raw.count - offset)
        if n < 0 {
          if errno == EINTR { continue }
          exit(0)  // the host has gone
        }
        offset += n
      }
    }
  }

  /// Calls `onLine` for every line received, and `onClose` when the host closes the socket.
  func startReading(onLine: @escaping (String) -> Void, onClose: @escaping () -> Void) {
    let fd = self.fd
    let thread = Thread {
      var pending = Data()
      var chunk = [UInt8](repeating: 0, count: 64 * 1024)
      while true {
        let n = chunk.withUnsafeMutableBytes { read(fd, $0.baseAddress, $0.count) }
        if n < 0 && errno == EINTR { continue }
        if n <= 0 {
          onClose()
          return
        }
        pending.append(contentsOf: chunk[0..<n])
        while let newline = pending.firstIndex(of: 0x0A) {
          let line = pending.subdata(in: pending.startIndex..<newline)
          pending = pending.subdata(in: (newline + 1)..<pending.endIndex)
          onLine(String(decoding: line, as: UTF8.self))
        }
        if pending.count > Self.maxLine {
          pending = Data()
          onLine("")  // dropped; the session ignores empty lines
        }
      }
    }
    thread.name = "kiwi.mydata.reader.socket"
    thread.start()
  }
}

// MARK: - serve

func runServe(socketPath: String) -> Never {
  let connection: LineSocket
  do {
    connection = try LineSocket(connectingTo: socketPath)
  } catch {
    fail("could not connect to the host (\((error as NSError).code))", code: 69)
  }

  let work = DispatchQueue(label: "kiwi.mydata.reader.work")
  var pending: [DataKind: DispatchWorkItem] = [:]  // used on `work` only
  let hooks = SessionHooks(
    perform: { work.async(execute: $0) },
    debounce: { kind, run in
      pending[kind]?.cancel()
      let item = DispatchWorkItem(block: run)
      pending[kind] = item
      work.asyncAfter(deadline: .now() + ReaderSession.startupGrace, execute: item)
    },
    quit: { exit(0) })
  let session = ReaderSession(reader: SystemPersonalDataReader(), send: connection.send, hooks: hooks)

  work.async { session.start() }
  connection.startReading(
    onLine: { line in work.async { session.handle(line: line) } },
    onClose: { exit(0) })

  let timer = DispatchSource.makeTimerSource(queue: work)
  timer.schedule(deadline: .now() + 60, repeating: 60, leeway: .seconds(5))
  timer.setEventHandler { session.tick() }
  timer.resume()

  // A real application run loop, so that macOS can ask it to quit at log out like any other app.
  // LSUIElement keeps it out of the Dock and the app switcher.
  withExtendedLifetime((timer, connection)) {
    NSApplication.shared.run()
  }
  exit(0)
}

// MARK: - main

signal(SIGPIPE, SIG_IGN)
switch parseArguments(CommandLine.arguments) {
case .statusOnly(let out)?:
  runStatusOnly(out: out)
case .serve(let socket)?:
  runServe(socketPath: socket)
case nil:
  fail("usage: myDataReader --socket <path> | status-only [--out <file>]", code: 64)
}
