## FeltSeam.gd
## A stitched line across the control's width (floor seams, dividers, underlines).
@tool
extends Control

@export var color := Color("c2a782"):
	set(v):
		color = v
		queue_redraw()
@export var width := 2.0:
	set(v):
		width = v
		queue_redraw()
@export var dash := 6.0:
	set(v):
		dash = v
		queue_redraw()
@export var gap := 5.0:
	set(v):
		gap = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var y := size.y * 0.5
	var x := 0.0
	while x < size.x:
		draw_line(Vector2(x, y), Vector2(minf(x + dash, size.x), y), color, width, true)
		x += dash + gap
