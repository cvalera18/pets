## Pet.gd
## The pet entity — owns PetStats and drives animations + interactions.
##
## Responsibilities:
##   • Ticking PetStats via apply_decay(delta) every frame
##   • Responding to player interactions (fed, played, slept, petted)
##   • Playing animations via AnimatedSprite2D
##   • Scheduling local notifications when stats drop to critical / zero
##
## Pet does NOT know about HUD or UI. It communicates exclusively via EventBus.
## Art team: replace ANIM_* constants with your actual AnimationLibrary keys.
class_name Pet
extends Node2D


# ─── Animation name constants ─────────────────────────────────────────────────
# Match these to the animation names in your AnimatedSprite2D's SpriteFrames.
# TODO: confirm names with the art team once sprites are delivered.

const ANIM_IDLE     := "idle"
const ANIM_HAPPY    := "happy"
const ANIM_SAD      := "sad"
const ANIM_EAT      := "eat"
const ANIM_PLAY     := "play"
const ANIM_SLEEP    := "sleep"
const ANIM_CRITICAL := "critical"

# ─── Procedural animation tuning ──────────────────────────────────────────────
# Drives the "alive" motion layered on top of the SpriteFrames (see _animate).

enum Mood { IDLE, SLEEP, SAD }

const BREATHE_SPEED_IDLE  := 2.2
const BREATHE_SPEED_SLEEP := 1.1
const BREATHE_SPEED_SAD   := 1.6

const BREATHE_AMP_IDLE  := 0.035
const BREATHE_AMP_SLEEP := 0.06
const BREATHE_AMP_SAD   := 0.02

const BOB_AMP_IDLE  := 2.5
const BOB_AMP_SLEEP := 1.0
const BOB_AMP_SAD   := 0.8

const REACT_DURATION := 0.55
const REACT_STRETCH  := 0.22

# ─── Child references ─────────────────────────────────────────────────────────

@onready var sprite:           Node2D           = $Sprite
@onready var interaction_area: Area2D           = $InteractionArea

# ─── State ────────────────────────────────────────────────────────────────────

var stats:      PetStats = PetStats.new()
var pet_name:   String   = "Mochi"
var bond_xp:    int      = 0
var bond_level: int      = 1

var _interaction_cooldown: float  = 0.0
var _is_sleeping:          bool   = false
var _sleep_timer:          float  = 0.0
var _thought_timer:        float  = 0.0

# Procedural animation runtime state.
var _mood:       Mood    = Mood.IDLE
var _anim_time:  float   = 0.0
var _react_t:    float   = REACT_DURATION  # Starts "finished" (no active pop).
var _base_scale: Vector2 = Vector2.ONE
var _base_pos:   Vector2 = Vector2.ZERO

# Active personality trait + its motion multipliers (1.0 = no trait).
var _trait_id:      String = ""
var _trait_breathe: float  = 1.0
var _trait_bob:     float  = 1.0
var _trait_react:   float  = 1.0


func _ready() -> void:
	interaction_area.input_event.connect(_on_interaction_input)

	EventBus.pet_fed.connect(_on_fed)
	EventBus.pet_played.connect(_on_played)
	EventBus.pet_slept.connect(_on_slept)
	EventBus.pet_woken.connect(_on_woken)
	EventBus.pet_petted.connect(_on_petted)
	EventBus.stat_depleted.connect(_on_stat_depleted)
	EventBus.stat_critical.connect(_on_stat_critical)
	EventBus.stat_recovered.connect(_on_stat_recovered)
	EventBus.personality_updated.connect(_on_personality_updated)
	EventBus.trait_revealed.connect(_on_trait_revealed)

	_play_anim(ANIM_IDLE)
	_capture_rest_pose()
	_thought_timer = randf_range(GameConfig.THOUGHT_INTERVAL_MIN, GameConfig.THOUGHT_INTERVAL_MAX)


func _process(delta: float) -> void:
	_animate(delta)  # Procedural "alive" motion — runs even while sleeping.

	if _is_sleeping:
		_sleep_timer -= delta
		if _sleep_timer <= 0.0:
			EventBus.pet_woken.emit()  # Auto-wake after the nap finishes.
		return  # Decay is paused while the pet sleeps.

	stats.apply_decay(delta)

	if _interaction_cooldown > 0.0:
		_interaction_cooldown -= delta

	_thought_timer -= delta
	if _thought_timer <= 0.0:
		_maybe_think()


# ─── Public API ───────────────────────────────────────────────────────────────

## Initializes the pet with full stats for a brand new game.
func initialize_fresh(p_name: String = "Mochi") -> void:
	stats      = PetStats.new()
	pet_name   = p_name
	bond_xp    = 0
	bond_level = 1
	_play_anim(ANIM_IDLE)
	_set_mood(Mood.IDLE)


## Loads stat values from a save Dictionary and applies offline decay.
## offline_seconds comes from SaveSystem.get_offline_seconds().
func load_from_save(pet_data: Dictionary, offline_seconds: float) -> void:
	stats    = PetStats.new()
	pet_name = pet_data.get("name", "Mochi")
	stats.from_dict(pet_data)
	bond_xp    = int(pet_data.get("bond_xp", 0))
	@warning_ignore("integer_division")
	bond_level = 1 + bond_xp / GameConfig.BOND_XP_PER_LEVEL

	if offline_seconds > 0.0:
		stats.apply_offline_decay(offline_seconds)

	_update_anim_from_stats()
	_update_mood_from_stats()


## Emits stat_changed for all current values so the HUD can sync on startup.
## Room.gd calls this after both Pet and HUD are in the scene tree.
func broadcast_stats() -> void:
	EventBus.stat_changed.emit("hunger",    stats.hunger,    stats.hunger)
	EventBus.stat_changed.emit("happiness", stats.happiness, stats.happiness)
	EventBus.stat_changed.emit("energy",    stats.energy,    stats.energy)
	EventBus.stat_changed.emit("affection", stats.affection, stats.affection)
	EventBus.bond_level_changed.emit(bond_level)
	EventBus.bond_progress_changed.emit(_bond_ratio())
	EventBus.pet_name_changed.emit(pet_name)


# ─── Interaction Handlers ─────────────────────────────────────────────────────

func _on_fed() -> void:
	if not _can_interact():
		return
	var before := stats.hunger
	var gain := GameConfig.FEED_HUNGER_GAIN * Personality.gain_factor("feed")
	stats.hunger += gain
	_play_anim(ANIM_EAT)
	_trigger_reaction()
	_feedback("+%d" % int(round(gain)), GameConfig.COLOR_HUNGER, "eat", 30)
	_add_bond(_bond_amount(GameConfig.BOND_XP_FEED, "feed"))
	Personality.record("feed", before)
	_update_mood_from_stats()  # caring for the pet cheers it up if it's healthy
	_reset_cooldown()


func _on_played() -> void:
	if not _can_interact():
		return
	if stats.energy <= GameConfig.CRITICAL_THRESHOLD:
		# Too tired to play — give visual feedback instead of a silent no-op.
		_feedback(tr("PET_TOO_TIRED_TO_PLAY"), GameConfig.COLOR_NEUTRAL, "", 15)
		return
	var before := stats.happiness
	var gain := GameConfig.PLAY_HAPPINESS_GAIN * Personality.gain_factor("play")
	stats.happiness += gain
	stats.energy -= GameConfig.PLAY_ENERGY_COST * Personality.play_energy_cost_factor()
	_play_anim(ANIM_PLAY)
	_trigger_reaction()
	_feedback("+%d" % int(round(gain)), GameConfig.COLOR_HAPPINESS, "play", 40)
	_add_bond(_bond_amount(GameConfig.BOND_XP_PLAY, "play"))
	Personality.record("play", before)
	_update_mood_from_stats()
	_reset_cooldown()


func _on_slept() -> void:
	if not _can_interact() or _is_sleeping:
		return
	var before := stats.energy
	_is_sleeping = true
	_sleep_timer = GameConfig.SLEEP_DURATION
	stats.energy += GameConfig.SLEEP_ENERGY_GAIN * Personality.gain_factor("sleep")
	_play_anim(ANIM_SLEEP)
	_set_mood(Mood.SLEEP)
	_feedback("Zzz", GameConfig.COLOR_ENERGY, "sleep", 20)
	Personality.record("sleep", before)
	EventBus.sleeping_changed.emit(true)


func _on_woken() -> void:
	if not _is_sleeping:
		return
	_is_sleeping = false
	_update_anim_from_stats()
	_update_mood_from_stats()
	EventBus.sleeping_changed.emit(false)
	_reset_cooldown()


func _on_petted() -> void:
	if not _can_interact():
		return
	var before := stats.affection
	var gain := GameConfig.PET_AFFECTION_GAIN * Personality.gain_factor("pet")
	stats.affection += gain
	_play_anim(ANIM_HAPPY)
	_trigger_reaction()
	_feedback("+%d" % int(round(gain)), GameConfig.COLOR_AFFECTION, "love", 25)
	_add_bond(_bond_amount(GameConfig.BOND_XP_PET, "pet"))
	Personality.record("pet", before)
	_update_mood_from_stats()
	_reset_cooldown()


# ─── Stat Event Responses ─────────────────────────────────────────────────────

func _on_stat_depleted(stat_name: String) -> void:
	_play_anim(ANIM_SAD)
	_set_mood(Mood.SAD)
	_schedule_notification(stat_name, 1.0)  # Full delay for depleted.


func _on_stat_critical(stat_name: String, _value: float) -> void:
	_play_anim(ANIM_CRITICAL)
	_set_mood(Mood.SAD)
	_schedule_notification(stat_name, 0.5)  # Half delay for critical warning.


func _on_stat_recovered(_stat_name: String, _value: float) -> void:
	_update_anim_from_stats()
	_update_mood_from_stats()


# ─── Touch / Click ────────────────────────────────────────────────────────────

func _on_interaction_input(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventScreenTouch and event.pressed:
		EventBus.pet_petted.emit()
	elif event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		EventBus.pet_petted.emit()  # Editor / PC fallback for testing.


# ─── Private Helpers ──────────────────────────────────────────────────────────

func _can_interact() -> bool:
	return _interaction_cooldown <= 0.0


func _reset_cooldown() -> void:
	_interaction_cooldown = GameConfig.INTERACTION_COOLDOWN


## Emits a floating text + optional particle burst at the pet, plus haptics.
## Centralizes the juice so interaction handlers stay one-liners.
func _feedback(text: String, color: Color, burst_kind: String, haptic_ms: int) -> void:
	EventBus.floating_text_requested.emit(text, color, global_position)
	if burst_kind != "":
		EventBus.burst_requested.emit(burst_kind, global_position)
	_haptic(haptic_ms)


## Fires device haptics on mobile only (no-op on desktop / editor).
func _haptic(ms: int) -> void:
	if ms > 0 and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## Periodically voices the pet's neediest stat as a floating "thought" bubble.
## Stays quiet while the pet is content (lowest stat still above LOW_THRESHOLD).
func _maybe_think() -> void:
	_thought_timer = randf_range(GameConfig.THOUGHT_INTERVAL_MIN, GameConfig.THOUGHT_INTERVAL_MAX)
	var stat := stats.get_lowest_stat()
	if float(stats.to_dict().get(stat, GameConfig.STAT_MAX)) < GameConfig.LOW_THRESHOLD:
		# A need is pressing — voice it.
		EventBus.floating_text_requested.emit(
				tr("THOUGHT_" + stat.to_upper()), _stat_color(stat), global_position)
	elif _trait_id != "" and randf() < 0.5:
		# Content and has a personality — occasionally show a flavor thought.
		EventBus.floating_text_requested.emit(
				tr("TRAIT_" + _trait_id.to_upper() + "_IDLE"), _trait_color(_trait_id), global_position)


func _stat_color(stat: String) -> Color:
	match stat:
		"hunger":    return GameConfig.COLOR_HUNGER
		"happiness": return GameConfig.COLOR_HAPPINESS
		"energy":    return GameConfig.COLOR_ENERGY
		"affection": return GameConfig.COLOR_AFFECTION
	return GameConfig.COLOR_NEUTRAL


# ─── Personality ──────────────────────────────────────────────────────────────

## Scales a base bond-XP amount by the active trait's bond factor.
func _bond_amount(base: int, kind: String) -> int:
	return int(round(base * Personality.bond_factor(kind)))


## Syncs the active trait's motion multipliers and forwards tints to the sprite.
func _on_personality_updated(profile: Dictionary) -> void:
	_trait_id      = profile.get("dominant", "")
	_trait_breathe = profile.get("breathe", 1.0)
	_trait_bob     = profile.get("bob", 1.0)
	_trait_react   = profile.get("react", 1.0)
	if sprite and sprite.has_method("set_personality"):
		sprite.set_personality(profile)


## Celebrates the first time a trait is discovered (text + burst + haptic).
func _on_trait_revealed(tid: String) -> void:
	_feedback(tr("TRAIT_REVEAL_" + tid), GameConfig.COLOR_AFFECTION, "love", 60)


func _trait_color(tid: String) -> Color:
	match tid:
		"glotona":   return GameConfig.COLOR_HUNGER
		"juguetona": return GameConfig.COLOR_HAPPINESS
		"dormilona": return GameConfig.COLOR_ENERGY
		"mimosa":    return GameConfig.COLOR_AFFECTION
	return GameConfig.COLOR_NEUTRAL


## Adds bond XP; celebrates and notifies the HUD when a new level is reached.
func _add_bond(xp: int) -> void:
	bond_xp += xp
	@warning_ignore("integer_division")
	var new_level := 1 + bond_xp / GameConfig.BOND_XP_PER_LEVEL
	if new_level > bond_level:
		bond_level = new_level
		EventBus.bond_level_changed.emit(bond_level)
		_celebrate_level_up()
	EventBus.bond_progress_changed.emit(_bond_ratio())


## Progress within the current bond level, in [0, 1].
func _bond_ratio() -> float:
	@warning_ignore("integer_division")
	var into_level := bond_xp % GameConfig.BOND_XP_PER_LEVEL
	return float(into_level) / float(GameConfig.BOND_XP_PER_LEVEL)


func _celebrate_level_up() -> void:
	EventBus.floating_text_requested.emit(
			tr("BOND_LEVEL_UP") % bond_level, GameConfig.COLOR_AFFECTION, global_position)
	EventBus.burst_requested.emit("love", global_position)
	_haptic(60)


func _play_anim(_anim_name: String) -> void:
	pass  # Mochi has no SpriteFrames; its face is driven by mood (see _set_mood).


func _update_anim_from_stats() -> void:
	if stats.is_healthy():
		_play_anim(ANIM_IDLE)
	else:
		_play_anim(ANIM_SAD)


# ─── Procedural animation ─────────────────────────────────────────────────────
# Brings the (otherwise static) sprite to life without any new art:
#   • a volume-preserving squash-and-stretch "breathing" loop
#   • a soft vertical bob
#   • a one-shot "pop" reaction on interactions
# Everything is composed each frame from the rest pose captured in _ready, so it
# layers cleanly on top of whatever SpriteFrames animation is (or isn't) playing.

func _capture_rest_pose() -> void:
	_base_scale = sprite.scale
	_base_pos = sprite.position


func _animate(delta: float) -> void:
	_anim_time += delta * _breathe_speed()
	var breathe := sin(_anim_time) * _breathe_amp()
	# Volume-preserving: as it stretches taller it gets slightly narrower.
	var breathe_scale := Vector2(1.0 - breathe * 0.5, 1.0 + breathe)

	var pop := Vector2.ONE
	if _react_t < REACT_DURATION:
		_react_t += delta
		var p := _react_t / REACT_DURATION
		var wobble := sin(p * PI * 3.0) * (1.0 - p) * REACT_STRETCH * _trait_react
		pop = Vector2(1.0 - wobble * 0.5, 1.0 + wobble)

	sprite.scale = _base_scale * breathe_scale * pop

	var bob := cos(_anim_time) * _bob_amp()
	var droop := 2.0 if _mood == Mood.SAD else 0.0
	sprite.position = _base_pos + Vector2(0.0, bob + droop)


func _trigger_reaction() -> void:
	_react_t = 0.0  # Restart the one-shot pop.


func _set_mood(mood: Mood) -> void:
	_mood = mood
	if sprite:
		sprite.set_mood(mood)


func _update_mood_from_stats() -> void:
	_set_mood(Mood.IDLE if stats.is_healthy() else Mood.SAD)


func _breathe_speed() -> float:
	var base := BREATHE_SPEED_IDLE
	match _mood:
		Mood.SLEEP:
			base = BREATHE_SPEED_SLEEP
		Mood.SAD:
			base = BREATHE_SPEED_SAD
	return base * _trait_breathe


func _breathe_amp() -> float:
	match _mood:
		Mood.SLEEP:
			return BREATHE_AMP_SLEEP
		Mood.SAD:
			return BREATHE_AMP_SAD
		_:
			return BREATHE_AMP_IDLE


func _bob_amp() -> float:
	var base := BOB_AMP_IDLE
	match _mood:
		Mood.SLEEP:
			base = BOB_AMP_SLEEP
		Mood.SAD:
			base = BOB_AMP_SAD
	return base * _trait_bob


## Schedules a notification for the given stat. delay_factor 0.5 = half the config delay.
func _schedule_notification(stat_name: String, delay_factor: float) -> void:
	match stat_name:
		"hunger":
			EventBus.notification_schedule_requested.emit(
					"HUNGRY", GameConfig.NOTIF_HUNGER_DELAY * delay_factor)
		"happiness", "affection":
			EventBus.notification_schedule_requested.emit(
					"LONELY", GameConfig.NOTIF_LONELY_DELAY * delay_factor)
		"energy":
			EventBus.notification_schedule_requested.emit(
					"TIRED", GameConfig.NOTIF_TIRED_DELAY * delay_factor)
