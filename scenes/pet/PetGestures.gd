## PetGestures.gd
## Mochi's body language: she shows what she needs instead of saying it. Hungry,
## she paws at her bowl and meows; bored, she trots off and comes back with the
## feather wand in her mouth; wanting cuddles, she rubs her head against the air.
## (Rubbing against your finger is a caress; see PetTouch.resting.)
##
## Like PetPlay it only holds the timeline and a pose that Pet composes into its
## animation (offset in design canvas px, facing, stride, paw, tilt, dip, rub);
## the side effects go out as signals so Pet can play the sounds and move the bowl
## or the wand. Poses step at 12 fps. update() holds all the logic, so tests can
## drive it without a scene.
extends Node

signal pawed        # a paw lands on the bowl
signal meowed
signal went_out     # out of sight: she picks up the wand here
signal dropped      # she lets go of the wand, on the floor in front of you
signal done(kind: int)

enum Kind { NONE, ASK_FOOD, ASK_PET, FETCH }
enum Phase { OUT, AWAY, BACK, DROP, SIT }

const FPS := 12.0

const FOOD_PAWS := [0.4, 1.0]   # when each paw reaches the bowl
const PAW_TIME := 0.42          # one paw: up, over the bowl and back down
const FOOD_MEOW := 1.55
const FOOD_TIME := 2.3

const PET_TIME := 2.0

const WALK_SPEED := 190.0       # canvas px/s
const AWAY_X := 340.0           # far enough right to be out of sight
const STEP := 38.0              # canvas px per hop
const HOP := 7.0
const AWAY_TIME := 1.2
const DROP_TIME := 0.5
const SIT_TIME := 1.4
const SIT_MEOW := 0.25

var kind: Kind = Kind.NONE
var phase: Phase = Phase.OUT
## True while the wand is in her mouth: Pet reports where her mouth is.
var carrying := false

# The pose Pet reads every frame.
var offset := Vector2.ZERO    # canvas px from her spot on the rug
var facing := 1.0             # 1 = her own pose (facing left), -1 = mirrored
var stride := 0.0             # -1..1, legs swinging in diagonal pairs
var paw := 0.0                # 0..1, far front paw reaching for the bowl
var tilt := 0.0               # radians
var dip := 0.0                # canvas px, negative = lower
var rub := 0.0                # 0..1, head rubbing against the air

var _t := 0.0
var _x := 0.0
var _walked := 0.0
var _frame := 0.0
var _fired := {}
var _cancelled := false


func busy() -> bool:
	return kind != Kind.NONE


func is_fetching() -> bool:
	return kind == Kind.FETCH


func ask_food() -> void:
	_start(Kind.ASK_FOOD)


func ask_pet() -> void:
	_start(Kind.ASK_PET)


func fetch() -> void:
	_start(Kind.FETCH)
	_enter(Phase.OUT)


## The wand came out some other way ("Jugar"): she heads back without it.
func cancel() -> void:
	if kind != Kind.FETCH:
		if busy():
			_finish()
		return
	_cancelled = true
	carrying = false
	if phase == Phase.OUT or phase == Phase.AWAY:
		_enter(Phase.BACK)


func update(delta: float) -> void:
	if kind == Kind.NONE or delta <= 0.0:
		return
	_t += delta
	match kind:
		Kind.ASK_FOOD:
			for i in FOOD_PAWS.size():
				_once("paw%d" % i, _t >= FOOD_PAWS[i], pawed)
			_once("meow", _t >= FOOD_MEOW, meowed)
			if _t >= FOOD_TIME:
				_finish()
				return
		Kind.ASK_PET:
			if _t >= PET_TIME:
				_finish()
				return
		Kind.FETCH:
			if _fetch_tick(delta):
				return
	_frame += delta
	if _frame >= 1.0 / FPS:
		_frame = fmod(_frame, 1.0 / FPS)
		_pose()


## Returns true once the fetch is over.
func _fetch_tick(delta: float) -> bool:
	match phase:
		Phase.OUT:
			_walk(delta, AWAY_X)
			if _x >= AWAY_X:
				_enter(Phase.AWAY)
				carrying = true
				went_out.emit()
		Phase.AWAY:
			if _t >= AWAY_TIME:
				_enter(Phase.BACK)
		Phase.BACK:
			_walk(delta, 0.0)
			if _x <= 0.0:
				if _cancelled:
					_finish()
					return true
				_enter(Phase.DROP)
		Phase.DROP:
			if carrying and _t >= DROP_TIME * 0.6:
				carrying = false
				dropped.emit()
			if _t >= DROP_TIME:
				_enter(Phase.SIT)
		Phase.SIT:
			_once("meow", _t >= SIT_MEOW, meowed)
			if _t >= SIT_TIME:
				_finish()
				return true
	return false


func _walk(delta: float, goal: float) -> void:
	facing = -1.0 if goal > _x else 1.0
	var before := _x
	_x = move_toward(_x, goal, WALK_SPEED * delta)
	_walked += absf(_x - before)


func _start(k: Kind) -> void:
	kind = k
	_t = 0.0
	_x = 0.0
	_walked = 0.0
	_frame = 1.0 / FPS
	_fired.clear()
	_cancelled = false
	carrying = false
	_reset_pose()


func _enter(p: Phase) -> void:
	phase = p
	_t = 0.0
	_fired.clear()


func _finish() -> void:
	var k := kind
	kind = Kind.NONE
	carrying = false
	_reset_pose()
	done.emit(k)


func _once(key: String, cond: bool, sig: Signal) -> void:
	if cond and not _fired.has(key):
		_fired[key] = true
		sig.emit()


func _reset_pose() -> void:
	offset = Vector2.ZERO
	facing = 1.0
	stride = 0.0
	paw = 0.0
	tilt = 0.0
	dip = 0.0
	rub = 0.0


func _pose() -> void:
	var keep_facing := facing
	_reset_pose()
	match kind:
		Kind.ASK_FOOD:
			if _t < FOOD_MEOW:
				tilt = deg_to_rad(-4.0)
			for at in FOOD_PAWS:
				var p: float = (_t - at) / PAW_TIME + 0.5
				if p > 0.0 and p < 1.0:
					paw = sin(PI * p)
		Kind.ASK_PET:
			rub = clampf(minf(_t, PET_TIME - _t) / 0.3, 0.0, 1.0)
			dip = -2.0 * rub
		Kind.FETCH:
			facing = keep_facing
			offset.x = _x
			match phase:
				Phase.OUT, Phase.BACK:
					var hop := fmod(_walked / STEP, 1.0)
					offset.y = -HOP * sin(PI * hop)
					stride = sin(PI * _walked / STEP)
					tilt = deg_to_rad(2.0) * sin(TAU * hop)
				Phase.DROP:
					dip = -8.0 * sin(PI * clampf(_t / DROP_TIME, 0.0, 1.0))
					tilt = deg_to_rad(-3.0)
				Phase.SIT:
					facing = 1.0
