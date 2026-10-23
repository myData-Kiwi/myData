import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:mydata_ui/mydata_ui.dart';

import 'links.dart';
import 'theme_controller.dart';

/// Opens the theme gallery for [app] with its [themes] (View > Theme… in every app; Change… in myData's
/// Appearance), wired as design/themes/ARCHITECTURE.md 4.4 says:
///
/// - the window previews the selection while the gallery shows this app ([ThemeController.preview]);
/// - Return or "Use in [app]" stores it as that app's own ([ThemeController.use]);
/// - Use everywhere stores it for every app and offers Undo ([ThemeController.useEverywhere] and
///   [ThemeController.restore]); phones have one theme per app and no Use everywhere until native phone
///   apps;
/// - [choosingFor] (myData's gallery) adds an app switcher with every app, starting on [initialApp], so a
///   theme can be judged on another app's scene before it is used there.
Future<void> showThemeGalleryFor(
  BuildContext context,
  ThemeController themes, {
  required MyDataAppId app,
  List<MyDataAppId>? choosingFor,
  MyDataAppId? initialApp,
  bool? phone,
}) {
  final onPhone = phone ?? _isPhone;
  final apps = choosingFor ?? [app];
  return showThemeGallery(
    context: context,
    apps: [
      for (final a in apps)
        ThemeGalleryApp(
          id: a.name,
          name: a.displayName,
          scene: ThemePreviewScenes.forApp(a.name),
          current: themes.settings.choiceFor(a.name),
        ),
    ],
    initialApp: (initialApp ?? app).name,
    windowApp: app.name,
    onPreview: themes.preview,
    onUse: (id, choice) => themes.use(choice, app: id),
    onUseEverywhere: onPhone
        ? null
        : (choice) async {
            final before = await themes.useEverywhere(choice);
            return () => themes.restore(before);
          },
  );
}

bool get _isPhone => switch (defaultTargetPlatform) {
  TargetPlatform.iOS || TargetPlatform.android => true,
  _ => false,
};

/// Puts an app's [ThemeController] where its screens can reach it ([showAppThemeGallery]): above the app's
/// MaterialApp, so View > Theme… and a phone's More actions open the gallery from anywhere below.
class ThemeScope extends InheritedWidget {
  const ThemeScope({super.key, required this.themes, required this.app, required super.child});

  final ThemeController themes;

  /// The app whose window this is.
  final MyDataAppId app;

  static ThemeScope? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<ThemeScope>();

  @override
  bool updateShouldNotify(ThemeScope oldWidget) => oldWidget.themes != themes || oldWidget.app != app;
}

/// Opens the gallery for the app above [context] ([ThemeScope]), as [showThemeGalleryFor] does. Nothing
/// happens without a scope (a screen tested on its own).
Future<void> showAppThemeGallery(BuildContext context, {List<MyDataAppId>? choosingFor, MyDataAppId? initialApp}) {
  final scope = ThemeScope.maybeOf(context);
  if (scope == null) return Future.value();
  return showThemeGalleryFor(context, scope.themes, app: scope.app, choosingFor: choosingFor, initialApp: initialApp);
}
