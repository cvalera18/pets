## FeltRibbons.gd
## Two notched felt ribbon tails, drawn behind a round medal badge.
@tool
extends Control

@export var left_color := Color("d27449"):
	set(v):
		left_color = v
		queue_redraw()
@export var right_color := Color("cf8290"):
	set(v):
		right_color = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size.x * 0.5
	_ribbon(Vector2(c - 9, size.y - 26), 12.0, left_color)
	_ribbon(Vector2(c + 9, size.y - 26), -12.0, right_color)


func _ribbon(top_center: Vector2, deg: float, col: Color) -> void:
	var pts := PackedVector2Array([Vector2(-7, 0), Vector2(7, 0), Vector2(7, 24), Vector2(0, 18.7), Vector2(-7, 24)])
	var xf := Transform2D(deg_to_rad(deg), top_center)
	draw_colored_polygon(xf * pts, col)
