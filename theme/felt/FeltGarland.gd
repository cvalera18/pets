## FeltGarland.gd
## Bunting of felt flags hanging from a sagging string across the control.
@tool
extends Control

@export var colors: PackedColorArray = PackedColorArray([
	Color("d27449"), Color("dda843"), Color("6f93b0"), Color("cf8290"), Color("8fa67f"),
]):
	set(v):
		colors = v
		queue_redraw()
@export var flag_count := 7:
	set(v):
		flag_count = v
		queue_redraw()
@export var sag := 25.0:
	set(v):
		sag = v
		queue_redraw()
@export var string_color := Color("a97e55")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _curve_y(x: float) -> float:
	var t := (x + 10.0) / (size.x + 20.0)
	return 16.0 + 4.0 * sag * t * (1.0 - t)


func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 41:
		var x := -10.0 + (size.x + 20.0) * i / 40.0
		pts.append(Vector2(x, _curve_y(x)))
	draw_polyline(pts, string_color, 1.6, true)
	if flag_count <= 0 or colors.is_empty():
		return
	var step := size.x / flag_count
	for i in flag_count:
		var x := step * (i + 0.5)
		var y := _curve_y(x)
		var flag := PackedVector2Array([Vector2(x - 15, y), Vector2(x + 15, y), Vector2(x, y + 28)])
		draw_colored_polygon(flag, colors[i % colors.size()])
		draw_polyline(PackedVector2Array([Vector2(x - 15, y), Vector2(x, y + 28), Vector2(x + 15, y)]),
				colors[i % colors.size()], 1.0, true)
		var sy := y + 4.0
		var sx := x - 9.0
		while sx < x + 9.0:
			draw_line(Vector2(sx, sy), Vector2(minf(sx + 2.5, x + 9.0), sy), Color(1, 0.97, 0.925, 0.7), 1.2, true)
			sx += 4.5
