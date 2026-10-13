import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'backend.dart';

/// Photo bytes the host sent, shared by the list's small avatar and the page's large one so a photo is
/// fetched once. The oldest are forgotten past [capacity].
class PhotoCache {
  PhotoCache(this.backend, {this.capacity = 200});

  final ContactsBackend backend;
  final int capacity;
  final _bytes = <String, Future<Uint8List?>>{}; // in insertion order: the oldest first

  /// The photo of contact [id] as it was at [modifiedAt]; a changed card is fetched again.
  Future<Uint8List?> get(String id, String modifiedAt) {
    final key = '$id@$modifiedAt';
    final found = _bytes.remove(key);
    if (found != null) return _bytes[key] = found;
    final fetched = backend.photo(id);
    _bytes[key] = fetched;
    // A failed fetch is forgotten, so showing the contact again tries again.
    fetched.then<void>(
      (b) {
        if (b == null) _bytes.remove(key);
      },
      onError: (Object _) {
        _bytes.remove(key);
      },
    );
    while (_bytes.length > capacity) {
      _bytes.remove(_bytes.keys.first);
    }
    return fetched;
  }

  void clear() => _bytes.clear();
}

/// A contact's photo from the host (`GET /contacts/{id}/photo`), for an [Avatar]. Pass it only when the
/// contact has one (`has_photo`): nothing is fetched otherwise, and the list fetches only the rows it shows.
/// When the photo cannot be read the avatar keeps the initials.
@immutable
class HostPhoto extends ImageProvider<HostPhoto> {
  const HostPhoto(this.cache, this.id, this.modifiedAt);

  final PhotoCache cache;
  final String id;

  /// The card's last change, so a new photo is not hidden by the image cache.
  final String modifiedAt;

  @override
  Future<HostPhoto> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(HostPhoto key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1, debugLabel: 'contact photo');

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final bytes = await cache.get(id, modifiedAt);
    if (bytes == null) throw StateError('no photo');
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) =>
      other is HostPhoto && identical(other.cache, cache) && other.id == id && other.modifiedAt == modifiedAt;

  @override
  int get hashCode => Object.hash(identityHashCode(cache), id, modifiedAt);
}
