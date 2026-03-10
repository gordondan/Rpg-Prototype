extends Area2D
## Encounter zone that triggers random hostile encounters when the player walks through.
## Can represent tall grass, dense forest, ruins, or any dangerous terrain.

@export var encounter_rate: float = 0.15  # 15% chance per step
@export var encounter_table_id: String = "route_1"  # References data/maps/*.json

var player_inside := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		# Connect to the player's movement signal
		if body.has_signal("player_moved"):
			if not body.player_moved.is_connected(_on_player_stepped):
				body.player_moved.connect(_on_player_stepped)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_inside = false
		if body.has_signal("player_moved") and body.player_moved.is_connected(_on_player_stepped):
			body.player_moved.disconnect(_on_player_stepped)


func _on_player_stepped(_new_position: Vector2) -> void:
	if not player_inside:
		return

	if randf() < encounter_rate:
		_trigger_encounter()


func _trigger_encounter() -> void:
	## Roll 1-3 random creatures from this area's encounter table and start a battle.
	# Determine enemy count: 50% chance of 1, 35% chance of 2, 15% chance of 3
	var count_roll := randf()
	var enemy_count: int
	if count_roll < 0.5:
		enemy_count = 1
	elif count_roll < 0.85:
		enemy_count = 2
	else:
		enemy_count = 3

	BattleManager.start_wild_battle(encounter_table_id, enemy_count)
