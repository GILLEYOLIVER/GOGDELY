import 'dart:async';
import 'dart:js_interop';

import 'location_types.dart';

@JS('navigator')
external _BrowserNavigator get _navigator;

extension type _BrowserNavigator(JSObject _) implements JSObject {
  external _BrowserGeolocation? get geolocation;
}

extension type _BrowserGeolocation(JSObject _) implements JSObject {
  external void getCurrentPosition(JSFunction onSuccess, JSFunction onError);
}

extension type _BrowserPosition(JSObject _) implements JSObject {
  external _BrowserCoordinates get coords;
}

extension type _BrowserCoordinates(JSObject _) implements JSObject {
  external double get latitude;
  external double get longitude;
  external double get accuracy;
}

extension type _BrowserPositionError(JSObject _) implements JSObject {
  external int get code;
}

Future<DeviceLocation> requestDeviceLocation() async {
  final geolocation = _navigator.geolocation;
  if (geolocation == null) {
    throw StateError('Localização indisponível neste navegador ou conexão.');
  }
  final completer = Completer<DeviceLocation>();
  geolocation.getCurrentPosition(
    ((_BrowserPosition position) {
      if (completer.isCompleted) return;
      final coords = position.coords;
      completer.complete(DeviceLocation(coords.latitude, coords.longitude,
          accuracyMeters: coords.accuracy));
    }).toJS,
    ((_BrowserPositionError error) {
      if (completer.isCompleted) return;
      completer.completeError(StateError(switch (error.code) {
        1 =>
          'Permissão de localização negada. Ative-a no navegador para usar este recurso.',
        2 => 'O aparelho não conseguiu determinar sua localização.',
        _ => 'A localização demorou demais. Tente novamente.',
      }));
    }).toJS,
  );
  return completer.future.timeout(const Duration(seconds: 20),
      onTimeout: () =>
          throw StateError('A localização demorou demais. Tente novamente.'));
}
