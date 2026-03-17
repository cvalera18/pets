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
class_name PetStats
extends Resource


# ─── Stat Properties ──────────────────────────────────────────────────────────
# Setters clamp to [STAT_MIN, STAT_MAX] and fire EventBus events on change.

@export_range(0.0, 100.0) var hunger: float = 100.0:
	set(v):
		var old := hunger
		hunger = clampf(v, GameConfig.STAT_MIN, GameConfig.STAT_MAX)
		if hunger != old:
			EventBus.stat_changed.emit("hunger", hunger, old)
			_check_thresholds("hunger", hunger, old)

@export_range(0.0, 100.0) var mood: float = 100.0:
	set(v):
		var old := mood
		mood = clampf(v, GameConfig.STAT_MIN, GameConfig.STAT_MAX)
		if mood != old:
			EventBus.stat_changed.emit("mood", mood, old)
			_check_thresholds("mood", mood, old)

@export_range(0.0, 100.0) var energy: float = 100.0:
	set(v):
		var old := energy
		energy = clampf(v, GameConfig.STAT_MIN, GameConfig.STAT_MAX)
		if energy != old:
			EventBus.stat_changed.emit("energy", energy, old)
			_check_thresholds("energy", energy, old)

@export_range(0.0, 100.0) var affection: float = 100.0:
	set(v):
		var old := affection
		affection = clampf(v, GameConfig.STAT_MIN, GameConfig.STAT_MAX)
		if affection != old:
			EventBus.stat_changed.emit("affection", affection, old)
			_check_thresholds("affection", affection, old)


# ─── Public API ───────────────────────────────────────────────────────────────

## Applies real-time decay. Called by Pet.gd in _process(delta).
## Rates and multiplier come from GameConfig — change feel there, not here.
func apply_decay(delta: float) -> void:
	var m := GameConfig.DECAY_MULTIPLIER
	hunger    -= GameConfig.HUNGER_DECAY_RATE    * m * delta
	mood      -= GameConfig.MOOD_DECAY_RATE      * m * delta
	energy    -= GameConfig.ENERGY_DECAY_RATE    * m * delta
	affection -= GameConfig.AFFECTION_DECAY_RATE * m * delta
	# Setters handle clamping and EventBus emission.


## Applies decay for time elapsed while the app was closed.
## Called once on load, before the pet is shown to the player.
func apply_offline_decay(elapsed_seconds: float) -> void:
	var m := GameConfig.DECAY_MULTIPLIER
	hunger    -= GameConfig.HUNGER_DECAY_RATE    * m * elapsed_seconds
	mood      -= GameConfig.MOOD_DECAY_RATE      * m * elapsed_seconds
	energy    -= GameConfig.ENERGY_DECAY_RATE    * m * elapsed_seconds
	affection -= GameConfig.AFFECTION_DECAY_RATE * m * elapsed_seconds
	# Setters handle clamping and events — the pet may already look sad on launch.


## Returns a plain Dictionary for JSON serialization.
func to_dict() -> Dictionary:
	return {
		"hunger":    hunger,
		"mood":      mood,
		"energy":    energy,
		"affection": affection,
	}


## Restores stat values from a saved Dictionary.
## Missing keys fall back to STAT_MAX (safe default for new saves).
func from_dict(data: Dictionary) -> void:
	hunger    = data.get("hunger",    GameConfig.STAT_MAX)
	mood      = data.get("mood",      GameConfig.STAT_MAX)
	energy    = data.get("energy",    GameConfig.STAT_MAX)
	affection = data.get("affection", GameConfig.STAT_MAX)


## Returns true when all stats are above LOW_THRESHOLD (pet is "healthy").
func is_healthy() -> bool:
	return hunger    > GameConfig.LOW_THRESHOLD \
		and mood      > GameConfig.LOW_THRESHOLD \
		and energy    > GameConfig.LOW_THRESHOLD \
		and affection > GameConfig.LOW_THRESHOLD


## Returns the name of the lowest stat — useful for driving priority animations.
func get_lowest_stat() -> String:
	var stats := {"hunger": hunger, "mood": mood, "energy": energy, "affection": affection}
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
