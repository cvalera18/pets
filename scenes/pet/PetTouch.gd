## PetTouch.gd
## Turns the pointer over Mochi into cat gestures: taps, strokes by zone (with
## the direction of the fur on the back) and what cats dislike — rubbing against
## the fur, rough strokes, the belly trap and grabbing the tail.
##
## Works in the rig's 300×280 design-canvas space (ORIGIN = Mochi's feet), so the
## zones match the SVG pieces and follow Mochi's scale and breathing. The logic
## lives in begin()/advance()/finish(), which take canvas points, so tests can
## drive it without input events.
##
## Reads mouse events only: on Android the touch arrives emulated as mouse
## (input_devices/pointing/emulate_mouse_from_touch), so handling both would
## count every touch twice.
extends Node

signal tapped(zone: String, at: Vector2)
signal petting(zone: String, delta: float, at: Vector2)
signal annoyed(reason: String, at: Vector2)
signal looked(at: Vector2)
signal released

const MochiRig := preload("res://scenes/pet/MochiRig.gd")
const ORIGIN := MochiRig.ORIGIN

const TAP_TIME := 0.25
const TAP_SLOP := 12.0        # canvas px a tap may wander before it counts as a stroke
const MIN_SPEED := 30.0       # canvas px/s; slower is a finger resting, not stroking
const ROUGH_SPEED := 1500.0
const ROUGH_TIME := 0.3
const AGAINST_TIME := 0.45    # a quick return stroke is forgiven; a deliberate one is not
const BELLY_TIME := 0.9
const TAIL_TIME := 0.35       # long enough that a stroke brushing past the tail is fine
const GRUMPY_TIME := 1.5

@export var rig: Node2D

## Off while the finger holds the feather wand; a stroke in progress ends.
var enabled := true:
	set(v):
		enabled = v
		if not v and _down:
			finish()

var _down := false
var _pointer := Vector2.ZERO
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _vel := Vector2.ZERO
var _held := 0.0
var _moved := false
var _rough_t := 0.0
var _against_t := 0.0
var _belly_t := 0.0
var _tail_t := 0.0
var _grumpy := 0.0


## The part of Mochi under a design-canvas point, or "" if it misses her.
## Checked in order, so the face wins over the head and the tail over the back.
static func zone_at(c: Vector2) -> String:
	if _in_ellipse(c, Vector2(97, 124), Vector2(78, 24)):
		return "cheeks"
	if _in_ellipse(c, Vector2(97, 78), Vector2(84, 66)):
		return "head"
	if Rect2(226, 52, 62, 56).has_point(c):
		return "tail"
	if Rect2(100, 198, 124, 46).has_point(c):
		return "belly"
	if Rect2(124, 98, 142, 100).has_point(c):
		return "back"
	if Rect2(56, 140, 210, 128).has_point(c):
		return "body"
	return ""


static func _in_ellipse(p: Vector2, center: Vector2, radii: Vector2) -> bool:
	return ((p - center) / radii).length_squared() <= 1.0


# ─── Gesture logic (canvas space) ─────────────────────────────────────────────

func begin(c: Vector2) -> void:
	_down = true
	_start = c
	_last = c
	_vel = Vector2.ZERO
	_held = 0.0
	_moved = false
	_rough_t = 0.0
	_against_t = 0.0
	_belly_t = 0.0
	_tail_t = 0.0


func advance(c: Vector2, delta: float) -> void:
	if not _down or delta <= 0.0:
		return
	_held += delta
	_vel = _vel.lerp((c - _last) / delta, 0.4)
	_last = c
	if not _moved and c.distance_to(_start) > TAP_SLOP:
		_moved = true
	if _grumpy > 0.0:
		_grumpy -= delta
		return

	var zone := zone_at(c)
	if zone == "tail":
		_tail_t += delta
		if _tail_t >= TAIL_TIME:
			_annoy("tail", c)
		return
	_tail_t = 0.0

	var speed := _vel.length()
	if zone == "" or not _moved or speed < MIN_SPEED:
		return
	if speed > ROUGH_SPEED:
		_rough_t += delta
		if _rough_t >= ROUGH_TIME:
			_annoy("rough", c)
		return
	_rough_t = maxf(0.0, _rough_t - delta)

	# The back's fur runs from the head (left) to the tail (right).
	if zone == "back" and _vel.x < -0.6 * speed:
		_against_t += delta
		if _against_t >= AGAINST_TIME:
			_annoy("against", c)
		return
	_against_t = 0.0

	if zone == "belly":
		_belly_t += delta
		if _belly_t >= BELLY_TIME:
			_annoy("belly", c)
			return
	petting.emit(zone, delta, c)


func finish() -> void:
	if _down and not _moved and _held < TAP_TIME:
		tapped.emit(zone_at(_start), _start)
	_down = false
	released.emit()


func _annoy(reason: String, c: Vector2) -> void:
	_grumpy = GRUMPY_TIME
	_rough_t = 0.0
	_against_t = 0.0
	_belly_t = 0.0
	_tail_t = 0.0
	annoyed.emit(reason, c)


# ─── Input plumbing ───────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if rig == null or not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer = event.position
		var c := to_canvas(_pointer)
		if event.pressed:
			looked.emit(c)
			if zone_at(c) != "":
				begin(c)
				get_viewport().set_input_as_handled()
		elif _down:
			finish()
			get_viewport().set_input_as_handled()
		else:
			released.emit()
	elif event is InputEventMouseMotion:
		_pointer = event.position
		looked.emit(to_canvas(_pointer))


func _process(delta: float) -> void:
	if _down:
		advance(to_canvas(_pointer), delta)
	elif _grumpy > 0.0:
		_grumpy -= delta


## Viewport position → the rig's design canvas.
func to_canvas(screen: Vector2) -> Vector2:
	return rig.get_global_transform_with_canvas().affine_inverse() * screen + ORIGIN
