## FoodBowl.gd
## Mochi's felt food bowl, on the floor beside her. Drop a food from the tray onto
## it to fill it (EventBus.food_dropped → food_served); she eats in her own time,
## one mouthful per EventBus.bowl_bite, and the mound goes down as she does. A new
## food replaces whatever is left. When she paws at it asking for food
## (EventBus.bowl_nudged) it rocks on its base. Tapping it opens the food tray,
## and the first time the tray opens it guides the ghost hand to itself.
extends Node2D

const P := preload("res://theme/Palette.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")
const FeltFood := preload("res://theme/felt/FeltFood.gd")

const HALF_W := 42.0
const DEPTH := 26.0
const RIM_H := 9.0
const DROP_RADIUS := 85.0   # generous: a finger dropping food near the bowl counts
const BITES := 3.0
const TAP_SLOP := 14.0

var food := ""
var amount := 0.0
var _pop := 0.0
var _wobble := 0.0
var _press := Vector2.INF


func _ready() -> void:
	z_index = 5
	set_process(false)
	EventBus.food_dropped.connect(_on_food_dropped)
	EventBus.bowl_bite.connect(_on_bite)
	EventBus.bowl_nudged.connect(_on_nudged)
	EventBus.food_hint_wanted.connect(_on_food_hint_wanted)


func _on_food_dropped(which: String, screen_pos: Vector2) -> void:
	var center := get_global_transform_with_canvas() * Vector2(0.0, -DEPTH * 0.5)
	if screen_pos.distance_to(center) > DROP_RADIUS:
		return
	food = which
	amount = 1.0
	_pop = 1.0
	set_process(true)
	EventBus.food_served.emit(which)
	EventBus.bowl_changed.emit(food, amount)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var hit := _hit(get_global_transform_with_canvas().affine_inverse() * event.position)
	if event.pressed:
		_press = event.position if hit else Vector2.INF
		if hit:
			get_viewport().set_input_as_handled()
	elif _press != Vector2.INF:
		if hit and event.position.distance_to(_press) < TAP_SLOP:
			EventBus.tray_requested.emit("food")
		_press = Vector2.INF
		get_viewport().set_input_as_handled()


func _hit(local: Vector2) -> bool:
	return Rect2(-HALF_W - 8.0, -DEPTH - RIM_H - 14.0, HALF_W * 2.0 + 16.0, DEPTH + RIM_H + 22.0).has_point(local)


func _on_food_hint_wanted(slot: Vector2) -> void:
	EventBus.hint_requested.emit("drag", slot, get_global_transform_with_canvas() * Vector2(0.0, -DEPTH))


func _on_nudged() -> void:
	_wobble = 1.0
	set_process(true)


func _on_bite() -> void:
	if food == "":
		return
	amount = maxf(0.0, amount - 1.0 / BITES)
	if amount < 0.01:
		amount = 0.0
		food = ""
	EventBus.bowl_changed.emit(food, amount)
	queue_redraw()


func _process(delta: float) -> void:
	_pop = move_toward(_pop, 0.0, delta * 3.0)
	_wobble = move_toward(_wobble, 0.0, delta * 2.2)
	if _pop <= 0.0 and _wobble <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var bounce := 1.0 + 0.12 * sin(_pop * PI)
	var rock := sin(_wobble * PI * 4.0) * 0.09 * _wobble
	draw_set_transform(Vector2.ZERO, rock, Vector2(bounce, 2.0 - bounce))
	var rim_y := -DEPTH
	FeltDraw.fill(self, FeltDraw.ellipse(Vector2(0, 2), Vector2(HALF_W + 4.0, 7.0)), Color(P.HOOP_NAIL, 0.25))

	var body := PackedVector2Array()
	for i in 17:
		var a := PI * i / 16.0
		body.append(Vector2(cos(a) * HALF_W, rim_y + sin(a) * DEPTH))
	FeltDraw.fill(self, body, P.TERRACOTTA)
	FeltDraw.draw_dashes(self, FeltDraw.ellipse(Vector2(0, rim_y + 13.0), Vector2(HALF_W - 7.0, 8.0), 40).slice(0, 21),
			false, P.RING, 1.5, 4.0, 3.5)
	FeltDraw.fill(self, FeltDraw.ellipse(Vector2(0, rim_y), Vector2(HALF_W, RIM_H)), P.TERRACOTTA_LIP)
	FeltDraw.fill(self, FeltDraw.ellipse(Vector2(0, rim_y + 1.5), Vector2(HALF_W - 5.0, RIM_H - 3.0)), P.TERRACOTTA_DOWN)

	if amount > 0.0:
		var h := 4.0 + 7.0 * amount
		var mound := FeltDraw.ellipse(Vector2(0.0, rim_y - h * 0.4), Vector2((HALF_W - 8.0) * (0.55 + 0.45 * amount), h))
		FeltDraw.fill(self, mound, FeltFood.color_of(food))
		FeltFood.draw_food(self, food, Vector2(-10.0, rim_y - h), 0.42)
		if amount > 0.5:
			FeltFood.draw_food(self, food, Vector2(12.0, rim_y - h * 0.8), 0.36)
	draw_set_transform(Vector2.ZERO)
