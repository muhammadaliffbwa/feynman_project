// lib/services/playlist_fetcher_io.dart

import 'dart:convert';
import 'dart:io';

Future<String> fetchUrlText(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FormatException(
        'Playlist server returned HTTP ${response.statusCode}.',
      );
    }
    return await response.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}