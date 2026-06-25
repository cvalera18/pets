## TestRunner.gd
## Lightweight, dependency-free test harness (no GUT). Run it as its own scene:
##   run_project(scene = "res://tests/TestRunner.tscn")
## It prints PASS/FAIL per assertion and a final tally to stdout, so a headless
## run can be checked from the captured output. Pure logic only — it never
## touches the real save file (SaveSystem._migrate operates on plain Dictionaries).
extends Node

const PetStatsScript := preload("res://resources/PetStats.gd")

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("=== PETS TEST SUITE ===")
	_test_petstats()
	_test_migrations()
	_test_achievements_persistence()
	_test_personality()
	print("=== RESULT: %d passed, %d failed ===" % [_passed, _failed])
	if _failed > 0:
		push_error("Test suite has %d failing assertion(s)." % _failed)


# ─── Assertion helpers ────────────────────────────────────────────────────────

func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("PASS: ", label)
	else:
		_failed += 1
		print("FAIL: ", label)


func _approx(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


# ─── PetStats ─────────────────────────────────────────────────────────────────

func _test_petstats() -> void:
	var fresh: PetStats = PetStatsScript.new()
	_check("fresh hunger is STAT_MAX", _approx(fresh.hunger, GameConfig.STAT_MAX))
	_check("fresh pet is healthy", fresh.is_healthy())

	var clamp_stat: PetStats = PetStatsScript.new()
	clamp_stat.hunger = 500.0
	_check("clamp upper to STAT_MAX", _approx(clamp_stat.hunger, GameConfig.STAT_MAX))
	clamp_stat.hunger = -50.0
	_check("clamp lower to STAT_MIN", _approx(clamp_stat.hunger, GameConfig.STAT_MIN))

	GameState.decay_test_mode = true  # deterministic multiplier for the assertion
	var decayer: PetStats = PetStatsScript.new()
	decayer.apply_decay(1.0)
	var expected := GameConfig.STAT_MAX - GameConfig.HUNGER_DECAY_RATE * GameConfig.DECAY_MULTIPLIER_TEST
	_check("apply_decay reduces hunger by its rate", _approx(decayer.hunger, expected))
	GameState.decay_test_mode = false

	var offliner: PetStats = PetStatsScript.new()
	offliner.apply_offline_decay(100000.0)
	_check("offline decay floors at STAT_MIN",
			_approx(offliner.hunger, GameConfig.STAT_MIN) and _approx(offliner.energy, GameConfig.STAT_MIN))

	var src: PetStats = PetStatsScript.new()
	src.hunger = 42.0
	src.energy = 17.0
	var restored: PetStats = PetStatsScript.new()
	restored.from_dict(src.to_dict())
	_check("to_dict/from_dict round-trip",
			_approx(restored.hunger, 42.0) and _approx(restored.energy, 17.0))

	var lowest: PetStats = PetStatsScript.new()
	lowest.hunger = 5.0
	_check("low hunger -> not healthy", not lowest.is_healthy())
	_check("get_lowest_stat finds hunger", lowest.get_lowest_stat() == "hunger")


# ─── Save migrations ──────────────────────────────────────────────────────────

func _test_migrations() -> void:
	var v0: Dictionary = {"pet": {"name": "Y"}}
	var m0: Dictionary = SaveSystem._migrate(v0)
	_check("v0 -> current version", m0.get("version") == SaveSystem.SAVE_SCHEMA_VERSION)
	_check("v0 backfills cosmetics", m0.has("cosmetics"))
	_check("v0 backfills pet.bond_xp", m0["pet"].has("bond_xp"))
	_check("v0 backfills achievements", m0.has("achievements"))

	var v1: Dictionary = {"version": 1, "pet": {"name": "X"}, "settings": {}, "cosmetics": {}}
	var m1: Dictionary = SaveSystem._migrate(v1)
	_check("v1 -> current version", m1.get("version") == SaveSystem.SAVE_SCHEMA_VERSION)
	_check("v1 backfills pet.bond_xp", m1["pet"].has("bond_xp"))
	_check("v1 backfills achievements", m1.has("achievements"))

	_check("v0 backfills personality", m0.has("personality"))

	var v3: Dictionary = {"version": 3, "pet": {"bond_xp": 5}, "achievements": {"unlocked": ["a"]}}
	var m3: Dictionary = SaveSystem._migrate(v3)
	_check("v3 -> current version", m3.get("version") == SaveSystem.SAVE_SCHEMA_VERSION)
	_check("v3 backfills personality", m3.has("personality"))
	_check("migration preserves existing bond_xp", m3["pet"]["bond_xp"] == 5)

	var v4: Dictionary = {"version": 4, "personality": {"dominant": "glotona"}}
	var m4: Dictionary = SaveSystem._migrate(v4)
	_check("current version is unchanged", m4.get("version") == SaveSystem.SAVE_SCHEMA_VERSION)
	_check("migration preserves existing personality", m4["personality"]["dominant"] == "glotona")


# ─── Achievements persistence ─────────────────────────────────────────────────

func _test_achievements_persistence() -> void:
	Achievements.load_from({"unlocked": ["first_care", "bond_3"], "interactions": 7})
	var d: Dictionary = Achievements.to_dict()
	_check("achievements interactions round-trip", d.get("interactions") == 7)
	var unlocked: Array = d.get("unlocked", [])
	_check("achievements unlocked round-trip", unlocked.has("first_care") and unlocked.has("bond_3"))
	Achievements.load_from({})  # reset global state after the test


# ─── Personality ──────────────────────────────────────────────────────────────

func _test_personality() -> void:
	Personality.load_from({})  # reset
	for i in 10:
		Personality.record("feed")
	_check("below MIN_VOLUME -> no trait", Personality.trait_id() == "")

	Personality.load_from({})
	for i in 30:
		Personality.record("feed")
	_check("dominant feeding -> glotona", Personality.trait_id() == "glotona")
	_check("glotona raises hunger decay", Personality.decay_factor("hunger") > 1.0)
	_check("glotona boosts feed gain", Personality.gain_factor("feed") > 1.0)
	_check("neutral stat decay unaffected", _approx(Personality.decay_factor("affection"), 1.0))

	Personality.record("play")  # a single off-action
	_check("one off-action keeps trait (hysteresis)", Personality.trait_id() == "glotona")

	var snap: Dictionary = Personality.to_dict()
	Personality.load_from({})
	_check("reset clears trait", Personality.trait_id() == "")
	Personality.load_from(snap)
	_check("personality round-trips", Personality.trait_id() == "glotona")

	for i in 60:
		Personality.record("play")
	_check("sustained play switches to juguetona", Personality.trait_id() == "juguetona")

	Personality.load_from({})  # reset global state after the test
