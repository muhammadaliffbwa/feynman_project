// lib/models/playlist.dart

class Playlist {
  final String id;
  final String name;
  final List<String> tracks;

  Playlist({
    String? id,
    required this.name,
    List<String>? tracks,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        tracks = tracks ?? [];

  Playlist copyWith({
    String? name,
    List<String>? tracks,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      tracks: tracks ?? List.from(this.tracks),
    );
  }

  void addTrack(String trackUrl) {
    if (!tracks.contains(trackUrl)) {
      tracks.add(trackUrl);
    }
  }

  void removeTrack(String trackUrl) {
    tracks.remove(trackUrl);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tracks': tracks,
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      tracks: List<String>.from(json['tracks'] as List? ?? []),
    );
  }
}