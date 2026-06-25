## Mochi.gd
## The pet, drawn procedurally as a cozy cartoon cat (no art assets), matching
## the Claude Design "Mochi" mockup: a round peach blob with pointed ears, blush
## cheeks and a mood-driven face (happy / sleep / sad). Everything is centered on
## the node origin so the procedural breathe/bob/pop scaling stays symmetric.
##
## Used as the Pet's visual ($Sprite). Pet.gd drives the transform and calls
## set_mood() when the mood changes.
class_name Mochi
extends Node2D

# Mirrors Pet.Mood: 0 = idle/happy, 1 = sleep, 2 = sad.
var _mood: int = 0

const FUR_RIM   := Color("efbc8e")
const FUR       := Color("f6cca1")
const FUR_LIGHT := Color("ffe7cd")
const INNER_EAR := Color("edadb4")
const SHEEN     := Color(1, 0.95, 0.86, 0.30)
const CHEEK     := Color(0.94, 0.59, 0.65, 0.55)
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
	_ellipse(Vector2(0, 86), 54, 9, Color(0.47, 0.33, 0.24, 0.16))

	# Pointed ears (drawn first so the body overlaps their base).
	_ear(-1)
	_ear(1)

	# Body blob — rim then fur, all centered.
	_ellipse(Vector2(0, 10), 73, 72, FUR_RIM)
	_ellipse(Vector2(0, 10), 70, 69, FUR)
	# Subtle, CENTERED top sheen (not an off-centre disc).
	_ellipse(Vector2(0, -16), 46, 26, SHEEN)
	# Soft lighter muzzle/face patch the eyes sit on — low-contrast so it blends
	# into the body instead of leaving a visible seam.
	_ellipse(Vector2(0, 27), 47, 40, Color(1.0, 0.94, 0.84, 0.45))

	# Blush cheeks.
	_ellipse(Vector2(-37, 34), 12, 7, CHEEK)
	_ellipse(Vector2(37, 34), 12, 7, CHEEK)

	match _mood:
		1: _face_sleep()
		2: _face_sad()
		_: _face_happy()


# ─── Faces (eyes sit on the muzzle patch, ~y16; mouth ~y38) ───────────────────

func _face_happy() -> void:
	_eye(Vector2(-23, 15))
	_eye(Vector2(23, 15))
	draw_arc(Vector2(0, 34), 11, deg_to_rad(28), deg_to_rad(152), 18, MOUTH, 3.0, true)


func _face_sleep() -> void:
	draw_arc(Vector2(-23, 16), 9, deg_to_rad(20), deg_to_rad(160), 14, DARK, 3.0, true)
	draw_arc(Vector2(23, 16), 9, deg_to_rad(20), deg_to_rad(160), 14, DARK, 3.0, true)
	draw_arc(Vector2(0, 36), 5, 0.0, TAU, 18, MOUTH, 2.5, true)


func _face_sad() -> void:
	# Worried brows: inner ends raised (not angry inner-down).
	draw_line(Vector2(-31, 9), Vector2(-17, 4), DARK, 3.0, true)
	draw_line(Vector2(31, 9), Vector2(17, 4), DARK, 3.0, true)
	_ellipse(Vector2(-23, 18), 6, 8, DARK)
	_ellipse(Vector2(23, 18), 6, 8, DARK)
	draw_arc(Vector2(0, 44), 10, deg_to_rad(205), deg_to_rad(335), 16, MOUTH, 3.0, true)
	_ellipse(Vector2(36, 26), 4, 6, TEAR)


func _eye(c: Vector2) -> void:
	_ellipse(c, 7, 9, DARK)
	draw_circle(c + Vector2(-2.5, -3.0), 2.5, WHITE)


# ─── Shape helpers ────────────────────────────────────────────────────────────

func _ear(side: int) -> void:
	var s := float(side)
	var center := Vector2(34.0 * s, -52.0)
	var rot := deg_to_rad(18.0 * s)
	_ellipse(center, 23, 31, FUR_RIM, rot)
	_ellipse(center, 20, 28, FUR, rot)
	_ellipse(center + Vector2(0, 6).rotated(rot), 11, 16, INNER_EAR, rot)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color, rot: float = 0.0, segs: int = 32) -> void:
	var pts := PackedVector2Array()
	for i in segs:
		var a := TAU * float(i) / float(segs)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	draw_colored_polygon(pts, color)
