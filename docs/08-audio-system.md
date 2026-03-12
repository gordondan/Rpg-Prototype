# Audio System

The audio system handles background music with crossfading and up to 4 concurrent sound effects.

## Key File

`scripts/autoload/audio_manager.gd` — Autoloaded as `AudioManager`.

## Architecture

```
AudioManager (Node)
├── _music_player (AudioStreamPlayer)  — Single music track, "Music" bus
├── _sfx_players[0] (AudioStreamPlayer) — SFX channel 1, "SFX" bus
├── _sfx_players[1] (AudioStreamPlayer) — SFX channel 2
├── _sfx_players[2] (AudioStreamPlayer) — SFX channel 3
└── _sfx_players[3] (AudioStreamPlayer) — SFX channel 4
```

## Music

Two tracks are defined:

| Constant | File | Used During |
|---|---|---|
| `MUSIC_OVERWORLD` | `assets/audio/music/The_Crimson_Vanguard.mp3` | Overworld exploration |
| `MUSIC_BATTLE` | `assets/audio/music/Apex_of_Fury.mp3` | Battle encounters |

### Automatic Switching

`AudioManager` listens to `GameManager.game_state_changed`:

- `BATTLE` → Switch to battle music (0.3s fade-in)
- `OVERWORLD` → Switch to overworld music (0.8s fade-in)

### Playback API

- `play_music(path, fade_in=0.5)` — Loads and plays music with fade-in. Skips if already playing the same track. All music loops.
- `stop_music(fade_out=0.5)` — Fades out and stops.

## Sound Effects

- `play_sfx(path)` — Plays a sound effect on the first available channel. If all 4 channels are busy, reuses channel 0.

## Runtime Audio Loading

Audio files don't need to go through Godot's import system. The loader tries:

1. `ResourceLoader` (for imported assets)
2. Direct file loading (for non-imported files):
   - `.mp3` → `AudioStreamMP3` (raw byte loading)
   - `.ogg` → `AudioStreamOggVorbis.load_from_file()`
   - `.wav` → `AudioStreamWAV` (resource loader fallback)
