## MochiRig.gd
## Mochi as a cutout rig: each SVG piece in assets/mochi/ hangs from a pivot
## Node2D so it can be animated on its own (tail sway, head tilt, blink, ear
## twitch, gaze, flinch). All pieces share the 300×280 design canvas, so a piece's placement
## is just its cropped rect minus its parent's pivot. The node origin sits at
## Mochi's feet, which keeps Pet.gd's breathe/pop scaling grounded.
##
## Pet.gd drives the whole-body motion and calls set_mood() / set_personality(),
## set_torso_lift(), look_at_canvas() / release_look(), flinch(), set_legs(),
## set_lie(), set_rub(), meow() and set_excited(); mouth_screen() tells where to
## hold a toy.
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

# Rubbing: the head sways side to side, leaning toward the finger if there is one.
const RUB_SWING := 0.11
const RUB_LEAN := 0.2
const RUB_HZ := 1.7

const MOUTH := Vector2(97, 121)

# Lying down: the body settles until its belly (y 238) meets the floor, the head
# rests a little lower still and the tail swings down to lie along the floor.
const LIE_DROP := 26.0
const LIE_HEAD_DROP := 8.0
const LIE_TAIL := 100.0
const LIE_TILT := -0.12
const MEOW_TIME := 0.55

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
var _tail_tween: Tween
var _excite := 1.0

var _torso_base := {}
var _leg_base := {}

var _rub_goal := 0.0
var _rub_w := 0.0
var _rub_at := Vector2.INF
var _rub_phase := 0.0
var _meow_t := 0.0
var _lie := 0.0

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
	_apply_face()
	_ear_tilt = 18.0 if mood == 2 else 6.0 if mood == 1 else 0.0
	for t in _flinches:
		t.kill()
	_nodes["EarL"].rotation_degrees = -_ear_tilt
	_nodes["EarR"].rotation_degrees = _ear_tilt
	if not Engine.is_editor_hint():
		_start_idle()


## Leg pose. leap 0..1: front legs reach forward and back legs push back.
## stride -1..1: trotting, the diagonal pairs swinging opposite ways.
## paw 0..1: the far front paw reaches forward and up (pawing at the bowl).
func set_legs(leap: float, stride := 0.0, paw := 0.0) -> void:
	if _nodes.is_empty():
		return
	var swing := 22.0 * stride
	_nodes["LegFF"].rotation_degrees = 35.0 * leap + swing + 72.0 * paw
	_nodes["LegFN"].rotation_degrees = 35.0 * leap - swing
	_nodes["LegBF"].rotation_degrees = -30.0 * leap - swing
	_nodes["LegBN"].rotation_degrees = -30.0 * leap + swing
	# Lying, the legs fold under her: they sink with the body and shorten so the
	# paws stay on the floor, showing as tucked stubs.
	for key in _leg_base:
		_nodes[key].position = _leg_base[key] + Vector2(0.0, LIE_DROP * _lie)
		_nodes[key].scale.y = 1.0 - 0.5 * _lie
	_nodes["LegFF"].position.y -= 16.0 * paw


## Lying down, 0..1 (Pet steps it like the other poses).
func set_lie(k: float) -> void:
	_lie = k
	if not _nodes.is_empty():
		_nodes["TailRest"].rotation_degrees = LIE_TAIL * k


## Rubs her head, weight 0..1 (eased): side to side, leaning toward `at` (a
## design-canvas point such as your finger) when one is given.
func set_rub(weight: float, at := Vector2.INF) -> void:
	_rub_goal = weight
	_rub_at = at


## Opens her mouth for a meow.
func meow(time := MEOW_TIME) -> void:
	_meow_t = time
	_apply_face()


## Her mouth in viewport coordinates, where she holds what she carries.
func mouth_screen() -> Vector2:
	return head_to_screen(MOUTH)


## A design-canvas point on her head, in viewport coordinates: it follows the
## head as it turns, tilts and lowers.
func head_to_screen(c: Vector2) -> Vector2:
	return (_nodes["Head"] as Node2D).get_global_transform_with_canvas() * (c - NECK)


## A design-canvas point, in viewport coordinates.
func canvas_to_screen(c: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * (c - ORIGIN)


## Excitement speeds up the tail (1 = calm); she lashes it while hunting.
func set_excited(k: float) -> void:
	_excite = k
	if _tail_tween:
		_tail_tween.set_speed_scale(k)


## Breathing lift: body, head and tail rise `px` while the legs stay planted
## (lying down, all of them sit lower).
func set_torso_lift(px: float) -> void:
	for key in _torso_base:
		var drop := LIE_DROP * _lie + (LIE_HEAD_DROP * _lie if key == "HeadLook" else 0.0)
		_nodes[key].position = _torso_base[key] - Vector2(0.0, px - drop)


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
	if _meow_t > 0.0:
		_meow_t -= delta
		if _meow_t <= 0.0:
			_apply_face()
	_look_w = move_toward(_look_w, 1.0 if _look_on or _look_linger > 0.0 else 0.0, delta * 3.0)

	var eye_target := Vector2.ZERO
	var head_target := 0.0
	if _look_w > 0.0:
		var d := _look_at - EYES_CENTER
		eye_target = d.normalized() * minf(EYE_TRAVEL, d.length() * 0.05) * _look_w
		head_target = clampf(Vector2.UP.angle_to(_look_at - NECK) * 0.35, -HEAD_TURN, HEAD_TURN) * _look_w
	head_target += LIE_TILT * _lie
	_rub_w = move_toward(_rub_w, _rub_goal, delta * 4.0)
	if _rub_w > 0.0:
		_rub_phase += delta * TAU * RUB_HZ
		var lean := 0.0
		if _rub_at.is_finite():
			lean = clampf(Vector2.UP.angle_to(_rub_at - NECK) * 0.6, -RUB_LEAN, RUB_LEAN)
		head_target = lerpf(head_target, lean + sin(_rub_phase) * RUB_SWING, _rub_w)
	else:
		_rub_phase = 0.0
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


func _apply_face() -> void:
	if _nodes.is_empty():
		return
	var shown: Array = FACES.get(_mood, FACES[0])
	var meowing := _meow_t > 0.0
	for p in FACE_PIECES:
		(_nodes[p] as CanvasItem).visible = p in shown and not (meowing and p.begins_with("mouth_"))
	(_nodes["mouth_miau"] as CanvasItem).visible = meowing


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

	# Tail carries the idle sway, TailRest lying down and TailFlick the flinch.
	var tail := _pivot(felt, "Tail", Vector2(230, 156))
	var tail_rest := _pivot(tail, "TailRest", Vector2(230, 156))
	_piece(_pivot(tail_rest, "TailFlick", Vector2(230, 156)), "tail")
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
			"mouth_feliz", "mouth_dormida", "mouth_triste", "mouth_miau", "snout"]:
		_piece(head, p)
	_nodes["mouth_miau"].visible = false
	for key in ["body", "Tail", "HeadLook"]:
		_torso_base[key] = _nodes[key].position
	for key in ["LegFF", "LegFN", "LegBF", "LegBN"]:
		_leg_base[key] = _nodes[key].position


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

	_tail_tween = null
	if _mood != 1:
		_nodes["Tail"].rotation_degrees = -6.0
		_loop([["Tail", "rotation_degrees", 7.0, 1.3], ["Tail", "rotation_degrees", -6.0, 1.3]])
		_tail_tween = _idle.back()
		_tail_tween.set_speed_scale(_excite)
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
