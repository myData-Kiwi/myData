import 'dart:async';

import 'package:flutter/widgets.dart';

import 'links.dart';

/// Which of some myData apps are installed on this Mac, for a screen that opens them (myAssistant's
/// results, the myData app's Status).
///
/// [start] asks once ([AppLinks.isInstalled] for each app, together) and again whenever this app comes back
/// to the front (its lifecycle resumes), so an app installed or removed meanwhile is noticed without a
/// restart. Never on every build: a lookup takes about 50 ms. Until the first answer, and off macOS, no app
/// counts as installed, so nothing offers to open an app that may not be there.
class InstalledApps extends ChangeNotifier {
  InstalledApps({required Iterable<MyDataAppId> apps, AppLinks? links}) : apps = Set.unmodifiable(apps), _given = links;

  /// The apps asked about.
  final Set<MyDataAppId> apps;

  /// Null uses the shared [appLinks] at the time of each lookup.
  final AppLinks? _given;

  Set<MyDataAppId> _installed = const {};
  bool _checked = false;
  int _generation = 0;
  AppLifecycleListener? _lifecycle;
  bool _disposed = false;

  AppLinks get links => _given ?? appLinks;

  /// The apps of [apps] found installed at the last lookup.
  Set<MyDataAppId> get installed => _installed;

  /// Whether a lookup has answered at least once.
  bool get checked => _checked;

  bool isInstalled(MyDataAppId app) => _installed.contains(app);

  /// Looks once now, and again each time this app is brought back to the front.
  Future<void> start() {
    _lifecycle ??= AppLifecycleListener(onResume: () => unawaited(refresh()));
    return refresh();
  }

  /// Looks again. When lookups overlap, the last one started decides.
  Future<void> refresh() async {
    final generation = ++_generation;
    final order = apps.toList();
    final answers = await Future.wait(order.map(links.isInstalled));
    if (_disposed || generation != _generation) return;
    final found = {
      for (var i = 0; i < order.length; i++)
        if (answers[i]) order[i],
    };
    final changed = !_checked || found.length != _installed.length || !found.containsAll(_installed);
    _installed = Set.unmodifiable(found);
    _checked = true;
    if (changed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _lifecycle?.dispose();
    super.dispose();
  }
}
