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
	## Roll a random creature from this area's encounter table and start a battle.
	var encounter_data = DataLoader.get_encounter_table(encounter_table_id)
	if encounter_data.is_empty():
		push_warning("No encounter table found for: %s" % encounter_table_id)
		return

	# Weighted random selection from encounter table
	var total_weight := 0.0
	for entry in encounter_data:
		total_weight += entry.get("weight", 1.0)

	var roll := randf() * total_weight
	var cumulative := 0.0

	for entry in encounter_data:
		cumulative += entry.get("weight", 1.0)
		if roll <= cumulative:
			var creature_id: String = entry["creature_id"]
			var level_min: int = entry.get("level_min", 2)
			var level_max: int = entry.get("level_max", 5)
			var level := randi_range(level_min, level_max)

			BattleManager.start_wild_battle(creature_id, level)
			return
