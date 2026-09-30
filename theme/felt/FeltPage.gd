## FeltPage.gd
## A notebook page: card-colored paper with soft ruled lines, its top-left corner
## square where the active tab joins it.
@tool
extends Control

const P := preload("res://theme/Palette.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")

@export var radius := 18.0:
	set(v):
		radius = v
		queue_redraw()
@export var line_every := 34.0:
	set(v):
		line_every = v
		queue_redraw()


func _draw() -> void:
	var shape := FeltDraw.rounded_rect(Rect2(Vector2.ZERO, size), radius)
	# Square the top-left corner.
	var corner := PackedVector2Array([Vector2.ZERO, Vector2(radius, 0), Vector2(radius, radius), Vector2(0, radius)])
	var merged := Geometry2D.merge_polygons(shape, corner)
	FeltDraw.fill(self, merged[0] if merged.size() > 0 else shape, P.CARD)
	var y := line_every
	while y < size.y - 12.0:
		draw_line(Vector2(12, y), Vector2(size.x - 12, y), Color(P.SEAM_SOFT, 0.75), 1.0)
		y += line_every
