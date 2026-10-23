import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'generated/tokens.g.dart';

/// The bundled fonts and their licence files, in assets/fonts: SIL Open Font License 1.1, and ISC (with MIT for
/// the icons Lucide takes from Feather) for the Mac frame's icons.
const bundledFontLicenses = {
  MyDataFontFamily.displayName: 'OFL-plusjakartasans.txt',
  MyDataFontFamily.bodyName: 'OFL-figtree.txt',
  MyDataFontFamily.monoName: 'OFL-jetbrainsmono.txt',
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
