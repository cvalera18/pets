## Pet.gd
## The pet entity — owns PetStats and drives animations + interactions.
##
## Responsibilities:
##   • Ticking PetStats via apply_decay(delta) every frame
##   • Responding to player interactions (fed) and hunting the feather wand (PetPlay)
##   • Sleeping on her own when tired and waking when rested (no sleep button)
##   • Caresses: turning PetTouch's gestures into affection, purring and reactions
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

enum Mood { IDLE, SLEEP, SAD, CONTENT }

const BREATHE_SPEED_IDLE  := 2.2
const BREATHE_SPEED_SLEEP := 1.1
const BREATHE_SPEED_SAD   := 1.6

const BREATHE_AMP_IDLE  := 0.035
const BREATHE_AMP_SLEEP := 0.06
const BREATHE_AMP_SAD   := 0.02

# Pixels the torso rises per breath; the feet never leave the rug.
const BOB_AMP_IDLE  := 2.5
const BOB_AMP_SLEEP := 1.0
const BOB_AMP_SAD   := 0.8

const REACT_DURATION := 0.55

## How long Mochi keeps the content face (^ ^) after being cared for.
const CONTENT_DURATION := 2.5
const REACT_STRETCH  := 0.22

const PetTouch := preload("res://scenes/pet/PetTouch.gd")
const PetPlay := preload("res://scenes/pet/PetPlay.gd")
const Tastes := preload("res://resources/Tastes.gd")
const Haptics := preload("res://systems/Haptics.gd")

# ─── Caress tuning ────────────────────────────────────────────────────────────

const PURR_GRACE := 0.35        # seconds the purr keeps swelling after the last stroke
const PURR_BREATH := 2.4        # seconds per purr breath, same as AudioManager's loop
const PURR_HAPTIC_STEP := 0.09
const HINT_AFTER := 20.0        # a tap hints at stroking only if none happened this recently
const HINT_COOLDOWN := 8.0

const SLEEP_CHECK_EVERY := 3.0
const ZZZ_EVERY := 5.0

const FOOD_CHECK_EVERY := 1.0   # how often she glances at the bowl
const BITES := 3
const BITE_TIME := 0.9
const SNIFF_TIME := 1.0

# ─── Child references ─────────────────────────────────────────────────────────

@onready var sprite: Node2D   = $Sprite
@onready var shadow: Node2D   = $Shadow
@onready var touch:  PetTouch = $Touch
@onready var play:   PetPlay  = $Play

# ─── State ────────────────────────────────────────────────────────────────────

var stats:      PetStats = PetStats.new()
var pet_name:   String   = "Mochi"
var bond_xp:    int      = 0
var bond_level: int      = 1

var tastes: Tastes = Tastes.new()

var _is_sleeping:          bool   = false
var _thought_timer:        float  = 0.0

# Sleep runtime state (she decides when; see the Sleep section).
var _sleep_check: float = 0.0   # seconds to the next "am I sleepy?" look
var _doze_grace:  float = GameConfig.OPEN_GRACE
var _sulk:        float = 0.0   # grumpy after being woken
var _zzz_t:       float = 0.0

# Bowl runtime state (she eats when she wants; see the Food section).
var _bowl_food:   String = ""
var _bowl_amount: float  = 0.0
var _refused:     String = ""   # the food in the bowl she already turned down
var _meal:        String = ""   # the food she's eating now
var _bites_left:  int    = 0
var _bite_t:      float  = 0.0
var _meal_gain:   float  = 0.0
var _sniff_t:     float  = 0.0
var _food_check:  float  = 0.0
var _eat_t:       float  = 0.0
var _eat_tilt:    float  = 0.0
var _eat_dip:     float  = 0.0

# Procedural animation runtime state.
var _mood:       Mood    = Mood.IDLE
var _anim_time:  float   = 0.0
var _react_t:    float   = REACT_DURATION  # Starts "finished" (no active pop).
var _content_t:  float   = 0.0
var _base_scale: Vector2 = Vector2.ONE
var _shadow_scale: Vector2 = Vector2.ONE

# Active personality trait + its motion multipliers (1.0 = no trait).
var _trait_id:      String = ""
var _trait_breathe: float  = 1.0
var _trait_bob:     float  = 1.0
var _trait_react:   float  = 1.0

# Caress runtime state.
var _purr:         float = 0.0
var _purr_sent:    float = 0.0
var _purr_clock:   float = 0.0
var _haptic_t:     float = 0.0
var _purr_buzzing: bool  = false
var _stroking:     float = 0.0
var _stroke_time:  float = 0.0
var _stroke_gain:  float = 0.0
var _since_stroke: float = HINT_AFTER
var _hint_cd:      float = 0.0


func _ready() -> void:
	touch.tapped.connect(_on_tapped)
	touch.petting.connect(_on_petting)
	touch.annoyed.connect(_on_annoyed)
	touch.looked.connect(_on_looked)
	touch.released.connect(func() -> void: sprite.release_look())
	play.pounced.connect(func() -> void: _haptic(15))
	play.caught.connect(_on_play_caught)
	play.missed.connect(_on_play_missed)

	EventBus.bowl_changed.connect(_on_bowl_changed)
	EventBus.play_mode_changed.connect(_on_play_mode_changed)
	EventBus.wand_moved.connect(_on_wand_moved)
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
	_update_purr(delta)  # She can be stroked while asleep too.

	if _content_t > 0.0:
		_content_t -= delta
		if _content_t <= 0.0 and _mood == Mood.CONTENT:
			_update_mood_from_stats()

	if _is_sleeping:
		_sleep_tick(delta)
		return  # Only energy changes while she sleeps.

	play.can_hunt = stats.energy > GameConfig.CRITICAL_THRESHOLD and _sulk <= 0.0 and not _is_eating()
	play.update(delta)
	stats.apply_decay(delta)
	_eat_tick(delta)

	if _sulk > 0.0:
		_sulk -= delta
	if _doze_grace > 0.0:
		_doze_grace -= delta

	_thought_timer -= delta
	if _thought_timer <= 0.0:
		_maybe_think()

	_sleep_check -= delta
	if _sleep_check <= 0.0:
		_sleep_check = SLEEP_CHECK_EVERY
		if _wants_to_sleep():
			_fall_asleep()


# ─── Public API ───────────────────────────────────────────────────────────────

## Initializes the pet with full stats for a brand new game.
func initialize_fresh(p_name: String = "Mochi") -> void:
	stats      = PetStats.new()
	pet_name   = p_name
	bond_xp    = 0
	bond_level = 1
	tastes.roll()
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
	tastes.load_from(pet_data.get("tastes", {}))

	if offline_seconds > 0.0:
		stats.apply_offline_decay(offline_seconds)

	_doze_grace = GameConfig.OPEN_GRACE
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
	for food in tastes.known:
		EventBus.taste_discovered.emit(food, tastes.of(food))


# ─── Food (bowl) ──────────────────────────────────────────────────────────────
# You fill the bowl (FoodBowl); she eats when she wants. She has tastes (Tastes):
# her favorite she can't resist, one food she sniffs and turns down unless she's
# starving, the rest she eats when hungry. Each food's taste is discovered the
# first time she tries (or refuses) it.

func _on_bowl_changed(food: String, amount: float) -> void:
	if food != _bowl_food:
		_refused = ""
		if _meal != "" and food != "":
			_finish_meal()   # a new food replaced the one she was eating
	_bowl_food = food
	_bowl_amount = amount


func _is_eating() -> bool:
	return _meal != "" or _sniff_t > 0.0


func _consider_bowl() -> void:
	if _bowl_food == "" or _bowl_food == _refused or play.active or _stroking > 0.0 or _sulk > 0.0:
		return
	if tastes.wants(_bowl_food, stats.hunger):
		_start_meal()
	elif tastes.of(_bowl_food) == "dislike" and stats.hunger < GameConfig.EAT_BELOW:
		_sniff_t = SNIFF_TIME   # hungry enough to check it out, not enough to eat it
		_eat_t = 0.0


func _start_meal() -> void:
	_meal = _bowl_food
	_bites_left = BITES
	_bite_t = BITE_TIME * 0.5
	_meal_gain = 0.0
	_eat_t = 0.0
	_discover(_meal)
	if tastes.of(_meal) != "dislike":
		_content_t = BITES * BITE_TIME
		_set_mood(Mood.CONTENT)


func _eat_tick(delta: float) -> void:
	if not _is_eating():
		_eat_tilt = 0.0
		_eat_dip = 0.0
		_food_check -= delta
		if _food_check <= 0.0:
			_food_check = FOOD_CHECK_EVERY
			_consider_bowl()
		return
	# Head down toward the bowl; chewing steps at 12 fps like the other poses.
	_eat_t += delta
	var step := floorf(_eat_t * 12.0) / 12.0
	_eat_tilt = deg_to_rad(-5.0)
	_eat_dip = -10.0 - (3.0 if _meal != "" and int(step * 6.0) % 2 == 0 else 0.0)
	sprite.look_at_canvas(GameConfig.BOWL_OFFSET / _base_scale + PetTouch.ORIGIN)
	if _sniff_t > 0.0:
		_sniff_t -= delta
		if _sniff_t <= 0.0:
			_refuse()
		return
	_bite_t -= delta
	if _bite_t <= 0.0:
		_bite_t = BITE_TIME
		_bite()


func _bite() -> void:
	var factor := 0.5 if tastes.of(_meal) == "dislike" else 1.0
	var before := stats.hunger
	stats.hunger += float(GameConfig.FOOD_HUNGER.get(_meal, 25.0)) / BITES * factor * Personality.gain_factor("feed")
	_meal_gain += stats.hunger - before
	_bites_left -= 1
	_haptic(10)
	EventBus.bowl_bite.emit()
	if _bites_left <= 0 or _bowl_food == "":
		_finish_meal()


func _finish_meal() -> void:
	var taste := tastes.of(_meal)
	_feedback("+%d" % roundi(_meal_gain), GameConfig.COLOR_HUNGER, "eat", 30)
	var bond := _bond_amount(GameConfig.BOND_XP_FEED, "feed")
	if taste == "love":
		stats.happiness += GameConfig.LOVED_FOOD_HAPPINESS
		bond = roundi(bond * 1.5)
		EventBus.burst_requested.emit("love", global_position)
		EventBus.pet_thought.emit(tr("TASTE_LOVE"), "hunger")
	_add_bond(bond)
	Personality.record("feed")
	if taste != "dislike":
		_cheer_up()
	_meal = ""
	sprite.release_look()
	EventBus.pet_fed.emit()


func _refuse() -> void:
	_refused = _bowl_food
	_discover(_bowl_food)
	sprite.release_look()
	sprite.flinch()
	EventBus.floating_text_requested.emit(tr("FOOD_YUCK"), GameConfig.COLOR_NEUTRAL, global_position)
	EventBus.pet_thought.emit(tr("TASTE_DISLIKE"), "hunger")
	EventBus.sound_requested.emit("grumble")


func _discover(food: String) -> void:
	if food == "" or tastes.known.has(food):
		return
	tastes.known[food] = true
	EventBus.taste_discovered.emit(food, tastes.of(food))


# ─── Play (feather wand) ──────────────────────────────────────────────────────
# "Jugar" takes out the wand (FeatherWand); PetPlay decides when she pounces and
# these handlers pay out each catch. A long session tires her until she dozes off.

func _on_play_mode_changed(active: bool) -> void:
	play.set_active(active)
	touch.enabled = not active
	sprite.set_excited(1.8 if active else 1.0)
	if active and stats.energy <= GameConfig.CRITICAL_THRESHOLD:
		_feedback(tr("PET_TOO_TIRED_TO_PLAY"), GameConfig.COLOR_NEUTRAL, "", 15)
	if not active:
		sprite.release_look()


func _on_wand_moved(screen_pos: Vector2, held: bool) -> void:
	if not play.active or _is_sleeping:
		return
	# The hunt measures from her resting pose; her eyes use the rig as it is now.
	var rest := (get_global_transform_with_canvas().affine_inverse() * screen_pos) / _base_scale + PetTouch.ORIGIN
	play.set_feather(rest, held)
	sprite.look_at_canvas(touch.to_canvas(screen_pos))


func _on_play_caught(_at: Vector2) -> void:
	var before := stats.happiness
	var gain := GameConfig.PLAY_CATCH_HAPPINESS * Personality.gain_factor("play")
	stats.happiness += gain
	stats.energy -= GameConfig.PLAY_CATCH_ENERGY * Personality.play_energy_cost_factor()
	_play_anim(ANIM_PLAY)
	_feedback("+%d" % int(round(gain)), GameConfig.COLOR_HAPPINESS, "play", 40)
	_add_bond(_bond_amount(GameConfig.BOND_XP_PLAY, "play"))
	Personality.record("play", before)
	_cheer_up()
	EventBus.pet_played.emit()
	EventBus.wand_caught.emit()


func _on_play_missed(_at: Vector2) -> void:
	stats.happiness += GameConfig.PLAY_MISS_HAPPINESS * Personality.gain_factor("play")
	stats.energy -= GameConfig.PLAY_MISS_ENERGY * Personality.play_energy_cost_factor()
	EventBus.floating_text_requested.emit(tr("PLAY_MISS"), GameConfig.COLOR_NEUTRAL, global_position)
	_haptic(10)


# ─── Sleep ────────────────────────────────────────────────────────────────────
# Nobody puts Mochi to bed: she dozes off when she's tired (sooner at night) and
# wakes once rested. Waking her early makes her grumpy for a while.

func _wants_to_sleep() -> bool:
	if _doze_grace > 0.0 or _stroking > 0.0 or _purr > 0.05 or _react_t < REACT_DURATION or play.is_busy() or _is_eating():
		return false
	return stats.energy < (GameConfig.SLEEPY_ENERGY_NIGHT if _is_night() else GameConfig.SLEEPY_ENERGY)


func _fall_asleep() -> void:
	_is_sleeping = true
	_zzz_t = ZZZ_EVERY
	_content_t = 0.0
	_play_anim(ANIM_SLEEP)
	_set_mood(Mood.SLEEP)
	sprite.release_look()
	_feedback("Zzz", GameConfig.COLOR_ENERGY, "sleep", 0)
	EventBus.sleeping_changed.emit(true)
	EventBus.pet_slept.emit()


func _sleep_tick(delta: float) -> void:
	var regen := GameConfig.SLEEP_REGEN_TEST if GameState.decay_test_mode else GameConfig.SLEEP_REGEN_NORMAL
	stats.energy += regen * Personality.gain_factor("sleep") * delta
	_zzz_t -= delta
	if _zzz_t <= 0.0:
		_zzz_t = ZZZ_EVERY
		EventBus.floating_text_requested.emit("Zzz", GameConfig.COLOR_ENERGY, global_position)
	# At night she sleeps on till morning even once rested.
	if stats.energy >= GameConfig.STAT_MAX and not _is_night():
		_wake_up(false)


## disturbed = you woke her (a tap, a rough touch) instead of her waking rested.
func _wake_up(disturbed: bool) -> void:
	if not _is_sleeping:
		return
	_is_sleeping = false
	_update_anim_from_stats()
	_update_mood_from_stats()
	EventBus.sleeping_changed.emit(false)
	EventBus.pet_woken.emit()
	_trigger_reaction()
	if disturbed:
		_sulk = GameConfig.WAKE_SULK
		_doze_grace = GameConfig.WAKE_GRACE
		_stroking = 0.0
		sprite.flinch()
		EventBus.floating_text_requested.emit(tr("PET_WOKEN_GRUMPY"), GameConfig.COLOR_NEUTRAL, global_position)
		EventBus.sound_requested.emit("grumble")
		_haptic(35)
	else:
		# Letting her sleep it off is the care that grows a "dormilona".
		Personality.record("sleep")


func _is_night() -> bool:
	var hour: int = Time.get_datetime_dict_from_system()["hour"]
	return hour >= GameConfig.NIGHT_START_HOUR or hour < GameConfig.NIGHT_END_HOUR


# ─── Caresses ─────────────────────────────────────────────────────────────────
# Affection comes from stroking Mochi, not from a button: PetTouch reads the
# finger by zone and these handlers turn it into stats, purring and reactions.

func _on_petting(zone: String, delta: float, _at: Vector2) -> void:
	_stroking = PURR_GRACE
	_since_stroke = 0.0
	var factor: float = GameConfig.STROKE_ZONE_FACTOR.get(zone, 1.0)
	if _is_sleeping or _sulk > 0.0:
		factor *= 0.5
	var before := stats.affection
	stats.affection += GameConfig.STROKE_AFFECTION_RATE * factor * delta * Personality.gain_factor("pet")
	_stroke_gain += stats.affection - before
	_stroke_time += delta
	if _stroke_time >= GameConfig.STROKE_AWARD_TIME:
		_stroke_time = 0.0
		_award_caress()
	# Eyes closed in bliss while she purrs, whatever her stats (not while sulking).
	if not _is_sleeping and _sulk <= 0.0 and _purr > 0.25:
		_content_t = maxf(_content_t, 0.6)
		if _mood != Mood.CONTENT:
			_set_mood(Mood.CONTENT)


## A few seconds of good strokes: bond XP, hearts and the affection gained so far.
func _award_caress() -> void:
	if _stroke_gain >= 1.0:
		EventBus.floating_text_requested.emit("+%d" % roundi(_stroke_gain), GameConfig.COLOR_AFFECTION, global_position)
	_stroke_gain = 0.0
	if not _is_sleeping:
		EventBus.burst_requested.emit("love", global_position)
	_add_bond(_bond_amount(GameConfig.BOND_XP_PET, "pet"))
	Personality.record("pet", stats.affection)
	EventBus.pet_petted.emit()


func _on_annoyed(reason: String, _at: Vector2) -> void:
	if _is_sleeping:
		_wake_up(true)
		return
	_stroking = 0.0
	_purr = minf(_purr, 0.15)
	_stroke_time = 0.0
	_content_t = 0.0
	_update_mood_from_stats()
	sprite.flinch()
	_trigger_reaction()
	EventBus.floating_text_requested.emit(tr("TOUCH_" + reason.to_upper()), GameConfig.COLOR_NEUTRAL, global_position)
	EventBus.sound_requested.emit("grumble")
	_haptic(35)


func _on_tapped(zone: String, at: Vector2) -> void:
	if _is_sleeping:
		_wake_up(true)
		return
	if zone == "tail":
		_on_annoyed("tail", at)
		return
	_trigger_reaction()
	EventBus.sound_requested.emit("mrrp")
	_haptic(12)
	if _since_stroke >= HINT_AFTER and _hint_cd <= 0.0:
		_hint_cd = HINT_COOLDOWN
		EventBus.pet_thought.emit(tr("THOUGHT_STROKE_HINT"), "affection")


func _on_looked(at: Vector2) -> void:
	if not _is_sleeping:
		sprite.look_at_canvas(at)


## Swells the purr while strokes keep coming and lets it fade after; the audio
## follows purr_changed and the phone hums along in soft "breaths".
func _update_purr(delta: float) -> void:
	_since_stroke += delta
	if _hint_cd > 0.0:
		_hint_cd -= delta
	var cap := 0.5 if _is_sleeping else 1.0
	if _stroking > 0.0:
		_stroking -= delta
		_purr = move_toward(_purr, cap, delta / GameConfig.PURR_RISE)
	else:
		_purr = move_toward(_purr, 0.0, delta / GameConfig.PURR_FALL)
	if absf(_purr - _purr_sent) > 0.02 or (_purr == 0.0 and _purr_sent != 0.0):
		_purr_sent = _purr
		EventBus.purr_changed.emit(_purr)
	_purr_haptics(delta)


## The phone purrs along: one native 25 Hz breath at a time, re-issued as each
## breath ends so it follows the purr's strength and stops within a breath.
func _purr_haptics(delta: float) -> void:
	var prev := _purr_clock
	_purr_clock = fmod(_purr_clock + delta, PURR_BREATH)
	if _purr < 0.15:
		if _purr_buzzing:
			_purr_buzzing = false
			Haptics.stop()
		return
	if Haptics.has_waveforms():
		if not _purr_buzzing or _purr_clock < prev:
			Haptics.purr_breath(PURR_BREATH, _purr)
		_purr_buzzing = true
		return
	_purr_buzzing = true
	_haptic_t -= delta
	if _haptic_t > 0.0:
		return
	_haptic_t = PURR_HAPTIC_STEP
	var breath := 0.5 + 0.5 * sin(TAU * _purr_clock / PURR_BREATH)
	# Each pulse outlasts the step, so the buzz never gaps between calls.
	Haptics.vibrate(int(PURR_HAPTIC_STEP * 1000.0) + 40, clampf((0.05 + 0.15 * breath) * _purr, 0.04, 1.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_stroking = 0.0
		_purr = 0.0
		if _purr_buzzing:
			_purr_buzzing = false
			Haptics.stop()


# ─── Stat Event Responses ─────────────────────────────────────────────────────

func _on_stat_depleted(stat_name: String) -> void:
	_play_anim(ANIM_SAD)
	_update_mood_from_stats()
	_schedule_notification(stat_name, 1.0)  # Full delay for depleted.


func _on_stat_critical(stat_name: String, _value: float) -> void:
	_play_anim(ANIM_CRITICAL)
	_update_mood_from_stats()
	_schedule_notification(stat_name, 0.5)  # Half delay for critical warning.


func _on_stat_recovered(_stat_name: String, _value: float) -> void:
	_update_anim_from_stats()
	_update_mood_from_stats()


# ─── Private Helpers ──────────────────────────────────────────────────────────

## Emits a floating text + optional particle burst at the pet, plus haptics.
## Centralizes the juice so interaction handlers stay one-liners.
func _feedback(text: String, color: Color, burst_kind: String, haptic_ms: int) -> void:
	EventBus.floating_text_requested.emit(text, color, global_position)
	if burst_kind != "":
		EventBus.burst_requested.emit(burst_kind, global_position)
	_haptic(haptic_ms)


## Fires device haptics on mobile only (no-op on desktop / editor).
func _haptic(ms: int) -> void:
	Haptics.vibrate(ms)


## Periodically voices the pet's neediest stat as a "thought" bubble (shown by the HUD).
## Stays quiet while the pet is content (lowest stat still above LOW_THRESHOLD).
func _maybe_think() -> void:
	_thought_timer = randf_range(GameConfig.THOUGHT_INTERVAL_MIN, GameConfig.THOUGHT_INTERVAL_MAX)
	var stat := stats.get_lowest_stat()
	if float(stats.to_dict().get(stat, GameConfig.STAT_MAX)) < GameConfig.LOW_THRESHOLD:
		# A need is pressing — voice it.
		EventBus.pet_thought.emit(tr("THOUGHT_" + stat.to_upper()), stat)
	elif _trait_id != "" and randf() < 0.5:
		# Content and has a personality — occasionally show a flavor thought.
		EventBus.pet_thought.emit(tr("TRAIT_" + _trait_id.to_upper() + "_IDLE"), _trait_id)


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


## Celebrates the first time a trait is discovered (the HUD shows the toast).
func _on_trait_revealed(_tid: String) -> void:
	EventBus.burst_requested.emit("love", global_position)
	_haptic(60)


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
#   • a soft torso lift with each breath while the feet stay planted on the rug
#   • a one-shot "pop" reaction on interactions
# Everything is composed each frame from the rest pose captured in _ready, so it
# layers cleanly on top of whatever SpriteFrames animation is (or isn't) playing.

func _capture_rest_pose() -> void:
	_base_scale = sprite.scale
	_shadow_scale = shadow.scale


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

	sprite.scale = _base_scale * breathe_scale * pop * play.pose_scale
	# Moving the whole sprite lifted the feet off the rug and read as floating;
	# only a pounce (PetPlay's pose) takes her off the floor.
	sprite.set_torso_lift((1.0 - cos(_anim_time)) * 0.5 * _bob_amp() + play.torso_dip + _eat_dip)
	sprite.position = play.pose_offset * _base_scale
	sprite.rotation = play.pose_tilt + _eat_tilt
	sprite.set_leap(play.leap)
	var height := clampf(-play.pose_offset.y / 150.0, 0.0, 1.0)
	shadow.position.x = sprite.position.x
	shadow.scale = _shadow_scale * Vector2(breathe_scale.x * pop.x, 1.0) * (1.0 - 0.4 * height)
	shadow.modulate.a = 1.0 - 0.5 * height


func _trigger_reaction() -> void:
	_react_t = 0.0  # Restart the one-shot pop.


func _set_mood(mood: Mood) -> void:
	_mood = mood
	if sprite:
		sprite.set_mood(mood)


## Asleep she keeps her sleeping face, whatever her stats do meanwhile.
func _update_mood_from_stats() -> void:
	if _is_sleeping:
		_set_mood(Mood.SLEEP)
	else:
		_set_mood(Mood.IDLE if stats.is_healthy() else Mood.SAD)


## After a successful care action a healthy pet shows its content face for a bit.
func _cheer_up() -> void:
	if stats.is_healthy():
		_content_t = CONTENT_DURATION
		_set_mood(Mood.CONTENT)
	else:
		_update_mood_from_stats()


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
