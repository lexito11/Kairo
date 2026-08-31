import 'dart:js_interop';
import 'package:web/web.dart';

bool get isBrowserFullscreen => document.fullscreenElement != null;

Future<void> toggleBrowserFullscreen() async {
  if (isBrowserFullscreen) {
    await document.exitFullscreen().toDart;
    return;
  }
  final el = document.documentElement;
  if (el != null) {
    await el.requestFullscreen().toDart;
  }
}

void listenBrowserFullscreen(void Function() onChange) {
  document.addEventListener(
    'fullscreenchange',
    (Event _) {
      onChange();
    }.toJS,
  );
}
