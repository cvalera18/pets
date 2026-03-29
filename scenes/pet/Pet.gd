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

# ─── Child references ─────────────────────────────────────────────────────────

@onready var sprite:           AnimatedSprite2D = $Sprite
@onready var interaction_area: Area2D           = $InteractionArea

# ─── State ────────────────────────────────────────────────────────────────────

var stats:    PetStats = PetStats.new()
var pet_name: String   = "Mochi"

var _interaction_cooldown: float  = 0.0
var _is_sleeping:          bool   = false


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


func _process(delta: float) -> void:
	if _is_sleeping:
		return  # Decay is paused while the pet sleeps.

	stats.apply_decay(delta)

	if _interaction_cooldown > 0.0:
		_interaction_cooldown -= delta


# ─── Public API ───────────────────────────────────────────────────────────────

## Initializes the pet with full stats for a brand new game.
func initialize_fresh() -> void:
	stats    = PetStats.new()
	pet_name = "Mochi"  # TODO: receive from name-entry onboarding screen.
	_play_anim(ANIM_IDLE)


## Loads stat values from a save Dictionary and applies offline decay.
## offline_seconds comes from SaveSystem.get_offline_seconds().
func load_from_save(pet_data: Dictionary, offline_seconds: float) -> void:
	stats    = PetStats.new()
	pet_name = pet_data.get("name", "Mochi")
	stats.from_dict(pet_data)

	if offline_seconds > 0.0:
		stats.apply_offline_decay(offline_seconds)

	_update_anim_from_stats()


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
	_reset_cooldown()


func _on_played() -> void:
	if not _can_interact():
		return
	if stats.energy <= GameConfig.CRITICAL_THRESHOLD:
		# Too tired to play — give visual feedback.
		# TODO: show a "too tired" floating label via EventBus.
		return
	stats.happiness += GameConfig.PLAY_HAPPINESS_GAIN
	stats.energy -= GameConfig.PLAY_ENERGY_COST
	_play_anim(ANIM_PLAY)
	_reset_cooldown()


func _on_slept() -> void:
	if not _can_interact() or _is_sleeping:
		return
	_is_sleeping = true
	stats.energy += GameConfig.SLEEP_ENERGY_GAIN
	_play_anim(ANIM_SLEEP)
	EventBus.sleeping_changed.emit(true)


func _on_woken() -> void:
	if not _is_sleeping:
		return
	_is_sleeping = false
	_update_anim_from_stats()
	EventBus.sleeping_changed.emit(false)
	_reset_cooldown()


func _on_petted() -> void:
	if not _can_interact():
		return
	stats.affection += GameConfig.PET_AFFECTION_GAIN
	_play_anim(ANIM_HAPPY)
	_reset_cooldown()


# ─── Stat Event Responses ─────────────────────────────────────────────────────

func _on_stat_depleted(stat_name: String) -> void:
	_play_anim(ANIM_SAD)
	_schedule_notification(stat_name, 1.0)  # Full delay for depleted.


func _on_stat_critical(stat_name: String, _value: float) -> void:
	_play_anim(ANIM_CRITICAL)
	_schedule_notification(stat_name, 0.5)  # Half delay for critical warning.


func _on_stat_recovered(_stat_name: String, _value: float) -> void:
	_update_anim_from_stats()


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


func _play_anim(anim_name: String) -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	# If the animation doesn't exist yet (placeholder sprites), fail silently.


func _update_anim_from_stats() -> void:
	if stats.is_healthy():
		_play_anim(ANIM_IDLE)
	else:
		_play_anim(ANIM_SAD)


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
