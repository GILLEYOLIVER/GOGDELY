import 'dart:js_interop';

@JS('gogdelyPlayHorn')
external void _playHorn();

void playIntroHorn() => _playHorn();
