import 'location_types.dart';
import 'local_location_stub.dart'
    if (dart.library.js_interop) 'local_location_web.dart' as platform;

export 'location_types.dart';

/// Requests a single fix only after an explicit user action.
Future<DeviceLocation> requestDeviceLocation() =>
    platform.requestDeviceLocation();
