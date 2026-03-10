extends Node
## Simple audio manager for music and sound effects.
## Autoloaded as "AudioManager".

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_music: String = ""

const MAX_SFX_CHANNELS := 4

# ─── Music Tracks ────────────────────────────────────────────────
const MUSIC_OVERWORLD := "res://assets/audio/music/The_Crimson_Vanguard.mp3"
const MUSIC_BATTLE := "res://assets/audio/music/Apex_of_Fury.mp3"


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	for i in range(MAX_SFX_CHANNELS):
		var sfx := AudioStreamPlayer.new()
		sfx.bus = "SFX"
		add_child(sfx)
		_sfx_players.append(sfx)

	# Listen for game state changes to swap music automatically
	GameManager.game_state_changed.connect(_on_game_state_changed)

	# Start overworld music on launch (deferred so the tree is ready)
	call_deferred("_start_overworld_music")


func _start_overworld_music() -> void:
	play_music(MUSIC_OVERWORLD)


func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	match new_state:
		GameManager.GameState.BATTLE:
			play_music(MUSIC_BATTLE, 0.3)
		GameManager.GameState.OVERWORLD:
			play_music(MUSIC_OVERWORLD, 0.8)


# ─── Music Playback ─────────────────────────────────────────────

func play_music(path: String, fade_in: float = 0.5) -> void:
	if path == _current_music and _music_player.playing:
		return

	_current_music = path

	var stream := _load_audio(path)
	if not stream:
		push_warning("Music file not found: %s" % path)
		return

	# Enable looping for music
	if stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

	# Stop any existing fade tween
	_music_player.stream = stream
	_music_player.volume_db = -80.0 if fade_in > 0 else 0.0
	_music_player.play()

	if fade_in > 0:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", 0.0, fade_in)


func stop_music(fade_out: float = 0.5) -> void:
	if fade_out > 0:
		var tween := create_tween()
		tween.tween_property(_music_player, "volume_db", -80.0, fade_out)
		tween.tween_callback(_music_player.stop)
	else:
		_music_player.stop()
	_current_music = ""


# ─── SFX Playback ───────────────────────────────────────────────

func play_sfx(path: String) -> void:
	var stream := _load_audio(path)
	if not stream:
		return

	# Find a free channel
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return

	# All channels busy — use the first one
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


# ─── Audio Loading ──────────────────────────────────────────────

func _load_audio(path: String) -> AudioStream:
	## Load an audio file. Supports both imported resources and runtime-loaded
	## mp3/ogg/wav files that haven't been through Godot's import system.

	# Try the standard resource loader first (for imported assets)
	if ResourceLoader.exists(path):
		return load(path) as AudioStream

	# Fall back to runtime loading for non-imported files
	var global_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(global_path) and not FileAccess.file_exists(path):
		return null

	var actual_path: String = global_path if FileAccess.file_exists(global_path) else path

	if path.ends_with(".mp3"):
		return _load_mp3(actual_path)
	elif path.ends_with(".ogg"):
		return _load_ogg(actual_path)
	elif path.ends_with(".wav"):
		return _load_wav(actual_path)

	return null


func _load_mp3(file_path: String) -> AudioStreamMP3:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return null
	var stream := AudioStreamMP3.new()
	stream.data = file.get_buffer(file.get_length())
	return stream


func _load_ogg(file_path: String) -> AudioStreamOggVorbis:
	return AudioStreamOggVorbis.load_from_file(file_path)


func _load_wav(file_path: String) -> AudioStreamWAV:
	# Basic WAV loading — for simple cases
	if ResourceLoader.exists(file_path):
		return load(file_path) as AudioStreamWAV
	return null
