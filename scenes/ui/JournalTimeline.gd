## JournalTimeline.gd
## The rows of "Su día" in the Libreta, threaded by a stitched line behind their
## doodles.
@tool
extends VBoxContainer

const P := preload("res://theme/Palette.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")

## x of the thread, where the doodles sit.
@export var thread_x := 82.0:
	set(v):
		thread_x = v
		queue_redraw()


func _draw() -> void:
	FeltDraw.draw_dashes(self, PackedVector2Array([Vector2(thread_x, 20), Vector2(thread_x, size.y - 20)]), false,
			Color(P.TRACK_STITCH, 0.6), 2.0, 5.0, 5.0)
