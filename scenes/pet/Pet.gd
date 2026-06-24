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

@onready var sprite:           AnimatedSprite2D = $Sprite
@onready var interaction_area: Area2D           = $InteractionArea

# ─── State ────────────────────────────────────────────────────────────────────

var stats:    PetStats = PetStats.new()
var pet_name: String   = "Mochi"

var _interaction_cooldown: float  = 0.0
var _is_sleeping:          bool   = false
var _sleep_timer:          float  = 0.0

# Procedural animation runtime state.
var _mood:       Mood    = Mood.IDLE
var _anim_time:  float   = 0.0
var _react_t:    float   = REACT_DURATION  # Starts "finished" (no active pop).
var _base_scale: Vector2 = Vector2.ONE
var _base_pos:   Vector2 = Vector2.ZERO


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

	_play_anim(ANIM_IDLE)
	_capture_rest_pose()


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


# ─── Public API ───────────────────────────────────────────────────────────────

## Initializes the pet with full stats for a brand new game.
func initialize_fresh(p_name: String = "Mochi") -> void:
	stats    = PetStats.new()
	pet_name = p_name
	_play_anim(ANIM_IDLE)
	_set_mood(Mood.IDLE)


## Loads stat values from a save Dictionary and applies offline decay.
## offline_seconds comes from SaveSystem.get_offline_seconds().
func load_from_save(pet_data: Dictionary, offline_seconds: float) -> void:
	stats    = PetStats.new()
	pet_name = pet_data.get("name", "Mochi")
	stats.from_dict(pet_data)

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


# ─── Interaction Handlers ─────────────────────────────────────────────────────

func _on_fed() -> void:
	if not _can_interact():
		return
	stats.hunger += GameConfig.FEED_HUNGER_GAIN
	_play_anim(ANIM_EAT)
	_trigger_reaction()
	_feedback("+%d" % int(GameConfig.FEED_HUNGER_GAIN), GameConfig.COLOR_HUNGER, "eat", 30)
	_reset_cooldown()


func _on_played() -> void:
	if not _can_interact():
		return
	if stats.energy <= GameConfig.CRITICAL_THRESHOLD:
		# Too tired to play — give visual feedback instead of a silent no-op.
		_feedback(tr("PET_TOO_TIRED_TO_PLAY"), GameConfig.COLOR_NEUTRAL, "", 15)
		return
	stats.happiness += GameConfig.PLAY_HAPPINESS_GAIN
	stats.energy -= GameConfig.PLAY_ENERGY_COST
	_play_anim(ANIM_PLAY)
	_trigger_reaction()
	_feedback("+%d" % int(GameConfig.PLAY_HAPPINESS_GAIN), GameConfig.COLOR_HAPPINESS, "play", 40)
	_reset_cooldown()


func _on_slept() -> void:
	if not _can_interact() or _is_sleeping:
		return
	_is_sleeping = true
	_sleep_timer = GameConfig.SLEEP_DURATION
	stats.energy += GameConfig.SLEEP_ENERGY_GAIN
	_play_anim(ANIM_SLEEP)
	_set_mood(Mood.SLEEP)
	_feedback("Zzz", GameConfig.COLOR_ENERGY, "sleep", 20)
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
	stats.affection += GameConfig.PET_AFFECTION_GAIN
	_play_anim(ANIM_HAPPY)
	_trigger_reaction()
	_feedback("+%d" % int(GameConfig.PET_AFFECTION_GAIN), GameConfig.COLOR_AFFECTION, "love", 25)
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


func _play_anim(anim_name: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	# If the animation doesn't exist yet (placeholder sprites), fail silently.


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
		var wobble := sin(p * PI * 3.0) * (1.0 - p) * REACT_STRETCH
		pop = Vector2(1.0 - wobble * 0.5, 1.0 + wobble)

	sprite.scale = _base_scale * breathe_scale * pop

	var bob := cos(_anim_time) * _bob_amp()
	var droop := 2.0 if _mood == Mood.SAD else 0.0
	sprite.position = _base_pos + Vector2(0.0, bob + droop)


func _trigger_reaction() -> void:
	_react_t = 0.0  # Restart the one-shot pop.


func _set_mood(mood: Mood) -> void:
	_mood = mood


func _update_mood_from_stats() -> void:
	_set_mood(Mood.IDLE if stats.is_healthy() else Mood.SAD)


func _breathe_speed() -> float:
	match _mood:
		Mood.SLEEP:
			return BREATHE_SPEED_SLEEP
		Mood.SAD:
			return BREATHE_SPEED_SAD
		_:
			return BREATHE_SPEED_IDLE


func _breathe_amp() -> float:
	match _mood:
		Mood.SLEEP:
			return BREATHE_AMP_SLEEP
		Mood.SAD:
			return BREATHE_AMP_SAD
		_:
			return BREATHE_AMP_IDLE


func _bob_amp() -> float:
	match _mood:
		Mood.SLEEP:
			return BOB_AMP_SLEEP
		Mood.SAD:
			return BOB_AMP_SAD
		_:
			return BOB_AMP_IDLE


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
