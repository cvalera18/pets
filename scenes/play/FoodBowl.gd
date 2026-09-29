## FoodBowl.gd
## Mochi's felt food bowl, on the floor beside her. Drop a food from the tray onto
## it to fill it (EventBus.food_dropped → food_served); she eats in her own time,
## one mouthful per EventBus.bowl_bite, and the mound goes down as she does. A new
## food replaces whatever is left.
extends Node2D

const P := preload("res://theme/Palette.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")
const FeltFood := preload("res://theme/felt/FeltFood.gd")

const HALF_W := 42.0
const DEPTH := 26.0
const RIM_H := 9.0
const DROP_RADIUS := 85.0   # generous: a finger dropping food near the bowl counts
const BITES := 3.0

var food := ""
var amount := 0.0
var _pop := 0.0


func _ready() -> void:
	z_index = 5
	set_process(false)
	EventBus.food_dropped.connect(_on_food_dropped)
	EventBus.bowl_bite.connect(_on_bite)


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
	if _pop <= 0.0:
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var bounce := 1.0 + 0.12 * sin(_pop * PI)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(bounce, 2.0 - bounce))
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
