import 'dart:async';

import 'package:flutter/services.dart';

import 'links.dart';

/// Links that macOS opened with this app (`mycontacts://contact/<id>`, `mycalendar://day/<date>`,
/// `mydata://settings/sources`), as typed [MyDataLink]s.
///
/// The app's runner forwards them on the `mydata/links` channel; copy
/// `packages/mydata_core/macos_snippets/LinksAppDelegate.swift` into the runner (its header says how). The
/// runner holds links that arrive before Dart is listening (the link that started the app) and hands them
/// over when [start] says it is ready, so the first link is not lost.
///
/// Anything that is not a valid myData link for [app] is ignored. [links] is a single-subscription stream:
/// links that arrive before it is listened to are kept until it is.
class IncomingLinks {
  IncomingLinks({required this.app, MethodChannel? channel}) : channel = channel ?? defaultChannel;

  static const defaultChannel = MethodChannel('mydata/links');

  /// The app this is: only its own links are passed on.
  final MyDataAppId app;
  final MethodChannel channel;

  final _links = StreamController<MyDataLink>();
  bool _started = false;

  /// The links, in the order they arrived.
  Stream<MyDataLink> get links => _links.stream;

  /// Listen on the channel and collect the links the runner held. Safe to call on any platform: without
  /// the runner code (other platforms, older builds) no link ever arrives.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    channel.setMethodCallHandler(_onCall);
    try {
      final held = await channel.invokeMethod<List<Object?>>('ready');
      for (final raw in held ?? const <Object?>[]) {
        _accept(raw);
      }
    } on MissingPluginException {
      // No runner code: nothing to receive.
    } on PlatformException {
      // A runner that cannot answer has nothing to hand over.
    }
  }

  Future<Object?> _onCall(MethodCall call) async {
    if (call.method == 'open') _accept(call.arguments);
    return null;
  }

  void _accept(Object? raw) {
    if (raw is! String || _links.isClosed) return;
    final link = MyDataLink.parse(raw);
    if (link == null || link.app != app) return;
    _links.add(link);
  }

  void dispose() {
    if (_started) channel.setMethodCallHandler(null);
    unawaited(_links.close());
  }
}
