## JournalScale.gd
## One side of Mochi's temperament in the Libreta: a stitched line with a felt
## sewing button where she is. Until you've seen enough, the button is a stitched
## question mark in the middle and a row of dots shows how close you are.
@tool
extends Control

const P := preload("res://theme/Palette.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")
const FeltPicto := preload("res://theme/felt/FeltPicto.gd")
const JournalData := preload("res://resources/JournalData.gd")

const BUTTON := 13.0
const TRACK_Y := 13.0

@export_range(-1.0, 1.0) var value := 0.0:
	set(v):
		value = v
		queue_redraw()
@export var known := false:
	set(v):
		known = v
		queue_redraw()
@export_range(0, 3) var signs := 0:
	set(v):
		signs = v
		queue_redraw()
@export var color := P.MUSTARD:
	set(v):
		color = v
		queue_redraw()


func _draw() -> void:
	var line := PackedVector2Array([Vector2(2, TRACK_Y), Vector2(size.x - 2, TRACK_Y)])
	if known:
		FeltDraw.draw_dashes(self, line, false, P.TRACK_STITCH, 2.0, 6.0, 4.0)
		var c := Vector2(lerpf(BUTTON, size.x - BUTTON, (value + 1.0) * 0.5), TRACK_Y)
		draw_circle(c + Vector2(0, 2), BUTTON, Color(0.47, 0.35, 0.24, 0.3))
		draw_circle(c, BUTTON, color)
		FeltDraw.draw_dashes(self, FeltDraw.ellipse(c, Vector2.ONE * 9.0, 28), true, Color(P.ON_ACCENT, 0.8), 1.2, 2.5, 2.0)
		for hole in [Vector2(-2.5, -2.5), Vector2(2.5, -2.5), Vector2(-2.5, 2.5), Vector2(2.5, 2.5)]:
			draw_circle(c + hole, 1.6, color.darkened(0.3))
		return
	FeltDraw.draw_dashes(self, line, false, Color(P.TRACK_STITCH, 0.45), 2.0, 6.0, 4.0)
	var mid := Vector2(size.x * 0.5, TRACK_Y)
	draw_circle(mid, BUTTON, P.CARD)
	FeltPicto.draw_picto(self, "incognita", mid, 26.0)
	for i in JournalData.SIGNS_TO_KNOW:
		var dot := Vector2(6.0 + 14.0 * i, TRACK_Y + 24.0)
		if i < signs:
			draw_circle(dot, 4.5, P.TRACK_STITCH)
		else:
			FeltDraw.draw_dashes(self, FeltDraw.ellipse(dot, Vector2.ONE * 4.0, 12), true, P.TRACK_STITCH, 1.4, 2.0, 1.5)
