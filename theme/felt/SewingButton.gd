## SewingButton.gd
## Round felt button: a disc with a bottom lip, stitched ring and an SVG icon.
## With no lip or inner shade it doubles as a stat badge. Alert draws a warning
## ring around it (used when the stat it fixes is critical). ring_fill below 1
## turns the stitched ring into a gauge: stitched clockwise from the top up to that
## fraction, the rest left as faint stitches.
@tool
extends BaseButton

const FeltDraw := preload("res://theme/felt/FeltDraw.gd")

@export var color := Color("d27449"):
	set(v):
		color = v
		queue_redraw()
@export var diameter := 62.0:
	set(v):
		diameter = v
		custom_minimum_size = Vector2(v, v)
		queue_redraw()
@export_file("*.svg") var icon_path := "":
	set(v):
		icon_path = v
		_icon = FeltDraw.svg_texture(v) if v != "" else null
		queue_redraw()
@export var icon_color := Color("fff7ec"):
	set(v):
		icon_color = v
		queue_redraw()
@export var icon_size := 26.0:
	set(v):
		icon_size = v
		queue_redraw()
@export_group("Stitch")
@export var ring_color := Color(1.0, 0.97, 0.925, 0.75):
	set(v):
		ring_color = v
		queue_redraw()
@export var ring_inset := 5.0:
	set(v):
		ring_inset = v
		queue_redraw()
@export var ring_width := 2.0:
	set(v):
		ring_width = v
		queue_redraw()
@export var ring_dash := 5.0:
	set(v):
		ring_dash = v
		queue_redraw()
@export var ring_gap := 4.0:
	set(v):
		ring_gap = v
		queue_redraw()
@export_range(0.0, 1.0) var ring_fill := 1.0:
	set(v):
		v = clampf(v, 0.0, 1.0)
		if absf(v - ring_fill) < 0.002:
			return
		ring_fill = v
		queue_redraw()
@export var ring_empty_alpha := 0.28
@export_group("Depth")
@export var lip := 3.0:
	set(v):
		lip = v
		queue_redraw()
@export var lip_color := Color(0, 0, 0, 0.18):
	set(v):
		lip_color = v
		queue_redraw()
@export var inner_shade := true:
	set(v):
		inner_shade = v
		queue_redraw()
@export_group("Alert")
@export var alert := false:
	set(v):
		alert = v
		queue_redraw()
@export var alert_color := Color("c4453a")
@export var alert_gap_color := Color("f7eddd")

var _icon: Texture2D


func _ready() -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	focus_mode = Control.FOCUS_NONE
	if icon_path != "" and _icon == null:
		_icon = FeltDraw.svg_texture(icon_path)


func _draw() -> void:
	var c := size * 0.5
	var r := diameter * 0.5
	var mode := get_draw_mode()
	var down := (mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED) and lip > 0.0
	var off := Vector2(0, lip * 0.6) if down else Vector2.ZERO
	var fade := 0.55 if disabled else 1.0

	if alert and not disabled:
		draw_arc(c, r + 2.0, 0.0, TAU, 64, alert_gap_color, 4.0, true)
		draw_arc(c, r + 5.0, 0.0, TAU, 64, alert_color, 2.0, true)
	if lip > 0.0 and not down:
		draw_circle(c + Vector2(0, lip), r, _faded(lip_color, fade), true, -1.0, true)
	draw_circle(c + off, r, _faded(color, fade), true, -1.0, true)
	if inner_shade:
		var body := FeltDraw.ellipse(c + off, Vector2(r, r), 48)
		var raised := FeltDraw.ellipse(c + off + Vector2(0, -3), Vector2(r, r), 48)
		for poly in Geometry2D.clip_polygons(body, raised):
			draw_colored_polygon(poly, Color(0, 0, 0, 0.12 * fade))

	var rr := r - ring_inset - ring_width * 0.5
	if ring_width > 0.0 and rr > 0.0:
		if ring_fill >= 1.0:
			FeltDraw.draw_dashes(self, FeltDraw.ellipse(c + off, Vector2(rr, rr), 48), true,
					_faded(ring_color, fade), ring_width, ring_dash, ring_gap)
		else:
			var split := -PI * 0.5 + TAU * ring_fill
			var empty := _faded(ring_color, fade * ring_empty_alpha)
			FeltDraw.draw_dashes(self, _arc(c + off, rr, split, -PI * 0.5 + TAU), false, empty,
					ring_width, ring_dash, ring_gap)
			if ring_fill > 0.0:
				FeltDraw.draw_dashes(self, _arc(c + off, rr, -PI * 0.5, split), false,
						_faded(ring_color, fade), ring_width, ring_dash, ring_gap)
	if _icon:
		var s := Vector2(icon_size, icon_size)
		draw_texture_rect(_icon, Rect2(c + off - s * 0.5, s), false, _faded(icon_color, fade))


func _arc(center: Vector2, radius: float, from: float, to: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := maxi(2, ceili(48.0 * (to - from) / TAU))
	for i in steps + 1:
		pts.append(center + Vector2.from_angle(lerpf(from, to, float(i) / steps)) * radius)
	return pts


func _faded(col: Color, fade: float) -> Color:
	return Color(col.r, col.g, col.b, col.a * fade)
