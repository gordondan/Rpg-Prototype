extends RefCounted
class_name TestHelpers
## Shared utilities for tests. Provides factory methods and common setup.


static func make_creature(overrides: Dictionary = {}) -> CreatureInstance:
	## Create a CreatureInstance with known, simple stats for testing.
	## Override any property by passing it in the overrides dict.
	var c := CreatureInstance.new()
	c.creature_id = overrides.get("creature_id", "test_creature")
	c.nickname = overrides.get("nickname", "Test Creature")
	c.level = overrides.get("level", 10)
	c.experience = overrides.get("experience", 0)

	c.base_hp = overrides.get("base_hp", 50)
	c.base_attack = overrides.get("base_attack", 50)
	c.base_defense = overrides.get("base_defense", 50)
	c.base_sp_attack = overrides.get("base_sp_attack", 50)
	c.base_sp_defense = overrides.get("base_sp_defense", 50)
	c.base_speed = overrides.get("base_speed", 50)

	var raw_types: Array = overrides.get("types", ["normal"])
	c.types.clear()
	for t in raw_types:
		c.types.append(String(t))

	# Calculate stats from base stats and level
	c.max_hp = overrides.get("max_hp", int(((2.0 * c.base_hp + 31.0) * c.level / 100.0) + c.level + 10))
	c.attack = overrides.get("attack", int(((2.0 * c.base_attack + 31.0) * c.level / 100.0) + 5))
	c.defense = overrides.get("defense", int(((2.0 * c.base_defense + 31.0) * c.level / 100.0) + 5))
	c.sp_attack = overrides.get("sp_attack", int(((2.0 * c.base_sp_attack + 31.0) * c.level / 100.0) + 5))
	c.sp_defense = overrides.get("sp_defense", int(((2.0 * c.base_sp_defense + 31.0) * c.level / 100.0) + 5))
	c.speed = overrides.get("speed", int(((2.0 * c.base_speed + 31.0) * c.level / 100.0) + 5))

	c.current_hp = overrides.get("current_hp", c.max_hp)

	var raw_moves: Array = overrides.get("moves", [])
	c.moves.clear()
	for m in raw_moves:
		c.moves.append(m)

	return c


static func make_move(overrides: Dictionary = {}) -> Dictionary:
	## Create a move dictionary with known values for testing.
	return {
		"name": overrides.get("name", "Test Move"),
		"type": overrides.get("type", "normal"),
		"category": overrides.get("category", "physical"),
		"power": overrides.get("power", 50),
		"accuracy": overrides.get("accuracy", 100),
		"pp": overrides.get("pp", 20),
	}.merged(overrides)


static func reset_game_manager() -> void:
	## Reset GameManager to a clean state between tests.
	GameManager.player_party.clear()
	GameManager.story_flags.clear()
	GameManager.inventory.clear()
	GameManager.gold = 500
	GameManager.player_name = "Captain"
	GameManager.guild_ranks.clear()
	GameManager.current_state = GameManager.GameState.OVERWORLD
