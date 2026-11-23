// lib/services/playlist_fetcher_web.dart

import 'dart:js_interop';

@JS('fetch')
external JSPromise<_JSResponse> _fetch(JSString url);

extension type _JSResponse(JSObject _) implements JSObject {
  external bool get ok;
  external int get status;
  external JSPromise<JSString> text();
}

Future<String> fetchUrlText(Uri uri) async {
  try {
    final response = await _fetch(uri.toString().toJS).toDart;
    if (!response.ok) {
      throw FormatException(
        'Playlist server returned HTTP ${response.status}.',
      );
    }
    final jsText = await response.text().toDart;
    return jsText.toDart;
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'Browser blocked reading this .m3u/.pls file (CORS restriction). '
      'Open the .m3u link in a browser tab or text editor and paste the direct stream URL listed inside it.',
    );
  }
}