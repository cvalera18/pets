## FeatherWand.gd
## The feather wand toy, drawn in felt. You hold it by the handle, like a real
## one: your finger is the felt-wrapped grip, the wooden stick leans toward Mochi,
## and the feather hangs from its tip on a string, swinging as you move and
## settling when you hold still. Mochi hunts the feather (PetPlay).
##
## "Jugar" takes it out; let go and it swings back beside her; it goes away with
## "Guardar", a few seconds untouched, or when she falls asleep. While you hold the
## feather within her reach a ring of stitches appears around it and fills as you
## keep it still (EventBus.hunt_changed): when it's full, she pounces.
## Bored, Mochi brings it herself: it rides crosswise in her mouth
## (EventBus.toy_carried), lands on the floor in front of you (toy_dropped) and
## lies there until you pick it up by touching it, or a while passes.
## Reads the pointer itself while out (mouse events; touches arrive emulated) and
## reports the feather through EventBus.wand_moved.
extends Node2D

const P := preload("res://theme/Palette.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")

const STICK_LEN := 170.0
const STRING_LEN := 60.0
const GRIP_LEN := 46.0
const LEAN := 35.0           # degrees the stick leans toward Mochi from upright
const LEAN_SPAN := 150.0     # px from Mochi at which the lean is full
const GRAVITY := 900.0
const SWING_DAMP := 2.5      # per second; how fast the feather's swing settles
const FEATHERS := [P.ROSE, P.MUSTARD, P.DENIM]
const FEATHER_LEN := 46.0
const FEATHER_WIDTH := 13.0
const HALO_RADIUS := 32.0
const CARRY_ANGLE := -0.08   # radians: the stick crosswise in her mouth, tip a bit up
const CARRY_GRIP := 100.0    # from the grip end to where her teeth hold the stick
const PICK_RADIUS := 36.0

## Where the feather dangles when the wand comes out (Room puts it by Mochi's face).
var rest_point := Vector2.ZERO
## Mochi's x: the stick leans toward her from either side.
var focus_x := 0.0
## Where the wand she brought lies on the floor in front of her.
var floor_y := 0.0

var _active := false
var _held := false
var _handle := Vector2.ZERO
var _handle_goal := Vector2.ZERO
var _angle := -PI * 0.5
var _feather := Vector2.ZERO
var _feather_prev := Vector2.ZERO
var _idle := 0.0
var _clock := 0.0
var _huntable := false
var _hunt_progress := 0.0
var _halo := 0.0
var _carried := false
var _lying := false
var _on_floor := false
var _lie_t := 0.0


func _ready() -> void:
	z_index = 20
	visible = false
	set_process(false)
	EventBus.play_requested.connect(func() -> void: _set_active(not _active))
	EventBus.sleeping_changed.connect(_on_sleeping_changed)
	EventBus.wand_caught.connect(func() -> void: _feather += Vector2(0.0, 14.0))
	EventBus.hunt_changed.connect(_on_hunt_changed)
	EventBus.toy_carried.connect(_on_toy_carried)
	EventBus.toy_dropped.connect(_on_toy_dropped)


func _on_hunt_changed(huntable: bool, progress: float) -> void:
	_huntable = huntable
	_hunt_progress = progress


func _on_sleeping_changed(asleep: bool) -> void:
	if asleep:
		_set_active(false)
		if _lying:
			_put_away()


func _on_toy_carried(mouth: Vector2) -> void:
	if _active:
		return
	if not _carried:
		_carried = true
		_lying = false
		_on_floor = false
		_angle = CARRY_ANGLE
		_handle = _carry_handle(mouth)
		_feather = _tip() + Vector2(0.0, STRING_LEN)
		_feather_prev = _feather
		visible = true
		set_process(true)
	_handle = _carry_handle(mouth)
	_handle_goal = _handle


func _on_toy_dropped() -> void:
	if not _carried:
		return
	_carried = false
	_lying = true
	_on_floor = true
	_lie_t = 0.0
	_handle_goal = Vector2(_handle.x, floor_y)


func _put_away() -> void:
	_lying = false
	_handle_goal = _offscreen(_handle)


func _set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	_held = false
	_idle = 0.0
	if on:
		_handle_goal = _rest_handle()
		# From the floor (or her mouth) it's lifted where it is; otherwise it
		# comes in from the right edge.
		if not (_lying or _carried):
			_handle = _offscreen(_handle_goal)
			_angle = _lean_angle(_handle_goal.x)
			_feather = _tip() + Vector2(0.0, STRING_LEN)
			_feather_prev = _feather
		_carried = false
		_lying = false
		_on_floor = false
		visible = true
		set_process(true)
	else:
		_handle_goal = _offscreen(_handle)
	EventBus.play_mode_changed.emit(on)


func _unhandled_input(event: InputEvent) -> void:
	if _lying and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT 			and event.pressed and _touches_wand(_local(event.position)):
		_set_active(true)
		_held = true
		_handle_goal = _local(event.position)
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_held = event.pressed
		_idle = 0.0
		_handle_goal = _local(event.position) if event.pressed else _rest_handle()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _held:
		_handle_goal = _local(event.position)
		_idle = 0.0
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_clock += delta
	if _active and not _held:
		_idle += delta
		if _idle >= GameConfig.WAND_IDLE_TIMEOUT:
			_set_active(false)
	if _lying:
		_lie_t += delta
		if _lie_t >= GameConfig.TOY_LYING_TIMEOUT:
			_put_away()
	_halo = move_toward(_halo, 1.0 if _active and _held and _huntable else 0.0, delta * 5.0)
	if not _carried:
		var follow := 30.0 if _held else 10.0 if _lying else 6.0
		_handle = _handle.lerp(_handle_goal, 1.0 - exp(-follow * delta))
	_angle = lerp_angle(_angle, _target_angle(), 1.0 - exp(-8.0 * delta))

	# The feather is a damped pendulum on the string (verlet): the string can go
	# slack but never stretch past its length.
	var tip := _tip()
	var swing := (_feather - _feather_prev) * exp(-SWING_DAMP * delta)
	_feather_prev = _feather
	_feather += swing + Vector2(0.0, GRAVITY) * delta * delta
	_feather = tip + (_feather - tip).limit_length(STRING_LEN)
	if _on_floor:
		_feather.y = minf(_feather.y, floor_y + 3.0)

	if _active:
		EventBus.wand_moved.emit(get_global_transform_with_canvas() * _feather, _held)
	elif not (_lying or _carried) and _handle.distance_to(_handle_goal) < 12.0:
		visible = false
		_on_floor = false
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var tip := _tip()
	var dir := Vector2.from_angle(_angle)
	draw_line(_handle, tip, P.HOOP_INNER, 9.0, true)
	draw_line(_handle, tip, P.HOOP_WOOD, 6.0, true)
	draw_circle(tip, 4.5, P.HOOP_WOOD)

	# The grip, where you hold it: rose felt wrapped around the stick.
	var grip_start := _handle - dir * 6.0
	var grip_end := _handle + dir * GRIP_LEN
	draw_line(grip_start, grip_end, P.ROSE.darkened(0.25), 14.0, true)
	draw_line(grip_start, grip_end, P.ROSE, 11.0, true)
	draw_circle(grip_start, 7.0, P.ROSE)
	var across := dir.orthogonal() * 4.5
	for i in 4:
		var p := grip_start.lerp(grip_end, (i + 0.8) / 4.6)
		draw_line(p - across, p + across, P.ROSE.lightened(0.45), 1.5, true)

	draw_line(tip, _feather, P.HOOP_STRING, 2.0, true)
	var hang := (_feather - tip).angle() if _feather.distance_to(tip) > 1.0 else PI * 0.5
	var flutter := sin(_clock * 3.0) * 0.08
	for i in FEATHERS.size():
		_draw_feather(_feather, hang + (i - 1) * 0.49 + flutter, FEATHERS[i])
	draw_circle(_feather, 5.0, P.HOOP_NAIL)
	if _halo > 0.0:
		_draw_halo(_feather + Vector2.from_angle(hang) * FEATHER_LEN * 0.45)


## Around the feather while it's within her reach: faint stitches that get sewn
## clockwise as she stalks, full when she pounces.
func _draw_halo(center: Vector2) -> void:
	var top := -PI * 0.5
	var split := top + TAU * clampf(_hunt_progress, 0.0, 1.0)
	FeltDraw.draw_dashes(self, _arc(center, HALO_RADIUS, split, top + TAU), false,
			Color(P.MUSTARD, 0.35 * _halo), 2.0, 5.0, 4.0)
	if _hunt_progress > 0.0:
		FeltDraw.draw_dashes(self, _arc(center, HALO_RADIUS, top, split), false,
				Color(P.MUSTARD, _halo), 3.0, 5.0, 4.0)


func _arc(center: Vector2, radius: float, from: float, to: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := maxi(2, ceili(48.0 * (to - from) / TAU))
	for i in steps + 1:
		pts.append(center + Vector2.from_angle(lerpf(from, to, float(i) / steps)) * radius)
	return pts


## A felt feather: a leaf-shaped cut-out hanging from `base`, with a stitched vein.
func _draw_feather(base: Vector2, angle: float, color: Color) -> void:
	var dir := Vector2.from_angle(angle)
	var side := dir.orthogonal()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		var w := pow(sin(PI * t), 0.8) * FEATHER_WIDTH * 0.5
		var c := base + dir * FEATHER_LEN * t
		left.append(c + side * w)
		right.append(c - side * w)
	right.reverse()
	FeltDraw.fill(self, left + right, color)
	FeltDraw.draw_dashes(self, PackedVector2Array([base + dir * 6.0, base + dir * (FEATHER_LEN - 6.0)]),
			false, color.lightened(0.4), 1.5, 4.0, 3.0)


func _tip() -> Vector2:
	return _handle + Vector2.from_angle(_angle) * STICK_LEN


## Held out while playing, crosswise in her mouth, flat on the floor; on its way
## out it keeps whatever angle it had.
func _target_angle() -> float:
	if _active:
		return _lean_angle(_handle.x)
	if _carried:
		return CARRY_ANGLE
	if _lying:
		return 0.0
	return _angle


func _carry_handle(mouth: Vector2) -> Vector2:
	return _local(mouth) - Vector2.from_angle(CARRY_ANGLE) * CARRY_GRIP


func _touches_wand(p: Vector2) -> bool:
	var on_stick := Geometry2D.get_closest_point_to_segment(p, _handle, _tip()).distance_to(p) <= PICK_RADIUS
	return on_stick or p.distance_to(_feather) <= PICK_RADIUS


## Upright in front of Mochi, leaning toward her the farther the grip is to her side.
func _lean_angle(handle_x: float) -> float:
	return deg_to_rad(-90.0 - LEAN * clampf((handle_x - focus_x) / LEAN_SPAN, -1.0, 1.0))


## Where to hold the grip so the feather hangs at rest_point, kept on screen.
func _rest_handle() -> Vector2:
	var guess := rest_point - Vector2(0.0, STRING_LEN) - Vector2.from_angle(_lean_angle(rest_point.x + 100.0)) * STICK_LEN
	var size := get_viewport_rect().size
	return Vector2(minf(guess.x, size.x - 24.0), minf(guess.y, size.y - 24.0))


func _offscreen(from: Vector2) -> Vector2:
	return Vector2(get_viewport_rect().size.x + 140.0, from.y)


func _local(screen: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen
