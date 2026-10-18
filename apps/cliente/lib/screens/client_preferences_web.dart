import 'dart:js_interop';

const _key = 'gogdely-client-preferences-v1';

@JS('localStorage')
external _BrowserStorage get _storage;

extension type _BrowserStorage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
}

String? readClientPreferences() {
  try {
    return _storage.getItem(_key.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

bool writeClientPreferences(String value) {
  try {
    _storage.setItem(_key.toJS, value.toJS);
    return true;
  } catch (_) {
    return false;
  }
}
