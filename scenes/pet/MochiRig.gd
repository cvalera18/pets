## MochiRig.gd
## Mochi as a cutout rig: each SVG piece in assets/mochi/ hangs from a pivot
## Node2D so it can be animated on its own (tail sway, head tilt, blink, ear
## twitch, gaze, flinch). All pieces share the 300×280 design canvas, so a piece's placement
## is just its cropped rect minus its parent's pivot. The node origin sits at
## Mochi's feet, which keeps Pet.gd's breathe/pop scaling grounded.
##
## Pet.gd drives the whole-body motion and calls set_mood() / set_personality(),
## set_torso_lift(), look_at_canvas() / release_look() and flinch().
## The contact shadow is a separate FloorShadow node so it can stay on the floor.
## Runs as a tool so the rig also shows in the editor (without idle motion).
@tool
extends Node2D

const FeltDraw := preload("res://theme/felt/FeltDraw.gd")
const FELT_SHADER := preload("res://theme/felt/felt_group.gdshader")
const PIECES_DIR := "res://assets/mochi/"
const RASTER_SCALE := 3.0
## Design-canvas point that lands on the node origin (between the feet).
const ORIGIN := Vector2(150, 262)
const CHEEK_ALPHA := 0.7

# Mirrors Pet.Mood: 0 = idle/happy, 1 = sleep, 2 = sad, 3 = content.
const FACES := {
	0: ["eye_l", "eye_r", "lashes", "mouth_feliz"],
	1: ["eyes_dormida", "mouth_dormida"],
	2: ["face_triste", "mouth_triste"],
	3: ["eyes_contenta", "mouth_feliz"],
}
const FACE_PIECES := ["eye_l", "eye_r", "lashes", "eyes_contenta", "eyes_dormida",
		"face_triste", "mouth_feliz", "mouth_dormida", "mouth_triste"]
const FUR_PIECES := ["tail", "leg_ff", "leg_bf", "body", "leg_fn", "leg_bn", "ear_l", "ear_r", "head"]

# Gaze: the eyes slide and the head turns a little toward what Mochi looks at.
const EYES_CENTER := Vector2(97, 94)
const NECK := Vector2(100, 142)
const EYE_TRAVEL := 3.2
const HEAD_TURN := 0.16
const LOOK_LINGER := 1.0

@export_enum("Feliz:0", "Dormida:1", "Triste:2", "Contenta:3") var preview_mood := 0:
	set(v):
		preview_mood = v
		if is_node_ready():
			set_mood(v)

var _mood := -1
var _nodes := {}
var _idle: Array[Tween] = []
var _flinches: Array[Tween] = []
var _ear_tilt := 0.0

var _torso_base := {}

var _look_at := Vector2.ZERO
var _look_on := false
var _look_linger := 0.0
var _look_w := 0.0
var _eye_off := Vector2.ZERO
var _eye_base := {}


func _ready() -> void:
	_build()
	set_mood(preview_mood)
	set_process(not Engine.is_editor_hint())


func set_mood(mood: int) -> void:
	if mood == _mood or _nodes.is_empty():
		return
	_mood = mood
	var shown: Array = FACES.get(mood, FACES[0])
	for p in FACE_PIECES:
		(_nodes[p] as CanvasItem).visible = p in shown
	_ear_tilt = 18.0 if mood == 2 else 6.0 if mood == 1 else 0.0
	for t in _flinches:
		t.kill()
	_nodes["EarL"].rotation_degrees = -_ear_tilt
	_nodes["EarR"].rotation_degrees = _ear_tilt
	if not Engine.is_editor_hint():
		_start_idle()


## Breathing lift: body, head and tail rise `px` while the legs stay planted.
func set_torso_lift(px: float) -> void:
	for key in _torso_base:
		_nodes[key].position = _torso_base[key] - Vector2(0.0, px)


## Mochi looks toward a point of her 300×280 design canvas (e.g. your finger).
func look_at_canvas(p: Vector2) -> void:
	_look_at = p
	_look_on = true


## Stops following; she keeps looking there a moment before glancing back.
func release_look() -> void:
	if _look_on:
		_look_on = false
		_look_linger = LOOK_LINGER


## Annoyed reaction: ears flatten back and the tail flicks.
func flinch() -> void:
	if _nodes.is_empty():
		return
	for t in _flinches:
		t.kill()
	var ears := create_tween()
	ears.tween_property(_nodes["EarL"], "rotation_degrees", -30.0, 0.08)
	ears.parallel().tween_property(_nodes["EarR"], "rotation_degrees", 30.0, 0.08)
	ears.tween_interval(0.9)
	ears.tween_property(_nodes["EarL"], "rotation_degrees", -_ear_tilt, 0.3)
	ears.parallel().tween_property(_nodes["EarR"], "rotation_degrees", _ear_tilt, 0.3)
	var tail := create_tween()
	for step in [[-24.0, 0.07], [16.0, 0.12], [-8.0, 0.12], [0.0, 0.18]]:
		tail.tween_property(_nodes["TailFlick"], "rotation_degrees", step[0], step[1])
	_flinches = [ears, tail]


func _process(delta: float) -> void:
	if _nodes.is_empty():
		return
	if _look_linger > 0.0:
		_look_linger -= delta
	_look_w = move_toward(_look_w, 1.0 if _look_on or _look_linger > 0.0 else 0.0, delta * 3.0)

	var eye_target := Vector2.ZERO
	var head_target := 0.0
	if _look_w > 0.0:
		var d := _look_at - EYES_CENTER
		eye_target = d.normalized() * minf(EYE_TRAVEL, d.length() * 0.05) * _look_w
		head_target = clampf(Vector2.UP.angle_to(_look_at - NECK) * 0.35, -HEAD_TURN, HEAD_TURN) * _look_w
	_eye_off = _eye_off.lerp(eye_target, 1.0 - exp(-14.0 * delta))
	for key in _eye_base:
		_nodes[key].position = _eye_base[key] + _eye_off
	var look: Node2D = _nodes["HeadLook"]
	look.rotation = lerpf(look.rotation, head_target, 1.0 - exp(-8.0 * delta))


## Applies the active trait's tint (multiply over the fur pieces) and cheek look.
## Called by Pet on EventBus.personality_updated.
func set_personality(profile: Dictionary) -> void:
	var fur: Color = profile.get("fur_mul", Color.WHITE)
	for p in FUR_PIECES:
		(_nodes[p] as CanvasItem).modulate = fur
	var cheek: Color = profile.get("cheek_mul", Color.WHITE)
	cheek.a = clampf(CHEEK_ALPHA + float(profile.get("cheek_alpha_add", 0.0)), 0.0, 1.0)
	var cheek_scale := float(profile.get("cheek_scale", 1.0))
	for key in ["CheekL", "CheekR"]:
		_nodes[key].modulate = cheek
		_nodes[key].scale = Vector2.ONE * cheek_scale


# ─── Construction ─────────────────────────────────────────────────────────────

func _build() -> void:
	if not _nodes.is_empty():
		return
	var root := Node2D.new()
	root.name = "Root"
	root.position = -ORIGIN
	root.set_meta("abs", Vector2.ZERO)
	add_child(root)

	var felt := CanvasGroup.new()
	felt.name = "Felt"
	felt.fit_margin = 12.0
	felt.set_meta("abs", Vector2.ZERO)
	var mat := ShaderMaterial.new()
	mat.shader = FELT_SHADER
	mat.set_shader_parameter("noise", FeltDraw.make_noise(0.5, 7))
	felt.material = mat
	root.add_child(felt)

	var tail := _pivot(felt, "Tail", Vector2(230, 156))
	_piece(_pivot(tail, "TailFlick", Vector2(230, 156)), "tail")
	_piece(_pivot(felt, "LegFF", Vector2(81, 206)), "leg_ff")
	_piece(_pivot(felt, "LegBF", Vector2(192, 206)), "leg_bf")
	_piece(felt, "body")
	_piece(_pivot(felt, "LegFN", Vector2(121, 210)), "leg_fn")
	_piece(_pivot(felt, "LegBN", Vector2(232, 204)), "leg_bn")

	# HeadLook carries the gaze turn so it adds to the idle tween on Head.
	var head := _pivot(_pivot(felt, "HeadLook", NECK), "Head", NECK)
	_piece(head, "collar")
	_piece(_pivot(head, "EarL", Vector2(58, 62)), "ear_l")
	var ear_r := _pivot(head, "EarR", Vector2(138, 60))
	_piece(_pivot(ear_r, "EarTwitch", Vector2(138, 60)), "ear_r")
	_piece(head, "head")
	_piece(_pivot(head, "CheekL", Vector2(44, 116)), "cheek_l")
	_piece(_pivot(head, "CheekR", Vector2(150, 116)), "cheek_r")
	_nodes["CheekL"].modulate.a = CHEEK_ALPHA
	_nodes["CheekR"].modulate.a = CHEEK_ALPHA
	_piece(_pivot(head, "EyeL", Vector2(66, 94)), "eye_l")
	_piece(_pivot(head, "EyeR", Vector2(128, 94)), "eye_r")
	for key in ["EyeL", "EyeR"]:
		_eye_base[key] = _nodes[key].position
	for p in ["lashes", "eyes_contenta", "eyes_dormida", "face_triste",
			"mouth_feliz", "mouth_dormida", "mouth_triste", "snout"]:
		_piece(head, p)
	for key in ["body", "Tail", "HeadLook"]:
		_torso_base[key] = _nodes[key].position


func _pivot(parent: Node, node_name: String, abs_pivot: Vector2) -> Node2D:
	var n := Node2D.new()
	n.name = node_name
	n.position = abs_pivot - (parent.get_meta("abs", Vector2.ZERO) as Vector2)
	n.set_meta("abs", abs_pivot)
	parent.add_child(n)
	_nodes[node_name] = n
	return n


func _piece(parent: Node, piece: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = piece
	s.centered = false
	s.scale = Vector2.ONE / RASTER_SCALE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var img := Image.new()
	var svg := FileAccess.get_file_as_string(PIECES_DIR + piece + ".svg")
	if img.load_svg_from_string(svg, RASTER_SCALE) == OK:
		var used := img.get_used_rect().grow(2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var cropped := img.get_region(used)
		cropped.generate_mipmaps()
		s.texture = ImageTexture.create_from_image(cropped)
		s.position = Vector2(used.position) / RASTER_SCALE - (parent.get_meta("abs", Vector2.ZERO) as Vector2)
	else:
		push_warning("MochiRig: could not rasterize %s" % piece)
	parent.add_child(s)
	_nodes[piece] = s
	return s


# ─── Idle motion ──────────────────────────────────────────────────────────────

func _start_idle() -> void:
	for t in _idle:
		t.kill()
	_idle.clear()
	for key in ["Tail", "Head", "EyeL", "EyeR", "EarTwitch"]:
		_nodes[key].rotation = 0.0
		_nodes[key].scale = Vector2.ONE

	if _mood != 1:
		_nodes["Tail"].rotation_degrees = -6.0
		_loop([["Tail", "rotation_degrees", 7.0, 1.3], ["Tail", "rotation_degrees", -6.0, 1.3]])
		_loop([["Head", "rotation_degrees", -3.5, 1.56], ["Head", "rotation_degrees", 2.0, 1.66],
				["Head", "rotation_degrees", 0.0, 1.98]])
	if _mood == 0 or _mood == 2:
		for eye in ["EyeL", "EyeR"]:
			_loop([[eye, "scale", Vector2.ONE, 4.28], [eye, "scale", Vector2(1, 0.1), 0.14],
					[eye, "scale", Vector2.ONE, 0.18]])
	_loop([["EarTwitch", "rotation_degrees", 0.0, 6.16], ["EarTwitch", "rotation_degrees", -10.0, 0.21],
			["EarTwitch", "rotation_degrees", 4.0, 0.21], ["EarTwitch", "rotation_degrees", 0.0, 0.42]])


func _loop(steps: Array) -> void:
	var t := create_tween().set_loops()
	for s in steps:
		t.tween_property(_nodes[s[0]], s[1], s[2], s[3]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle.append(t)
