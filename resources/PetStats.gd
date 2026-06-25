## PetStats.gd
## Custom Resource — the pet's live stat values.
##
## Using Resource (not a plain Dictionary) gives us:
##   • @export visibility in the Godot editor for live inspection/debugging
##   • Type safety and property setters for threshold checks
##   • Easy serialization via to_dict() / from_dict()
##
## Pet.gd owns one instance and calls apply_decay(delta) every process frame.
## Setters emit EventBus signals so the HUD and other systems stay in sync
## without needing a direct reference to PetStats.
##
## ── Backing variables ─────────────────────────────────────────────────────────
## Each stat has a private backing variable (_hunger, etc.) so that assigning
## inside the setter never triggers recursion. In Godot 4, writing to the same
## property name inside its setter causes recursive calls that silently swallow
## the EventBus emission — backing variables eliminate this entirely.
class_name PetStats
extends Resource


# ─── Backing variables (exported so the Godot editor can inspect live values) ─

@export_range(0.0, 100.0) var _hunger:    float = 100.0
@export_range(0.0, 100.0) var _happiness: float = 100.0
@export_range(0.0, 100.0) var _energy:    float = 100.0
@export_range(0.0, 100.0) var _affection: float = 100.0


# ─── Public properties with setters ───────────────────────────────────────────

var hunger: float:
	get: return _hunger
	set(v):
		var old := _hunger
		_hunger = clampf(v, GameConfig.STAT_MIN, GameConfig.STAT_MAX)
		if _hunger != old:
			EventBus.stat_changed.emit("hunger", _hunger, old)
			_check_thresholds("hunger", _hunger, old)

var happiness: float:
	get: return _happiness
	set(v):
		var old := _happiness
		_happiness = clampf(v, GameConfig.STAT_MIN, GameConfig.STAT_MAX)
		if _happiness != old:
			EventBus.stat_changed.emit("happiness", _happiness, old)
			_check_thresholds("happiness", _happiness, old)

var energy: float:
	get: return _energy
	set(v):
		var old := _energy
		_energy = clampf(v, GameConfig.STAT_MIN, GameConfig.STAT_MAX)
		if _energy != old:
			EventBus.stat_changed.emit("energy", _energy, old)
			_check_thresholds("energy", _energy, old)

var affection: float:
	get: return _affection
	set(v):
		var old := _affection
		_affection = clampf(v, GameConfig.STAT_MIN, GameConfig.STAT_MAX)
		if _affection != old:
			EventBus.stat_changed.emit("affection", _affection, old)
			_check_thresholds("affection", _affection, old)


# ─── Public API ───────────────────────────────────────────────────────────────

## Applies real-time decay. Called by Pet.gd in _process(delta).
## Rates and multiplier come from GameConfig — change feel there, not here.
func apply_decay(delta: float) -> void:
	var m := _decay_multiplier()
	# Use self. to guarantee the setter is called and EventBus signals fire.
	# Without self., GDScript may access the backing variable directly.
	# The per-stat Personality.decay_factor() lets a trait nudge decay (always 1.0
	# when no trait is active).
	self.hunger    = _hunger    - GameConfig.HUNGER_DECAY_RATE    * m * delta * Personality.decay_factor("hunger")
	self.happiness = _happiness - GameConfig.HAPPINESS_DECAY_RATE * m * delta * Personality.decay_factor("happiness")
	self.energy    = _energy    - GameConfig.ENERGY_DECAY_RATE    * m * delta * Personality.decay_factor("energy")
	self.affection = _affection - GameConfig.AFFECTION_DECAY_RATE * m * delta * Personality.decay_factor("affection")


## Applies decay for time elapsed while the app was closed.
## Called once on load, before the pet is shown to the player.
func apply_offline_decay(elapsed_seconds: float) -> void:
	var m := _decay_multiplier()
	self.hunger    = _hunger    - GameConfig.HUNGER_DECAY_RATE    * m * elapsed_seconds * Personality.decay_factor("hunger")
	self.happiness = _happiness - GameConfig.HAPPINESS_DECAY_RATE * m * elapsed_seconds * Personality.decay_factor("happiness")
	self.energy    = _energy    - GameConfig.ENERGY_DECAY_RATE    * m * elapsed_seconds * Personality.decay_factor("energy")
	self.affection = _affection - GameConfig.AFFECTION_DECAY_RATE * m * elapsed_seconds * Personality.decay_factor("affection")


## Returns a plain Dictionary for JSON serialization.
func to_dict() -> Dictionary:
	return {
		"hunger":    hunger,
		"happiness": happiness,
		"energy":    energy,
		"affection": affection,
	}


## Restores stat values from a saved Dictionary.
## Missing keys fall back to STAT_MAX (safe default for new saves).
func from_dict(data: Dictionary) -> void:
	self.hunger    = data.get("hunger",    GameConfig.STAT_MAX)
	self.happiness = data.get("happiness", GameConfig.STAT_MAX)
	self.energy    = data.get("energy",    GameConfig.STAT_MAX)
	self.affection = data.get("affection", GameConfig.STAT_MAX)


## Current decay multiplier — fast in test mode, logical pace otherwise.
func _decay_multiplier() -> float:
	return GameConfig.DECAY_MULTIPLIER_TEST if GameState.decay_test_mode else GameConfig.DECAY_MULTIPLIER_NORMAL


## Returns true when all stats are above LOW_THRESHOLD (pet is "healthy").
func is_healthy() -> bool:
	return hunger    > GameConfig.LOW_THRESHOLD \
		and happiness > GameConfig.LOW_THRESHOLD \
		and energy    > GameConfig.LOW_THRESHOLD \
		and affection > GameConfig.LOW_THRESHOLD


## Returns the name of the lowest stat — useful for driving priority animations.
func get_lowest_stat() -> String:
	var stats := {"hunger": hunger, "happiness": happiness, "energy": energy, "affection": affection}
	var lowest_name := "hunger"
	var lowest_val  := hunger
	for key in stats:
		if stats[key] < lowest_val:
			lowest_val  = stats[key]
			lowest_name = key
	return lowest_name


# ─── Private ──────────────────────────────────────────────────────────────────

## Fires depleted / critical / recovered events based on threshold crossings.
func _check_thresholds(stat_name: String, new_val: float, old_val: float) -> void:
	if new_val <= GameConfig.STAT_MIN and old_val > GameConfig.STAT_MIN:
		EventBus.stat_depleted.emit(stat_name)
	elif new_val <= GameConfig.CRITICAL_THRESHOLD and old_val > GameConfig.CRITICAL_THRESHOLD:
		EventBus.stat_critical.emit(stat_name, new_val)
	elif new_val > GameConfig.CRITICAL_THRESHOLD and old_val <= GameConfig.CRITICAL_THRESHOLD:
		EventBus.stat_recovered.emit(stat_name, new_val)
