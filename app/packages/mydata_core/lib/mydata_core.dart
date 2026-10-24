/// Shared app logic for the myData apps: finding, starting and watching the host, reading this
/// app's token, the error states every app shows, links between the apps, and settings that belong to
/// this device (mode, hidden calendars).
library;

export 'package:mydata_client/api.dart';

export 'src/availability.dart';
export 'src/host_controller.dart';
export 'src/host_version.g.dart';
export 'src/theme_controller.dart';
export 'src/theme_gallery_launcher.dart';
export 'src/theme_moved_notice.dart';
export 'src/calendar_visibility.dart';
export 'src/contact_pair.dart';
export 'src/incoming_links.dart';
export 'src/installed_apps.dart';
export 'src/links.dart';
export 'src/platform.dart'
    show
        CommandResult,
        CommandRunner,
        DeviceStore,
        DeviceStoreUnreadable,
        HostEnvironment,
        HostExit,
        HostPlatform,
        LaunchResult,
        MacSystem,
        MemoryDeviceStore,
        PrivacyPane,
        deviceStore,
        hostCommandsFrom,
        hostPlatform,
        macSystem,
        replaceHostArguments;
