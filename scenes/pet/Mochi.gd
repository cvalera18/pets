## Mochi.gd
## The pet, drawn procedurally as a cozy cartoon cat (no art assets), matching
## the Claude Design "Mochi" mockup: a front-facing peach blob with big ears,
## blush cheeks and a mood-driven face (happy / sleep / sad).
##
## Used as the Pet's visual ($Sprite). Pet.gd drives the transform (procedural
## breathe / bob / pop) and calls set_mood() when the mood changes.
class_name Mochi
extends Node2D

# Mirrors Pet.Mood: 0 = idle/happy, 1 = sleep, 2 = sad.
var _mood: int = 0

const FUR_RIM   := Color("efbc8e")
const FUR       := Color("f6cca1")
const FUR_LIGHT := Color("ffead1")
const INNER_EAR := Color("edadb4")
const CHEEK     := Color(0.94, 0.59, 0.65, 0.6)
const DARK      := Color("5a463e")
const MOUTH     := Color("9c6b4e")
const TEAR      := Color("9fd0e8")
const WHITE     := Color("fff8f0")


func set_mood(mood: int) -> void:
	if _mood == mood:
		return
	_mood = mood
	queue_redraw()


func _draw() -> void:
	# Soft contact shadow.
	_ellipse(Vector2(0, 80), 56, 10, Color(0.47, 0.33, 0.24, 0.16))

	# Ears (drawn before the body so the body overlaps their base).
	_ear(-1)
	_ear(1)

	# Body: rim → fur → top-left highlight → belly highlight.
	_ellipse(Vector2(0, 13), 75, 71, FUR_RIM)
	_ellipse(Vector2(0, 13), 72, 68, FUR)
	_ellipse(Vector2(-12, -6), 52, 44, FUR_LIGHT)
	_ellipse(Vector2(0, 33), 40, 32, Color(1, 0.98, 0.93, 0.5))

	# Blush cheeks.
	_ellipse(Vector2(-40, 30), 13, 8, CHEEK)
	_ellipse(Vector2(40, 30), 13, 8, CHEEK)

	match _mood:
		1: _face_sleep()
		2: _face_sad()
		_: _face_happy()


# ─── Faces ────────────────────────────────────────────────────────────────────

func _face_happy() -> void:
	_eye(Vector2(-26, 12))
	_eye(Vector2(26, 12))
	draw_arc(Vector2(0, 30), 12, deg_to_rad(25), deg_to_rad(155), 18, MOUTH, 3.0, true)


func _face_sleep() -> void:
	draw_arc(Vector2(-26, 12), 9, deg_to_rad(20), deg_to_rad(160), 14, DARK, 3.0, true)
	draw_arc(Vector2(26, 12), 9, deg_to_rad(20), deg_to_rad(160), 14, DARK, 3.0, true)
	draw_arc(Vector2(0, 32), 6, 0.0, TAU, 20, MOUTH, 2.5, true)


func _face_sad() -> void:
	# Worried brows.
	draw_line(Vector2(-34, 2), Vector2(-20, 7), DARK, 3.0, true)
	draw_line(Vector2(34, 2), Vector2(20, 7), DARK, 3.0, true)
	_ellipse(Vector2(-26, 15), 6, 8, DARK)
	_ellipse(Vector2(26, 15), 6, 8, DARK)
	# Frown.
	draw_arc(Vector2(0, 40), 11, deg_to_rad(205), deg_to_rad(335), 16, MOUTH, 3.0, true)
	# Tear.
	_ellipse(Vector2(40, 22), 4, 6, TEAR)


func _eye(c: Vector2) -> void:
	_ellipse(c, 7, 9, DARK)
	draw_circle(c + Vector2(-2.5, -3.0), 2.5, WHITE)


# ─── Shape helpers ────────────────────────────────────────────────────────────

func _ear(side: int) -> void:
	var center := Vector2(33.0 * side, -45.0)
	var rot := deg_to_rad(20.0 * side)
	_ellipse(center, 21, 26, FUR_RIM, rot)
	_ellipse(center, 19, 24, FUR, rot)
	_ellipse(center + Vector2(0, 4).rotated(rot), 10, 14, INNER_EAR, rot)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, rot: float = 0.0, segs: int = 32) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var a := TAU * float(i) / float(segs)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, color)
