import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'generated/tokens.g.dart';
import 'theme/catalogue.dart';

/// The bundled fonts and icon sets and their licence files, in assets/fonts: SIL Open Font License 1.1 for
/// every font of the catalogue this build bundles, and ISC (with MIT for the icons Lucide takes from Feather)
/// for Lucide.
final Map<String, String> bundledFontLicenses = {
  for (final f in fontCatalogue.values)
    if (f.bundled) f.name: f.licence,
  MyDataMacFont.icons: 'ISC-lucide.txt',
};

/// Adds the fonts' licences to Flutter's licence registry, so they appear wherever the app lists licences.
/// Call once at startup.
void registerMyDataLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final e in bundledFontLicenses.entries) {
      final text = await rootBundle.loadString('packages/mydata_ui/assets/fonts/${e.value}');
      yield LicenseEntryWithLineBreaks([e.key], text);
    }
  });
}
