## TestRunner.gd
## Lightweight, dependency-free test harness (no GUT). Run it as its own scene:
##   run_project(scene = "res://tests/TestRunner.tscn")
## It prints PASS/FAIL per assertion and a final tally to stdout, so a headless
## run can be checked from the captured output. Pure logic only — it never
## touches the real save file (SaveSystem._migrate operates on plain Dictionaries).
extends Node

const PetStatsScript := preload("res://resources/PetStats.gd")
const PetTouchScript := preload("res://scenes/pet/PetTouch.gd")
const PetPlayScript := preload("res://scenes/pet/PetPlay.gd")
const PetGesturesScript := preload("res://scenes/pet/PetGestures.gd")
const TastesScript := preload("res://resources/Tastes.gd")
const TemperamentScript := preload("res://resources/Temperament.gd")
const RoutineScript := preload("res://systems/Routine.gd")
const JournalScript := preload("res://resources/JournalData.gd")

var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("=== PETS TEST SUITE ===")
	_test_petstats()
	_test_migrations()
	_test_achievements_persistence()
	_test_personality()
	_test_pet_touch()
	_test_pet_play()
	_test_pet_gestures()
	_test_tastes()
	_test_routine_and_temperament()
	_test_journal()
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

	var brief: PetStats = PetStatsScript.new()
	brief.apply_offline_decay(600.0)
	var brief_expected := GameConfig.STAT_MAX - GameConfig.HUNGER_DECAY_RATE * GameConfig.DECAY_MULTIPLIER_NORMAL * 600.0
	_check("short absence decays normally", _approx(brief.hunger, brief_expected))

	var overnight: PetStats = PetStatsScript.new()
	overnight.apply_offline_decay(100000.0)
	_check("a day away settles at the calm floor, not zero",
			_approx(overnight.hunger, GameConfig.OFFLINE_FLOOR) and _approx(overnight.energy, GameConfig.OFFLINE_FLOOR))
	_check("the calm floor keeps her healthy on return", overnight.is_healthy())

	var neglected: PetStats = PetStatsScript.new()
	neglected.apply_offline_decay(GameConfig.NEGLECT_AFTER + GameConfig.NEGLECT_SPAN * 2.0)
	_check("days of neglect sink to the neglect floor", _approx(neglected.affection, GameConfig.NEGLECT_FLOOR))

	var low: PetStats = PetStatsScript.new()
	low.hunger = 30.0
	low.apply_offline_decay(3600.0)
	_check("absence never raises a stat that was already low", _approx(low.hunger, 30.0))

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

	var v4p: Dictionary = {"version": 4, "pet": {"name": "Z", "bond_xp": 3}}
	var m4p: Dictionary = SaveSystem._migrate(v4p)
	_check("v4 backfills pet.tastes", m4p["pet"].has("tastes"))

	var v5: Dictionary = {"version": 5, "pet": {"name": "W", "tastes": {}}}
	var m5: Dictionary = SaveSystem._migrate(v5)
	_check("v5 backfills pet.temperament", m5["pet"].has("temperament") and m5["version"] >= 6)

	var v6: Dictionary = {"version": 6, "pet": {"name": "V", "temperament": {}}}
	var m6: Dictionary = SaveSystem._migrate(v6)
	_check("v6 backfills pet.journal", m6["pet"].has("journal") and m6["version"] == 7)


# ─── Food tastes ──────────────────────────────────────────────────────────────

func _test_tastes() -> void:
	var t = TastesScript.new()
	t.roll()
	var values: Array = t.taste.values()
	_check("tastes: one favorite, one disliked, the rest liked",
			values.count("love") == 1 and values.count("dislike") == 1 and values.count("like") == 2)

	var a = TastesScript.new()
	var b = TastesScript.new()
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed = 42
	rng_b.seed = 42
	a.roll(rng_a)
	b.roll(rng_b)
	_check("tastes roll is deterministic with a seed", a.taste == b.taste)

	var fav: String = t.taste.find_key("love")
	var yuck: String = t.taste.find_key("dislike")
	var liked: String = t.taste.find_key("like")
	_check("favorite tempts her even when nearly full", t.wants(fav, 90.0) and not t.wants(fav, 97.0))
	_check("liked food only when hungry", t.wants(liked, 70.0) and not t.wants(liked, 80.0))
	_check("disliked food only when starving", t.wants(yuck, 15.0) and not t.wants(yuck, 50.0))

	t.known[fav] = true
	var restored = TastesScript.new()
	restored.load_from(t.to_dict())
	_check("tastes round-trip", restored.taste == t.taste and restored.known.has(fav))

	var broken = TastesScript.new()
	broken.load_from({"taste": {"tuna": "love", "carrot": "love"}})
	_check("broken tastes are rolled anew", broken.taste.values().count("love") == 1 and broken.taste.size() == 4)

	_check("she has one favorite zone to be stroked", t.zone in TastesScript.ZONES and not t.zone_known)
	t.zone_known = true
	var again = TastesScript.new()
	again.load_from(t.to_dict())
	_check("favorite zone round-trips", again.zone == t.zone and again.zone_known)
	var older = TastesScript.new()
	older.load_from({"taste": t.taste, "known": [fav]})
	_check("an older save gets a favorite zone and keeps its foods",
			older.zone in TastesScript.ZONES and older.taste == t.taste and older.known.has(fav))


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


# ─── Caresses (PetTouch) ──────────────────────────────────────────────────────

func _test_pet_touch() -> void:
	_check("zone: forehead is head", PetTouchScript.zone_at(Vector2(97, 50)) == "head")
	_check("zone: cheek is cheeks", PetTouchScript.zone_at(Vector2(60, 120)) == "cheeks")
	_check("zone: back", PetTouchScript.zone_at(Vector2(200, 150)) == "back")
	_check("zone: belly", PetTouchScript.zone_at(Vector2(160, 225)) == "belly")
	_check("zone: tail tip", PetTouchScript.zone_at(Vector2(255, 80)) == "tail")
	_check("zone: empty corner misses Mochi", PetTouchScript.zone_at(Vector2(10, 10)) == "")

	var dt := 1.0 / 60.0
	var got := {"pet": 0, "annoyed": "", "tap": ""}
	var t: Node = PetTouchScript.new()
	t.petting.connect(func(_z: String, _d: float, _a: Vector2) -> void: got["pet"] += 1)
	t.annoyed.connect(func(r: String, _a: Vector2) -> void: got["annoyed"] = r)
	t.tapped.connect(func(z: String, _a: Vector2) -> void: got["tap"] = z)

	# Head → tail along the back, 300 px/s: good strokes, no complaint.
	t.begin(Vector2(140, 150))
	for i in 30:
		t.advance(Vector2(140 + 5 * (i + 1), 150), dt)
	t.finish()
	_check("stroke with the fur pets", got["pet"] > 10 and got["annoyed"] == "")

	# Tail → head across the whole back, deliberate (240 px/s): against the fur.
	t.begin(Vector2(264, 150))
	for i in 40:
		t.advance(Vector2(264 - 4 * (i + 1), 150), dt)
	t.finish()
	_check("stroke against the fur annoys", got["annoyed"] == "against")

	# Belly rubs are welcome for a moment, then it's a trap. (Skips the grumpy wait.)
	got["annoyed"] = ""
	t._grumpy = 0.0
	t.begin(Vector2(110, 220))
	for i in 80:
		t.advance(Vector2(110 + (i + 1), 220), dt)
	t.finish()
	_check("belly rub springs the trap", got["annoyed"] == "belly")

	# Holding the tail.
	got["annoyed"] = ""
	t._grumpy = 0.0
	t.begin(Vector2(255, 80))
	for i in 30:
		t.advance(Vector2(255, 80), dt)
	t.finish()
	_check("holding the tail annoys", got["annoyed"] == "tail")

	# A quick touch that barely moves is a tap on that zone.
	t._grumpy = 0.0
	t.begin(Vector2(97, 50))
	t.advance(Vector2(99, 51), 0.1)
	t.finish()
	_check("quick touch is a tap", got["tap"] == "head")

	# A finger held still on her head: she rubs against it (not a tap).
	got["tap"] = ""
	var rests := [0]
	t.resting.connect(func(_z: String, _d: float, _a: Vector2) -> void: rests[0] += 1)
	t.begin(Vector2(97, 50))
	for i in 40:
		t.advance(Vector2(97, 50), dt)
	t.finish()
	_check("finger resting on her head gets rubbed", rests[0] > 5 and got["tap"] == "")

	rests[0] = 0
	t.begin(Vector2(200, 150))
	for i in 40:
		t.advance(Vector2(200, 150), dt)
	t.finish()
	_check("a finger resting on her back isn't rubbed", rests[0] == 0)
	t.free()


# ─── Body language (PetGestures) ──────────────────────────────────────────────

func _test_pet_gestures() -> void:
	var dt := 1.0 / 60.0
	var got := {"pawed": 0, "meowed": 0, "out": 0, "dropped": 0, "done": 0}
	var g: Node = PetGesturesScript.new()
	g.pawed.connect(func() -> void: got["pawed"] += 1)
	g.meowed.connect(func() -> void: got["meowed"] += 1)
	g.went_out.connect(func() -> void: got["out"] += 1)
	g.dropped.connect(func() -> void: got["dropped"] += 1)
	g.done.connect(func(_k: int) -> void: got["done"] += 1)

	g.ask_food()
	var paw_seen := false
	for i in 180:
		g.update(dt)
		paw_seen = paw_seen or g.paw > 0.5
	_check("hungry: paws at the bowl twice and meows once", got["pawed"] == 2 and got["meowed"] == 1 and paw_seen)
	_check("ask for food ends back in her pose", not g.busy() and g.paw == 0.0 and got["done"] == 1)

	got["meowed"] = 0
	g.fetch()
	var went_right := false
	var max_x := 0.0
	var carried := false
	for i in 900:
		g.update(dt)
		max_x = maxf(max_x, g.offset.x)
		went_right = went_right or (g.facing < 0.0 and g.offset.x > 0.0)
		carried = carried or g.carrying
		if not g.busy():
			break
	_check("fetch: trots out of sight facing right", went_right and max_x >= PetGesturesScript.AWAY_X)
	_check("fetch: comes back carrying and drops the wand", carried and got["out"] == 1 and got["dropped"] == 1)
	_check("fetch: ends home, facing her way, after a meow",
			not g.busy() and g.offset == Vector2.ZERO and g.facing == 1.0 and got["meowed"] == 1)

	got["dropped"] = 0
	g.fetch()
	for i in 30:
		g.update(dt)
	g.cancel()
	for i in 600:
		g.update(dt)
		if not g.busy():
			break
	_check("wand taken out mid-fetch: she comes back empty-mouthed",
			not g.busy() and got["dropped"] == 0 and not g.carrying and g.offset == Vector2.ZERO)

	g.ask_pet()
	var rubbed := false
	for i in 150:
		g.update(dt)
		rubbed = rubbed or g.rub > 0.9
	_check("wanting cuddles: rubs her head against the air", rubbed and not g.busy() and g.rub == 0.0)

	g.groom()
	var licked := false
	for i in 240:
		g.update(dt)
		licked = licked or g.lift > 0.8
	_check("grooming: paw up to the chin, then back to her pose", licked and not g.busy() and g.lift == 0.0)

	var yawns := [0]
	g.yawned.connect(func() -> void: yawns[0] += 1)
	g.stretch()
	var stretched := false
	for i in 180:
		g.update(dt)
		stretched = stretched or (g.reach > 0.9 and g.tilt < 0.0)
	_check("stretch: front down, rear up, one yawn", stretched and yawns[0] == 1 and not g.busy())

	g.zoomies()
	var went := {"right": false, "left": false}
	for i in 600:
		g.update(dt)
		if g.offset.x > 80.0 and g.facing < 0.0:
			went["right"] = true
		if g.offset.x < -70.0 and g.facing > 0.0:
			went["left"] = true
		if not g.busy():
			break
	_check("zoomies: dashes right and left, ends home", went["right"] and went["left"] and not g.busy() and g.offset == Vector2.ZERO)
	g.free()


# ─── Her day (Routine + Temperament) ─────────────────────────────────────────

func _test_routine_and_temperament() -> void:
	var blocks := {8: "manana", 12: "activa", 15: "siesta", 18: "atardecer", 21: "calma", 23: "noche", 3: "noche"}
	var ok := true
	for h in blocks:
		ok = ok and RoutineScript.block(h) == blocks[h]
	_check("routine: the day's blocks follow the clock", ok)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var t = TemperamentScript.new()
	t.roll(rng)
	_check("temperament rolls within -1..1", absf(t.energy) <= 1.0 and absf(t.attachment) <= 1.0)
	var copy = TemperamentScript.new()
	copy.load_from(t.to_dict())
	_check("temperament survives a save", is_equal_approx(copy.energy, t.energy) and is_equal_approx(copy.attachment, t.attachment))
	var fresh = TemperamentScript.new()
	fresh.energy = 5.0
	fresh.load_from({})
	_check("missing temperament is rolled anew", absf(fresh.energy) <= 1.0)

	var clingy = TemperamentScript.new()
	clingy.attachment = 1.0
	var aloof = TemperamentScript.new()
	aloof.attachment = -1.0
	_check("an attached cat asks for cuddles much sooner",
			clingy.asks_below("affection", "activa", "") > aloof.asks_below("affection", "activa", "") + 30.0)
	_check("an independent cat only asks when she really needs it",
			aloof.asks_below("affection", "activa", "") <= GameConfig.CRITICAL_THRESHOLD)
	_check("dusk makes her cuddlier", clingy.asks_below("affection", "atardecer", "") > clingy.asks_below("affection", "activa", ""))
	_check("breakfast comes early in the morning", t.asks_below("hunger", "manana", "") > t.asks_below("hunger", "activa", ""))
	_check("habits move the line (glotona asks for food sooner)", t.asks_below("hunger", "activa", "glotona") > t.asks_below("hunger", "activa", ""))

	var calm = TemperamentScript.new()
	calm.energy = -1.0
	var restless = TemperamentScript.new()
	restless.energy = 1.0
	_check("calm cats nap sooner in the afternoon", calm.sleepy_energy("siesta", "") > restless.sleepy_energy("siesta", ""))
	_check("no afternoon nap outside the nap hours", calm.sleepy_energy("activa", "") == GameConfig.SLEEPY_ENERGY)
	_check("restless cats have mad dashes, calm ones don't",
			restless.free_time_weights("activa", "")["zoomies"] > 0.0 and calm.free_time_weights("activa", "")["zoomies"] == 0.0)
	_check("no mad dashes at night", restless.free_time_weights("noche", "")["zoomies"] == 0.0)
	_check("weighted pick lands on the right option",
			TemperamentScript.pick({"a": 1.0, "b": 0.0, "c": 1.0}, 0.25) == "a" and TemperamentScript.pick({"a": 1.0, "b": 0.0, "c": 1.0}, 0.75) == "c")


# ─── The Libreta (JournalData) ────────────────────────────────────────────────

func _test_journal() -> void:
	var j = JournalScript.new()
	j.start(1000.0)
	_check("a new notebook knows nothing yet", not j.knows("energy") and not j.knows("attach") and j.seen.is_empty())
	var revealed := [j.add_sign("energy"), j.add_sign("energy"), j.add_sign("energy"), j.add_sign("energy")]
	_check("three signs reveal a side of her temperament, once", revealed == [false, false, true, false] and j.knows("energy"))
	_check("each part of her day is noted the first time", j.see("siesta") and not j.see("siesta"))
	_check("days together count from her arrival", j.days_together(1000.0) == 1 and j.days_together(1000.0 + 86400.0 * 4.5) == 5)
	j.unread = true
	var copy = JournalScript.new()
	copy.load_from(j.to_dict(), 5000.0)
	_check("the notebook survives a save",
			copy.arrived_at == 1000.0 and copy.knows("energy") and copy.seen.has("siesta") and copy.unread)
	var older = JournalScript.new()
	older.load_from({}, 5000.0)
	_check("an older save starts its notebook now", older.arrived_at == 5000.0 and not older.knows("attach"))


# ─── Play (PetPlay) ───────────────────────────────────────────────────────────

func _test_pet_play() -> void:
	var dt := 1.0 / 60.0
	var near := Vector2(200, 60)   # beside her face, within reach
	var got := {"caught": 0, "missed": 0, "pounced": 0}
	var p: Node = PetPlayScript.new()
	p.caught.connect(func(_a: Vector2) -> void: got["caught"] += 1)
	p.missed.connect(func(_a: Vector2) -> void: got["missed"] += 1)
	p.pounced.connect(func() -> void: got["pounced"] += 1)

	p.set_active(true)
	p.set_feather(near)
	for i in 120:
		p.update(dt)
	_check("feather held still in reach gets caught", got["caught"] >= 1 and got["missed"] == 0)

	got["pounced"] = 0
	p.set_active(true)
	p.set_feather(Vector2(330, -60))
	for i in 180:
		p.update(dt)
	_check("feather out of reach: no pounce", got["pounced"] == 0)

	p.set_active(true)
	p.set_feather(near, false)
	for i in 180:
		p.update(dt)
	_check("a dangling feather nobody holds is only watched", got["pounced"] == 0)

	p.set_active(true)
	p.can_hunt = false
	p.set_feather(near)
	for i in 180:
		p.update(dt)
	_check("too tired to hunt: no pounce", got["pounced"] == 0)

	got["caught"] = 0
	p.can_hunt = true
	p.set_active(true)
	p.set_feather(near)
	var frames := 0
	while got["pounced"] == 0 and frames < 200:
		p.update(dt)
		frames += 1
	_check("mid-leap she's busy (won't doze off)", p.is_busy())
	p.set_feather(near + Vector2(0, -120))   # whisked away mid-leap
	for i in 40:
		p.update(dt)
	_check("feather whisked away mid-leap is a miss", got["missed"] == 1 and got["caught"] == 0)
	p.free()
