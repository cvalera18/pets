## FeltCushion.gd
## Knitted floor cushion (the pet's spot): a ribbed ellipse filling the control,
## with a soft floor shadow, a sunken lower rim and a stitched inner ring.
@tool
extends Control

const FeltDraw := preload("res://theme/felt/FeltDraw.gd")

@export var color := Color("c98c9a"):
	set(v):
		color = v
		queue_redraw()
@export var stitch_color := Color("f2d3da"):
	set(v):
		stitch_color = v
		queue_redraw()
@export var rib_color := Color(1, 1, 1, 0.14):
	set(v):
		rib_color = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := size * 0.5
	for i in 3:
		FeltDraw.fill(self, FeltDraw.ellipse(c + Vector2(0, 6), r + Vector2.ONE * (8.0 - i * 3.0)),
				Color(0.35, 0.24, 0.12, 0.05))
	var base := FeltDraw.ellipse(c, r, 72)
	FeltDraw.fill(self, base, color)
	var x := 0.0
	while x < size.x:
		var rib := PackedVector2Array([Vector2(x, 0), Vector2(x + 6, 0), Vector2(x + 6, size.y), Vector2(x, size.y)])
		for poly in Geometry2D.intersect_polygons(rib, base):
			draw_colored_polygon(poly, rib_color)
		x += 12.0
	var raised := FeltDraw.ellipse(c + Vector2(0, -7), r, 72)
	for poly in Geometry2D.clip_polygons(base, raised):
		draw_colored_polygon(poly, Color(0, 0, 0, 0.08))
	FeltDraw.draw_dashes(self, FeltDraw.ellipse(c, r - Vector2(10, 9), 72), true, stitch_color, 2.0, 6.0, 5.0)
