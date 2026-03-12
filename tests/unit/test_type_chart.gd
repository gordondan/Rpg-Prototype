extends GutTest
## Unit tests for TypeChart — verifies type effectiveness lookups.


func test_super_effective():
	assert_eq(TypeChart.get_effectiveness("fire", ["grass"]), 2.0,
		"Fire vs Grass should be super effective")


func test_not_very_effective():
	assert_eq(TypeChart.get_effectiveness("fire", ["water"]), 0.5,
		"Fire vs Water should be not very effective")


func test_immune():
	assert_eq(TypeChart.get_effectiveness("normal", ["ghost"]), 0.0,
		"Normal vs Ghost should have no effect")


func test_neutral():
	# Fire vs fighting — fighting not in fire's chart → 1.0
	assert_eq(TypeChart.get_effectiveness("fire", ["fighting"]), 1.0,
		"Fire vs Fighting should be neutral")


func test_dual_type_compounds():
	# Fire vs Grass/Bug: fire→grass = 2.0, fire→bug = 2.0 → 4.0
	assert_eq(TypeChart.get_effectiveness("fire", ["grass", "bug"]), 4.0,
		"Fire vs Grass/Bug should compound to 4x")


func test_dual_type_mixed():
	# Fire vs Grass/Water: fire→grass = 2.0, fire→water = 0.5 → 1.0
	assert_eq(TypeChart.get_effectiveness("fire", ["grass", "water"]), 1.0,
		"Fire vs Grass/Water should cancel to 1x")


func test_dual_type_with_immunity():
	# Normal vs Ghost/Fighting: normal→ghost = 0.0 → 0.0 regardless
	assert_eq(TypeChart.get_effectiveness("normal", ["ghost", "fighting"]), 0.0,
		"Immunity zeroes out even with super effective second type")


func test_unknown_attack_type_is_neutral():
	assert_eq(TypeChart.get_effectiveness("banana", ["fire"]), 1.0,
		"Unknown attack type should be neutral")


func test_effectiveness_text_super():
	assert_eq(TypeChart.get_effectiveness_text(2.0), "It's super effective!")


func test_effectiveness_text_not_very():
	assert_eq(TypeChart.get_effectiveness_text(0.5), "It's not very effective...")


func test_effectiveness_text_immune():
	assert_eq(TypeChart.get_effectiveness_text(0.0), "It doesn't affect the target...")


func test_effectiveness_text_neutral():
	assert_eq(TypeChart.get_effectiveness_text(1.0), "",
		"Neutral should return empty string")


func test_effectiveness_text_4x():
	assert_eq(TypeChart.get_effectiveness_text(4.0), "It's super effective!",
		"4x should still say super effective")
