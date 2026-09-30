## FeltBook.gd
## The cover of a felt notebook (the Libreta de Mochi): sage felt with a stitched
## seam, a darker spine down the left with thread crossings, a lip and a shadow.
## Its pages and tabs go on top as children.
@tool
extends Control

const P := preload("res://theme/Palette.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")

@export var radius := 26.0:
	set(v):
		radius = v
		queue_redraw()
@export var spine := 30.0:
	set(v):
		spine = v
		queue_redraw()
@export var crossing_every := 80.0:
	set(v):
		crossing_every = v
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	FeltDraw.fill(self, FeltDraw.rounded_rect(Rect2(Vector2(0, 8), size), radius), Color(0.16, 0.12, 0.08, 0.22))
	FeltDraw.fill(self, FeltDraw.rounded_rect(Rect2(Vector2(0, 3), size), radius), P.SAGE.darkened(0.2))
	FeltDraw.fill(self, FeltDraw.rounded_rect(rect, radius), P.SAGE_LIGHT)
	var back := FeltDraw.rounded_rect(Rect2(Vector2.ZERO, Vector2(spine + radius, size.y)), radius)
	var cut := PackedVector2Array([Vector2(spine, -1), Vector2(spine + radius + 1, -1),
			Vector2(spine + radius + 1, size.y + 1), Vector2(spine, size.y + 1)])
	for part in Geometry2D.clip_polygons(back, cut):
		FeltDraw.fill(self, part, P.SAGE)
	FeltDraw.draw_dashes(self, FeltDraw.rounded_rect(rect.grow(-7.0), radius - 7.0), true,
			Color(P.ON_ACCENT, 0.55), 2.0, 6.0, 5.0)
	var y := crossing_every * 0.9
	while y < size.y - 20.0:
		draw_line(Vector2(spine * 0.3, y), Vector2(spine * 0.72, y), P.MOON, 3.0, true)
		y += crossing_every
