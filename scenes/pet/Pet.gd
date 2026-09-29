## Pet.gd
## The pet entity — owns PetStats and drives animations + interactions.
##
## Responsibilities:
##   • Ticking PetStats via apply_decay(delta) every frame
##   • Responding to player interactions (fed, played, slept)
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
const Haptics := preload("res://systems/Haptics.gd")

# ─── Caress tuning ────────────────────────────────────────────────────────────

const PURR_GRACE := 0.35        # seconds the purr keeps swelling after the last stroke
const PURR_BREATH := 2.4        # seconds per purr breath, same as AudioManager's loop
const PURR_HAPTIC_STEP := 0.09
const HINT_AFTER := 20.0        # a tap hints at stroking only if none happened this recently
const HINT_COOLDOWN := 8.0

# ─── Child references ─────────────────────────────────────────────────────────

@onready var sprite: Node2D   = $Sprite
@onready var shadow: Node2D   = $Shadow
@onready var touch:  PetTouch = $Touch

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

	EventBus.pet_fed.connect(_on_fed)
	EventBus.pet_played.connect(_on_played)
	EventBus.pet_slept.connect(_on_slept)
	EventBus.pet_woken.connect(_on_woken)
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
	_cheer_up()
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
	_cheer_up()
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
	sprite.release_look()
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


# ─── Caresses ─────────────────────────────────────────────────────────────────
# Affection comes from stroking Mochi, not from a button: PetTouch reads the
# finger by zone and these handlers turn it into stats, purring and reactions.

func _on_petting(zone: String, delta: float, _at: Vector2) -> void:
	_stroking = PURR_GRACE
	_since_stroke = 0.0
	var factor: float = GameConfig.STROKE_ZONE_FACTOR.get(zone, 1.0)
	if _is_sleeping:
		factor *= 0.5
	var before := stats.affection
	stats.affection += GameConfig.STROKE_AFFECTION_RATE * factor * delta * Personality.gain_factor("pet")
	_stroke_gain += stats.affection - before
	_stroke_time += delta
	if _stroke_time >= GameConfig.STROKE_AWARD_TIME:
		_stroke_time = 0.0
		_award_caress()
	# Eyes closed in bliss while she purrs, whatever her stats.
	if not _is_sleeping and _purr > 0.25:
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
		EventBus.pet_woken.emit()
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
	_set_mood(Mood.SAD)
	_schedule_notification(stat_name, 1.0)  # Full delay for depleted.


func _on_stat_critical(stat_name: String, _value: float) -> void:
	_play_anim(ANIM_CRITICAL)
	_set_mood(Mood.SAD)
	_schedule_notification(stat_name, 0.5)  # Half delay for critical warning.


func _on_stat_recovered(_stat_name: String, _value: float) -> void:
	_update_anim_from_stats()
	_update_mood_from_stats()


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

	sprite.scale = _base_scale * breathe_scale * pop
	# Moving the whole sprite lifted the feet off the rug and read as floating.
	sprite.set_torso_lift((1.0 - cos(_anim_time)) * 0.5 * _bob_amp())
	shadow.scale = _shadow_scale * Vector2(breathe_scale.x * pop.x, 1.0)


func _trigger_reaction() -> void:
	_react_t = 0.0  # Restart the one-shot pop.


func _set_mood(mood: Mood) -> void:
	_mood = mood
	if sprite:
		sprite.set_mood(mood)


func _update_mood_from_stats() -> void:
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
