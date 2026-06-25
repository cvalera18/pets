## CozyRoom.gd
## The redesigned room backdrop (replaces the flat AmbientSky). A warm pastel
## room — gradient wall, window with sun & drifting clouds, framed picture,
## curved floor, layered rug and a potted plant — plus a time-of-day tint.
##
## Built in code from Control nodes (gradients via GradientTexture2D, rounded
## shapes via StyleBoxFlat panels) so it needs zero art assets and matches the
## design's exact colors. Lives behind everything in the Room; ignores input.
##
## NOTE: laid out for the 390×844 portrait base. Bottom props are anchored to the
## bottom so they survive taller viewports.
class_name CozyRoom
extends Control

const P := preload("res://theme/Palette.gd")
const UPDATE_INTERVAL: float = 60.0

var _tint: ColorRect
var _timer: float = 0.0
var _clouds: Array[Control] = []
var _cloud_t: float = 0.0


func _ready() -> void:
	z_index = -100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)
	_build()
	_apply_time_tint()


func _process(delta: float) -> void:
	# Gentle cloud drift.
	_cloud_t += delta
	for i in _clouds.size():
		var c := _clouds[i]
		c.position.x = c.get_meta("base_x") + sin(_cloud_t * 0.5 + i) * 4.0

	_timer += delta
	if _timer >= UPDATE_INTERVAL:
		_timer = 0.0
		_apply_time_tint()


func _fit_viewport() -> void:
	# A Control under a Node2D doesn't auto-anchor — size it explicitly.
	position = Vector2.ZERO
	size = get_viewport_rect().size


# ─── Construction ─────────────────────────────────────────────────────────────

func _build() -> void:
	var w := size.x
	var h := size.y

	# Wall gradient + warm vignette.
	_grad(Vector2.ZERO, size, P.BG_TOP, P.BG_BOTTOM, true)
	_grad(Vector2.ZERO, size, Color(1, 0.96, 0.91, 0.55), Color(1, 0.96, 0.91, 0.0), true, true)

	# ── Floor (gentle domed top, extends past the bottom edge) ──
	var floor_h := 184.0
	_round(Vector2(-30, h - floor_h), Vector2(w + 60, floor_h + 60), P.FLOOR_A, 64)
	# warm highlight strip along the floor line
	_round(Vector2(-30, h - floor_h - 6), Vector2(w + 60, 22), Color(1, 0.96, 0.9, 0.4), 11)
	# soft FLOOR_A→FLOOR_B vertical shading over the floor body (keeps the domed top)
	_grad(Vector2(-30, h - floor_h + 24), Vector2(w + 60, floor_h + 36),
			Color(P.FLOOR_B, 0.0), Color(P.FLOOR_B, 0.75), true)

	# ── Rug (three stacked stadiums) ──
	_round(Vector2(w / 2 - 120, h - 170), Vector2(240, 74), P.RUG_1, 37)
	_round(Vector2(w / 2 - 94,  h - 160), Vector2(188, 56), P.RUG_2, 28)
	_round(Vector2(w / 2 - 64,  h - 150), Vector2(128, 38), P.RUG_3, 19)

	# ── Framed picture (top-left) ──
	var pic := _round(Vector2(28, 96), Vector2(74, 60), P.WINDOW_FRAME, 12)
	_add_shadow(pic, 6, 4)
	_grad_child(pic, Vector2(7, 7), Vector2(60, 46), P.PICTURE_A, P.PICTURE_B, true, false, 7)
	_round_child(pic, Vector2(15, 13), Vector2(12, 12), P.SUN_A, 6)

	# ── Window (top-right) ──
	var win := _round(Vector2(w - 144, 78), Vector2(118, 146), P.WINDOW_FRAME, 18)
	var sky := _grad_child(win, Vector2(9, 9), Vector2(100, 128), P.SKY_B, P.SKY_A, true, false, 12)
	# soft sun glow halo behind the sun
	_grad_child(sky, Vector2(6, 10), Vector2(50, 50), Color(P.SUN_A, 0.65), Color(P.SUN_A, 0.0), false, true)
	_grad_child(sky, Vector2(14, 18), Vector2(34, 34), P.SUN_A, P.SUN_B, false, true, 17)
	_cloud(sky, Vector2(50, 46), Vector2(46, 18))
	_cloud(sky, Vector2(60, 32), Vector2(30, 14))
	# muntins
	_round_child(win, Vector2(57, 9), Vector2(4, 128), P.WINDOW_FRAME, 2)
	_round_child(win, Vector2(9, 71), Vector2(100, 4), P.WINDOW_FRAME, 2)
	_add_shadow(win, 8, 5)

	# ── Potted plant (bottom-left) ──
	var pot := _round(Vector2(38, h - 96), Vector2(26, 34), P.POT_B, 8)
	_add_shadow(pot, 5, 3)
	_round(Vector2(35, h - 66), Vector2(32, 8), P.POT_B, 5)
	_leaf(Vector2(30, h - 100), Vector2(20, 42), -22.0)
	_leaf(Vector2(42, h - 104), Vector2(20, 48), 0.0)
	_leaf(Vector2(52, h - 100), Vector2(20, 42), 22.0)

	# ── Time-of-day tint (added last so it's on top) ──
	_tint = ColorRect.new()
	_tint.color = Color(0, 0, 0, 0)
	_tint.position = Vector2.ZERO
	_tint.size = size
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _grad(pos: Vector2, sz: Vector2, c1: Color, c2: Color, vertical: bool, radial: bool = false) -> TextureRect:
	return _grad_child(self, pos, sz, c1, c2, vertical, radial)


func _grad_child(parent: Control, pos: Vector2, sz: Vector2, c1: Color, c2: Color,
		vertical: bool, radial: bool = false, _corner: int = 0) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, c1)
	g.set_color(1, c2)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = maxi(2, int(sz.x))
	tex.height = maxi(2, int(sz.y))
	if radial:
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
	else:
		tex.fill_from = Vector2(0, 0)
		tex.fill_to = (Vector2(0, 1) if vertical else Vector2(1, 0))
	var rect := TextureRect.new()
	rect.texture = tex
	rect.position = pos
	rect.size = sz
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _round(pos: Vector2, sz: Vector2, color: Color, radius: int) -> Panel:
	return _round_child(self, pos, sz, color, radius)


func _round_child(parent: Control, pos: Vector2, sz: Vector2, color: Color, radius: int) -> Panel:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _add_shadow(panel: Panel, sz: int, oy: float) -> void:
	var sb := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.shadow_color = Color(0.55, 0.36, 0.22, 0.16)
		sb.shadow_size = sz
		sb.shadow_offset = Vector2(0, oy)


func _cloud(parent: Control, pos: Vector2, sz: Vector2) -> void:
	var c := _round_child(parent, pos, sz, Color(1, 1, 1, 0.9), int(sz.y / 2.0))
	c.set_meta("base_x", pos.x)
	_clouds.append(c)


func _leaf(pos: Vector2, sz: Vector2, deg: float) -> void:
	var leaf := _round(pos, sz, P.LEAF_A, int(sz.x / 2.0))
	leaf.pivot_offset = Vector2(sz.x / 2.0, sz.y)
	leaf.rotation_degrees = deg


func _apply_time_tint() -> void:
	if _tint == null:
		return
	var hour: int = Time.get_time_dict_from_system().get("hour", 12)
	if hour < 5 or hour >= 20:
		_tint.color = P.TINT_NIGHT
	elif hour >= 17:
		_tint.color = P.TINT_DUSK
	else:
		_tint.color = Color(0, 0, 0, 0)
