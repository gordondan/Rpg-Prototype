extends GutTest
## Component tests for GameManager — state, party, flags, save/load.


func before_each():
	TestHelpers.reset_game_manager()


func test_initial_state_is_overworld():
	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD)


func test_set_state_changes_state():
	GameManager.set_state(GameManager.GameState.BATTLE)
	assert_eq(GameManager.current_state, GameManager.GameState.BATTLE)


func test_set_state_emits_signal():
	watch_signals(GameManager)
	GameManager.set_state(GameManager.GameState.BATTLE)
	assert_signal_emitted(GameManager, "game_state_changed")


func test_is_player_free_only_in_overworld():
	GameManager.set_state(GameManager.GameState.OVERWORLD)
	assert_true(GameManager.is_player_free())

	GameManager.set_state(GameManager.GameState.BATTLE)
	assert_false(GameManager.is_player_free())

	GameManager.set_state(GameManager.GameState.DIALOGUE)
	assert_false(GameManager.is_player_free())

	GameManager.set_state(GameManager.GameState.MENU)
	assert_false(GameManager.is_player_free())


func test_add_creature_to_party():
	var c := TestHelpers.make_creature()
	var added := GameManager.add_creature_to_party(c)
	assert_true(added)
	assert_eq(GameManager.player_party.size(), 1)


func test_party_max_6():
	for i in range(6):
		GameManager.add_creature_to_party(TestHelpers.make_creature())
	assert_eq(GameManager.player_party.size(), 6)

	var added := GameManager.add_creature_to_party(TestHelpers.make_creature())
	assert_false(added, "Should not add 7th creature")
	assert_eq(GameManager.player_party.size(), 6)


func test_get_first_alive_creature():
	var c1 := TestHelpers.make_creature({"nickname": "First", "current_hp": 0})
	var c2 := TestHelpers.make_creature({"nickname": "Second", "current_hp": 10})
	GameManager.add_creature_to_party(c1)
	GameManager.add_creature_to_party(c2)
	var alive := GameManager.get_first_alive_creature()
	assert_eq(alive.nickname, "Second")


func test_get_first_alive_returns_null_when_wiped():
	var c := TestHelpers.make_creature({"current_hp": 0})
	GameManager.add_creature_to_party(c)
	assert_null(GameManager.get_first_alive_creature())


func test_is_party_wiped():
	var c1 := TestHelpers.make_creature({"current_hp": 0})
	var c2 := TestHelpers.make_creature({"current_hp": 0})
	GameManager.add_creature_to_party(c1)
	GameManager.add_creature_to_party(c2)
	assert_true(GameManager.is_party_wiped())


func test_is_party_not_wiped():
	var c1 := TestHelpers.make_creature({"current_hp": 0})
	var c2 := TestHelpers.make_creature({"current_hp": 1})
	GameManager.add_creature_to_party(c1)
	GameManager.add_creature_to_party(c2)
	assert_false(GameManager.is_party_wiped())


func test_heal_all_party():
	var c1 := TestHelpers.make_creature({"max_hp": 50, "current_hp": 10})
	c1.status_effect = "poison"
	var c2 := TestHelpers.make_creature({"max_hp": 50, "current_hp": 25})
	GameManager.add_creature_to_party(c1)
	GameManager.add_creature_to_party(c2)
	GameManager.heal_all_party()
	assert_eq(c1.current_hp, 50)
	assert_eq(c1.status_effect, "")
	assert_eq(c2.current_hp, 50)


func test_story_flags():
	assert_false(GameManager.get_flag("test_flag"))
	GameManager.set_flag("test_flag", true)
	assert_true(GameManager.get_flag("test_flag"))
	GameManager.set_flag("test_flag", false)
	assert_false(GameManager.get_flag("test_flag"))


func test_transition_to_battle_sets_state():
	GameManager.transition_to_battle(Vector2(100, 200), "test_map")
	assert_eq(GameManager.current_state, GameManager.GameState.BATTLE)


func test_return_from_battle_restores_overworld():
	GameManager.set_state(GameManager.GameState.BATTLE)
	GameManager.return_from_battle()
	assert_eq(GameManager.current_state, GameManager.GameState.OVERWORLD)


func test_save_load_roundtrip():
	GameManager.player_name = "TestHero"
	GameManager.gold = 1234
	GameManager.set_flag("test_flag_roundtrip", true)
	var c := CreatureInstance.create("flame_squire", 7)
	c.nickname = "Testy"
	c.current_hp = 15
	GameManager.add_creature_to_party(c)

	GameManager.save_game(99)
	TestHelpers.reset_game_manager()

	var loaded := GameManager.load_game(99)
	assert_true(loaded, "Should load successfully")
	assert_eq(GameManager.player_name, "TestHero")
	assert_eq(GameManager.gold, 1234)
	assert_true(GameManager.get_flag("test_flag_roundtrip"))
	assert_eq(GameManager.player_party.size(), 1)
	assert_eq(GameManager.player_party[0].nickname, "Testy")
	assert_eq(GameManager.player_party[0].level, 7)
	assert_eq(GameManager.player_party[0].current_hp, 15)


func after_all():
	var path := "user://save_99.json"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	TestHelpers.reset_game_manager()
