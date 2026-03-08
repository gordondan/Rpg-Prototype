extends Node
## Simple audio manager for music and sound effects.
## Autoloaded as "AudioManager".

var _music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_music: String = ""

const MAX_SFX_CHANNELS := 4


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

	for i in range(MAX_SFX_CHANNELS):
		var sfx := AudioStreamPlayer.new()
		sfx.bus = "SFX"
		add_child(sfx)
		_sfx_players.append(sfx)


func play_music(path: String, fade_in: float = 0.5) -> void:
	if path == _current_music and _music_player.playing:
		return

	_current_music = path

	if not ResourceLoader.exists(path):
		push_warning("Music file not found: %s" % path)
		return

	var stream := load(path) as AudioStream
	if stream:
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


func play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return

	var stream := load(path) as AudioStream

	# Find a free channel
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.play()
			return

	# All channels busy — use the first one
	_sfx_players[0].stream = stream
	_sfx_players[0].play()
