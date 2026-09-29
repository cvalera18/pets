## FeltHoop.gd
## Embroidery hoop hanging on the wall: an embroidered sun and cloud by day, a
## moon and stars by night. Draws inside a 70×84 box (nail and string on top).
@tool
extends Control

const FeltDraw := preload("res://theme/felt/FeltDraw.gd")
const P := preload("res://theme/Palette.gd")
const TimeTint := preload("res://scenes/effects/TimeTint.gd")

@export var night := false:
	set(v):
		night = v
		queue_redraw()
## At runtime, embroider the moon after dark instead of using `night`.
@export var follow_clock := false

var _timer := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(70, 84)


func _ready() -> void:
	if follow_clock and not Engine.is_editor_hint():
		night = TimeTint.phase() == TimeTint.Phase.NIGHT


func _process(delta: float) -> void:
	if not follow_clock or Engine.is_editor_hint():
		return
	_timer += delta
	if _timer >= TimeTint.UPDATE_INTERVAL:
		_timer = 0.0
		night = TimeTint.phase() == TimeTint.Phase.NIGHT


func _draw() -> void:
	var c := Vector2(35, 49)
	draw_line(Vector2(35, 4), Vector2(35, 16), P.HOOP_STRING, 2.0, true)
	draw_circle(Vector2(35, 4), 4.0, P.HOOP_NAIL, true, -1.0, true)
	for i in 3:
		draw_circle(c + Vector2(0, 4), 38.0 - i * 1.5, Color(P.SHADOW, 0.06), true, -1.0, true)
	draw_circle(c, 35.0, P.HOOP_WOOD, true, -1.0, true)
	draw_circle(c, 30.0, P.HOOP_FABRIC, true, -1.0, true)
	draw_arc(c, 29.25, 0.0, TAU, 64, P.HOOP_INNER, 1.5, true)
	draw_rect(Rect2(30, 10, 10, 9), P.HOOP_INNER)

	if night:
		draw_circle(Vector2(28, 38), 13.0, P.MOON, true, -1.0, true)
		draw_circle(Vector2(35, 32), 12.0, P.HOOP_FABRIC, true, -1.0, true)
		for s in [Vector2(46, 42), Vector2(33, 57), Vector2(51, 27)]:
			draw_circle(s, 1.8, P.SUN_RING, true, -1.0, true)
	else:
		FeltDraw.draw_dashes(self, FeltDraw.ellipse(Vector2(26, 41), Vector2(11.25, 11.25), 40), true,
				P.SUN_RING, 1.5, 3.5, 3.0)
		draw_circle(Vector2(26, 41), 7.0, P.SUN, true, -1.0, true)
		FeltDraw.fill(self, FeltDraw.rounded_rect(Rect2(29, 53, 30, 13), 6.5), Color.WHITE)
		FeltDraw.draw_dashes(self, FeltDraw.rounded_rect(Rect2(29.75, 53.75, 28.5, 11.5), 5.75), true,
				P.CLOUD_STITCH, 1.5, 3.5, 3.0)
