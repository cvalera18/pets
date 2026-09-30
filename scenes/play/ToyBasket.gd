## ToyBasket.gd
## A woven felt basket on the floor to Mochi's right, where her toys live. The
## feather wand pokes out of it while it's stored (EventBus.wand_stored). Tapping
## the basket opens the toys tray (EventBus.tray_requested); with the wand out,
## the HUD puts it back instead.
extends Node2D

const P := preload("res://theme/Palette.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")

const TAP_SLOP := 14.0
const FEATHERS := [P.ROSE, P.MUSTARD, P.DENIM]

var _stored := true
var _press := Vector2.INF


func _ready() -> void:
	EventBus.wand_stored.connect(_on_wand_stored)


func _on_wand_stored(stored: bool) -> void:
	_stored = stored
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var hit := Rect2(-38.0, -92.0, 76.0, 100.0).has_point(get_global_transform_with_canvas().affine_inverse() * event.position)
	if event.pressed:
		_press = event.position if hit else Vector2.INF
		if hit:
			get_viewport().set_input_as_handled()
	elif _press != Vector2.INF:
		if hit and event.position.distance_to(_press) < TAP_SLOP:
			EventBus.tray_requested.emit("toys")
		_press = Vector2.INF
		get_viewport().set_input_as_handled()


func _draw() -> void:
	FeltDraw.fill(self, FeltDraw.ellipse(Vector2(0, 3), Vector2(36, 6), 32), Color(P.HOOP_NAIL, 0.25))
	if _stored:
		# The wand stands in the basket grip up, its feathers spilling over the rim.
		draw_line(Vector2(-6, -30), Vector2(-24, -80), P.HOOP_INNER, 8.0, true)
		draw_line(Vector2(-6, -30), Vector2(-24, -80), P.HOOP_WOOD, 5.0, true)
		draw_line(Vector2(-19, -66), Vector2(-26, -86), P.ROSE.darkened(0.25), 12.0, true)
		draw_line(Vector2(-19, -66), Vector2(-26, -86), P.ROSE, 9.0, true)
		for i in FEATHERS.size():
			var dir := Vector2.from_angle(deg_to_rad(-60.0 + 25.0 * i))
			var pts := Transform2D(dir.angle(), Vector2(14, -34) + dir * 11.0) * FeltDraw.ellipse(Vector2.ZERO, Vector2(11, 4), 20)
			FeltDraw.fill(self, pts, FEATHERS[i])
	FeltDraw.fill(self, PackedVector2Array([Vector2(-32, -34), Vector2(32, -34), Vector2(25, 2), Vector2(-25, 2)]), P.HOOP_WOOD)
	for row in [[-22.0, 29.6], [-10.0, 27.3]]:
		FeltDraw.draw_dashes(self, PackedVector2Array([Vector2(-row[1], row[0]), Vector2(row[1], row[0])]), false,
				P.HOOP_INNER, 2.0, 5.0, 3.0)
	FeltDraw.fill(self, FeltDraw.ellipse(Vector2(0, -34), Vector2(33, 6), 40), P.HOOP_INNER)
	FeltDraw.draw_dashes(self, FeltDraw.ellipse(Vector2(0, -34), Vector2(27, 3.5), 40), true, P.MOON, 1.4, 4.0, 3.0)
