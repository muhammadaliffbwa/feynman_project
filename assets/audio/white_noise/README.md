# White noise assets

These four MP3s are **synthetic placeholders** — generated with numpy/scipy
(filtered noise, no sample libraries), not recordings. They're seamless
30-second loops, so they're good enough to wire up and test the feature
end-to-end, but they're a rough approximation, especially `cafe_ambience`.

| File                | What it is                                              |
|----------------------|----------------------------------------------------------|
| `white_noise.mp3`   | Soft-filtered broadband noise                             |
| `rain.mp3`          | Band-passed noise + random droplet transients + gusts     |
| `ocean_waves.mp3`   | Low-passed noise shaped by a slow multi-sine swell envelope |
| `cafe_ambience.mp3` | Band-passed murmur bed + a couple of soft clinks          |

## Swapping in real recordings

Grab royalty-free loops from somewhere like [Freesound](https://freesound.org)
or [Pixabay Audio](https://pixabay.com/sound-effects/) and replace the file —
**keep the same filename** and the Dart code (`music_player_service.dart`)
needs no changes. Aim for a track that already loops cleanly, or fade the
last ~1s into the first ~1s yourself so the seam isn't audible under
`LoopMode.one`.
