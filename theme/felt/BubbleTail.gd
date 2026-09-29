## BubbleTail.gd
## The two little felt dots that trail a thought bubble toward the pet's head.
## Draws a big dot at the top-right of the control and a small one bottom-left.
@tool
extends Control

@export var color := Color("fbf4e6"):
	set(v):
		color = v
		queue_redraw()
@export var lip_color := Color(0.47, 0.35, 0.24, 0.25)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(22, 28)


func _draw() -> void:
	for d in [[Vector2(size.x - 7.0, 7.0), 7.0], [Vector2(4.5, size.y - 4.5), 4.5]]:
		draw_circle(d[0] + Vector2(0, 2), d[1], lip_color, true, -1.0, true)
		draw_circle(d[0], d[1], color, true, -1.0, true)
