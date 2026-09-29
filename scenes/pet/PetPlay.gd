## PetPlay.gd
## Mochi hunting the feather wand. She watches it; when you hold the feather still
## within reach she stalks, crouches with a butt wiggle and pounces. Whether she
## catches it (or misses, if you whisk it away mid-leap) is reported to Pet, which
## pays out the rewards.
##
## Works in the rig's 300×280 design canvas like PetTouch, and exposes a pose
## (offset, squash, tilt, torso dip, leg leap) that Pet composes into its own
## procedural animation. Poses step at 12 fps: the felt stop-motion look.
## update() holds all the logic, so tests can drive it without a scene.
extends Node

signal pounced
signal caught(at: Vector2)
signal missed(at: Vector2)

enum State { WATCH, STALK, CROUCH, POUNCE, LAND, REST }

const HEAD := Vector2(97, 90)        # the canvas point that leads the pounce
const FLOOR_Y := 275.0
const REACH := 200.0                 # farthest the feather can be from her head
const STILL_SPEED := 90.0            # canvas px/s below which the feather is "still" (fingers tremble)
const STALK_TIME := 0.35
const CROUCH_TIME := 0.55
const POUNCE_TIME := 0.55
const LAND_TIME := 0.25
const REST_TIME := 0.6
const CATCH_RADIUS := 55.0
const MAX_LEAP := Vector2(110, 150)  # sideways and upward reach of a leap
const FPS := 12.0

var active := false
## Pet clears this when she's too tired, sulking or asleep.
var can_hunt := true
var state: State = State.WATCH

# The pose Pet reads every frame.
var pose_offset := Vector2.ZERO   # canvas px
var pose_scale := Vector2.ONE
var pose_tilt := 0.0              # radians
var torso_dip := 0.0              # canvas px, negative = lower
var leap := 0.0                   # 0..1 leg stretch

var _feather := Vector2.ZERO
var _prev := Vector2.ZERO
var _has_feather := false
var _held := false
var _speed := 0.0
var _t := 0.0
var _target := Vector2.ZERO       # leap apex, relative to her rest position
var _resolved := false


func set_active(on: bool) -> void:
	active = on
	_has_feather = false
	_speed = 0.0
	_enter(State.WATCH)
	_reset_pose()


## The feather's position in design canvas, measured from her resting pose (not
## the leaping one, or the feather would drift as she moves). She only hunts a
## feather someone is holding: a dangling one is just watched.
func set_feather(c: Vector2, held: bool = true) -> void:
	_feather = c
	_held = held
	if not _has_feather:
		_prev = c
		_has_feather = true


## Mid-hunt: she shouldn't doze off or be interrupted.
func is_busy() -> bool:
	return active and state in [State.CROUCH, State.POUNCE, State.LAND]


## The feather is where she'd hunt it: held, within reach, and she's up for it.
func feather_huntable() -> bool:
	return active and _has_feather and can_hunt and _held and _in_reach(_feather)


## How close she is to pouncing, 0..1: it fills while the feather stays still.
func progress() -> float:
	match state:
		State.STALK:
			return _t / (STALK_TIME + CROUCH_TIME)
		State.CROUCH:
			return (STALK_TIME + _t) / (STALK_TIME + CROUCH_TIME)
		State.POUNCE, State.LAND:
			return 1.0
	return 0.0


func update(delta: float) -> void:
	if not active or not _has_feather or delta <= 0.0:
		return
	_t += delta
	_speed = lerpf(_speed, (_feather - _prev).length() / delta, 0.3)
	_prev = _feather
	var huntable := can_hunt and _held and _in_reach(_feather)
	var still := _speed < STILL_SPEED

	match state:
		State.WATCH:
			if huntable and still:
				_enter(State.STALK)
		State.STALK:
			if not (huntable and still):
				_enter(State.WATCH)
			elif _t >= STALK_TIME:
				_enter(State.CROUCH)
		State.CROUCH:
			if not huntable:
				_enter(State.WATCH)
			elif _t >= CROUCH_TIME:
				_target = _leap_target(_feather)
				_resolved = false
				_enter(State.POUNCE)
				pounced.emit()
		State.POUNCE:
			if not _resolved and _t >= POUNCE_TIME * 0.5:
				_resolved = true
				var mouth := HEAD + _target
				if _feather.distance_to(mouth) <= CATCH_RADIUS:
					caught.emit(_feather)
				else:
					missed.emit(mouth)
			if _t >= POUNCE_TIME:
				_enter(State.LAND)
		State.LAND:
			if _t >= LAND_TIME:
				_enter(State.REST)
		State.REST:
			if _t >= REST_TIME:
				_enter(State.WATCH)
	_pose()


func _in_reach(c: Vector2) -> bool:
	return c.y < FLOOR_Y and c.distance_to(HEAD) <= REACH


func _leap_target(c: Vector2) -> Vector2:
	var d := c - HEAD
	return Vector2(clampf(d.x, -MAX_LEAP.x, MAX_LEAP.x), clampf(d.y, -MAX_LEAP.y, 20.0))


func _enter(s: State) -> void:
	state = s
	_t = 0.0


func _reset_pose() -> void:
	pose_offset = Vector2.ZERO
	pose_scale = Vector2.ONE
	pose_tilt = 0.0
	torso_dip = 0.0
	leap = 0.0


func _pose() -> void:
	_reset_pose()
	var step := floorf(_t * FPS) / FPS   # each pose holds for 1/12 s
	match state:
		State.STALK:
			torso_dip = -3.0
		State.CROUCH:
			var k := clampf(step / 0.15, 0.0, 1.0)
			torso_dip = -9.0 * k
			pose_scale = Vector2(1.0 + 0.06 * k, 1.0 - 0.1 * k)
			var side := 1.0 if int(step * 8.0) % 2 == 0 else -1.0
			pose_tilt = deg_to_rad(2.5) * side * k
		State.POUNCE:
			var p := clampf(step / POUNCE_TIME, 0.0, 1.0)
			var arc := sin(PI * p)
			pose_offset = _target * arc
			leap = arc
			if p < 0.5:
				pose_scale = Vector2(0.94, 1.08)
		State.LAND:
			var p := clampf(step / LAND_TIME, 0.0, 1.0)
			pose_scale = Vector2(1.0 + 0.1 * (1.0 - p), 1.0 - 0.12 * (1.0 - p))
