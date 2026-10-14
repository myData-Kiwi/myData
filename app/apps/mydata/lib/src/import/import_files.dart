import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

import 'import_text.dart';

/// A file the user dropped or chose, read only when it is sent: its bytes go to the host as they are, its
/// name only as a label (plan 3.5; design/components/DropZone, "For implementers").
abstract class PickedFile {
  /// The file's name, without its folder.
  String get name;

  /// A folder dropped on the zone (never opened).
  bool get isDirectory;

  /// Its size in bytes.
  Future<int> size();

  /// Its bytes.
  Future<Uint8List> read();
}

/// An [XFile] from the system's chooser or a drop.
class XPickedFile implements PickedFile {
  XPickedFile(this.file, {this.isDirectory = false});
  final XFile file;

  @override
  final bool isDirectory;

  @override
  String get name => file.name;

  @override
  Future<int> size() => file.length();

  @override
  Future<Uint8List> read() => file.readAsBytes();
}

/// A file held in memory (tests, and a retry of a file already read).
class MemoryFile implements PickedFile {
  MemoryFile(this.name, this.bytes, {this.isDirectory = false});

  @override
  final String name;
  final Uint8List bytes;

  @override
  final bool isDirectory;

  @override
  Future<int> size() async => bytes.length;

  @override
  Future<Uint8List> read() async => bytes;
}

/// Opens the system's own file chooser (design/platforms.md: "Dialogs for files … the system's own"),
/// filtered to the types the Import section takes. Null when the user cancelled.
typedef FileChooser = Future<PickedFile?> Function();

/// The system's chooser through file_selector: one `.vcf` or `.zip`.
Future<PickedFile?> chooseContactsFile() async {
  const group = XTypeGroup(
    label: 'vCard or zip',
    extensions: ['vcf', 'vcard', 'zip'],
    uniformTypeIdentifiers: ['public.vcard', 'public.zip-archive'],
  );
  final file = await openFile(acceptedTypeGroups: const [group]);
  return file == null ? null : XPickedFile(file);
}

/// What the Import section checks before sending anything (design/components/DropZone, "Checked before
/// sending, by extension"): the error sentence, or null when the file can go to the host.
abstract final class ImportFileCheck {
  /// The host's cap: 50 MB uploaded (`MAX_INPUT`, 50 MiB).
  static const maxBytes = 50 * 1024 * 1024;

  /// Several files dropped at once, or one that is a folder, not a vCard or a zip, or too large.
  static String? check(List<PickedFile> files, {Map<PickedFile, int> sizes = const {}}) {
    if (files.length > 1) return ImportText.severalFiles;
    if (files.isEmpty) return null;
    final f = files.single;
    if (f.isDirectory) return ImportText.folder(f.name);
    final ext = extensionOf(f.name);
    if (ext == 'ics' || ext == 'ical' || ext == 'ifb') return ImportText.calendar(f.name);
    if (ext == 'csv') return ImportText.csv(f.name);
    if (ext != 'vcf' && ext != 'vcard' && ext != 'zip') return ImportText.notVcard(f.name);
    final size = sizes[f];
    if (size != null && size > maxBytes) return ImportText.tooBig(f.name, size);
    return null;
  }

  /// "vcf" for "Contacts.VCF"; empty without one.
  static String extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 || dot == name.length - 1 ? '' : name.substring(dot + 1).toLowerCase();
  }
}
