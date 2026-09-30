## FeltPicto.gd
## Mochi's pictograms, drawn in felt. She never talks: how she's doing shows as a
## soft doodle in her thought bubble (hambre, jugar, mimos, sueno) — a state, never
## the exact thing she wants, which you find out by caring for her —, how she
## feels pops over her head (enojo, asco, encanta, casi, maulla) and the ghost hand
## (mano) shows the player a gesture. A few UI marks share the set: plumas and
## varita (the toys), costurero (the sewing-kit button), cerrar, and for the
## Libreta: libreta (its button), patita (grooming), corazon (her favorite spot)
## and incognita (something you haven't found out yet).
##
## draw_picto() paints any of them on any CanvasItem, in a 64-unit design box
## scaled to `size`, so the bubble, the effects layer and the ghost hand share
## one drawing.
@tool
extends Control

const P := preload("res://theme/Palette.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")

## Where the ghost hand's fingertip is in the 64-unit box.
const FINGERTIP := Vector2(28, 5)

@export_enum("hambre", "jugar", "mimos", "sueno", "enojo", "asco", "encanta", "casi",
		"maulla", "mano", "plumas", "varita", "costurero", "cerrar", "libreta", "patita",
		"corazon", "incognita") var kind := "hambre":
	set(v):
		kind = v
		queue_redraw()


func _draw() -> void:
	draw_picto(self, kind, size * 0.5, minf(size.x, size.y))


static func draw_picto(ci: CanvasItem, which: String, center: Vector2, size: float) -> void:
	var s := size / 64.0
	var o := center - Vector2(32, 32) * s
	match which:
		"hambre":
			_empty_bowl(ci, o, s)
		"jugar":
			_bounce(ci, o, s)
		"mimos":
			var heart := _heart_points(o + Vector2(32, 34) * s, 24.0 * s)
			FeltDraw.fill(ci, heart, Color(P.ROSE, 0.35))
			FeltDraw.draw_dashes(ci, heart, true, P.ROSE, 2.6 * s, 4.5 * s, 3.5 * s)
		"plumas":
			ci.draw_line(o + Vector2(32, 0) * s, o + Vector2(32, 10) * s, P.HOOP_STRING, 2.0 * s, true)
			_feathers(ci, o + Vector2(32, 10) * s, s, 21.0, 6.5)
		"sueno":
			_moon(ci, o, s)
		"enojo":
			for seg in [[Vector2(27, 11), Vector2(27, 21), Vector2(22, 27), Vector2(11, 27)],
					[Vector2(37, 11), Vector2(37, 21), Vector2(42, 27), Vector2(53, 27)],
					[Vector2(27, 53), Vector2(27, 43), Vector2(22, 37), Vector2(11, 37)],
					[Vector2(37, 53), Vector2(37, 43), Vector2(42, 37), Vector2(53, 37)]]:
				_stroke(ci, _bezier(o, s, seg), P.CRIT, 6.0 * s)
		"asco":
			for x in [14.0, 32.0, 50.0]:
				var y0 := 56.0 if x == 32.0 else 52.0
				var wave: Array[Vector2] = []
				for i in 21:
					var t := i / 20.0
					wave.append(Vector2(x + sin(t * TAU * 1.5) * 4.5, y0 - 40.0 * t))
				_stroke(ci, _map(o, s, wave), P.SAGE, 4.5 * s)
		"encanta":
			_heart(ci, o + Vector2(26, 38) * s, 21.0 * s, P.ROSE)
			FeltDraw.fill(ci, FeltDraw.ellipse(o + Vector2(15, 32) * s, Vector2(3, 4.5) * s, 16), Color(P.ON_ACCENT, 0.6))
			_heart(ci, o + Vector2(50, 17) * s, 11.0 * s, P.ROSE)
		"casi":
			_drop(ci, o, s)
		"maulla":
			for arc in [[Vector2(14, 22), Vector2(23, 32), Vector2(14, 42)],
					[Vector2(27, 15), Vector2(41, 32), Vector2(27, 49)],
					[Vector2(40, 8), Vector2(59, 32), Vector2(40, 56)]]:
				_stroke(ci, _quad(o, s, arc), P.INK_SOFT, 4.5 * s)
		"mano":
			var hand := _map(o, s, _hand_outline())
			FeltDraw.fill(ci, hand, Color(P.ON_ACCENT, 0.8))
			FeltDraw.draw_dashes(ci, hand, true, P.INK_SOFT, 2.2 * s, 4.0 * s, 3.0 * s)
		"varita":
			var grip := o + Vector2(52, 58) * s
			var tip := o + Vector2(20, 10) * s
			ci.draw_line(grip, tip, P.HOOP_INNER, 6.0 * s, true)
			ci.draw_line(grip, tip, P.HOOP_WOOD, 3.5 * s, true)
			ci.draw_line(grip, grip.lerp(tip, 0.28), P.ROSE, 8.0 * s, true)
			ci.draw_line(tip, tip + Vector2(0, 12) * s, P.HOOP_STRING, 1.5 * s, true)
			_feathers(ci, tip + Vector2(0, 12) * s, s, 13.0, 4.2)
		"costurero":
			_spool(ci, o, s)
		"libreta":
			FeltDraw.fill(ci, FeltDraw.rounded_rect(Rect2(o + Vector2(14, 6) * s, Vector2(36, 52) * s), 6.0 * s), P.SAGE_LIGHT)
			FeltDraw.fill(ci, FeltDraw.rounded_rect(Rect2(o + Vector2(14, 6) * s, Vector2(10, 52) * s), 4.0 * s), P.SAGE)
			for y in [14.0, 24.0, 34.0, 44.0]:
				_stroke(ci, _map(o, s, [Vector2(16.5, y), Vector2(21.5, y)]), P.MOON, 2.4 * s)
			FeltDraw.draw_dashes(ci, FeltDraw.rounded_rect(Rect2(o + Vector2(29, 15) * s, Vector2(15, 11) * s), 2.0 * s),
					true, P.CARD, 1.8 * s, 3.0 * s, 2.5 * s)
			FeltDraw.fill(ci, _map(o, s, [Vector2(39, 55), Vector2(46, 55), Vector2(46, 63), Vector2(42.5, 60), Vector2(39, 63)]), P.ROSE)
		"patita":
			FeltDraw.fill(ci, FeltDraw.ellipse(o + Vector2(32, 42) * s, Vector2(14, 11) * s, 32), P.HOOP_INNER)
			for toe in [Vector2(16, 26), Vector2(26, 17), Vector2(38, 17), Vector2(48, 26)]:
				FeltDraw.fill(ci, FeltDraw.ellipse(o + toe * s, Vector2(5.5, 7) * s, 20), P.HOOP_INNER)
		"corazon":
			FeltDraw.fill(ci, _heart_points(o + Vector2(32, 34) * s, 24.0 * s), P.ROSE)
			FeltDraw.draw_dashes(ci, _heart_points(o + Vector2(32, 33) * s, 17.0 * s), true, P.ON_ACCENT, 2.4 * s, 4.0 * s, 3.0 * s)
		"incognita":
			FeltDraw.draw_dashes(ci, FeltDraw.ellipse(o + Vector2(32, 32) * s, Vector2(24, 24) * s, 40), true,
					P.TRACK_STITCH, 2.6 * s, 4.5 * s, 3.5 * s)
			var mark: Array[Vector2] = []
			for p in _bezier_points([Vector2(24, 25), Vector2(24, 13), Vector2(40, 12), Vector2(40, 24)]):
				mark.append(p)
			for p in _bezier_points([Vector2(40, 24), Vector2(40, 30), Vector2(32, 30), Vector2(32, 38)]):
				mark.append(p)
			_stroke(ci, _map(o, s, mark), P.MUTED, 4.5 * s)
			ci.draw_circle(o + Vector2(32, 47) * s, 3.0 * s, P.MUTED)
		"cerrar":
			ci.draw_line(o + Vector2(20, 20) * s, o + Vector2(44, 44) * s, P.INK_SOFT, 6.0 * s, true)
			ci.draw_line(o + Vector2(44, 20) * s, o + Vector2(20, 44) * s, P.INK_SOFT, 6.0 * s, true)
			for p in [Vector2(20, 20), Vector2(44, 44), Vector2(44, 20), Vector2(20, 44)]:
				ci.draw_circle(o + p * s, 3.0 * s, P.INK_SOFT)


# ─── Pieces ───────────────────────────────────────────────────────────────────

## Hungry: an empty bowl, and a little rumble over it.
static func _empty_bowl(ci: CanvasItem, o: Vector2, s: float) -> void:
	var body: Array[Vector2] = []
	for i in 17:
		var a := PI * i / 16.0
		body.append(Vector2(32, 36) + Vector2(cos(a) * 24.0, sin(a) * 17.0))
	FeltDraw.fill(ci, _map(o, s, body), P.TERRACOTTA)
	var seam: Array[Vector2] = []
	for i in 13:
		var a := PI * (0.12 + 0.76 * i / 12.0)
		seam.append(Vector2(32, 41) + Vector2(cos(a) * 17.0, sin(a) * 7.0))
	FeltDraw.draw_dashes(ci, _map(o, s, seam), false, Color(P.ON_ACCENT, 0.75), 1.8 * s, 3.5 * s, 3.0 * s)
	FeltDraw.fill(ci, FeltDraw.ellipse(o + Vector2(32, 36) * s, Vector2(24, 6) * s, 32), P.TERRACOTTA_LIP)
	FeltDraw.fill(ci, FeltDraw.ellipse(o + Vector2(32, 37) * s, Vector2(20, 3.8) * s, 32), P.TERRACOTTA_DOWN)
	var rumble: Array[Vector2] = []
	for i in 25:
		var t := i / 24.0
		rumble.append(Vector2(18.0 + 28.0 * t, 16.0 + sin(t * TAU * 2.0) * 3.0))
	FeltDraw.draw_dashes(ci, _map(o, s, rumble), false, Color(P.INK_SOFT, 0.6), 2.2 * s, 4.0 * s, 3.0 * s)


## Wanting to play: a felt pompom bouncing along a dotted trail.
static func _bounce(ci: CanvasItem, o: Vector2, s: float) -> void:
	for arc in [[Vector2(4, 52), Vector2(15, 12), Vector2(26, 52)], [Vector2(26, 52), Vector2(35, 22), Vector2(44, 46)]]:
		FeltDraw.draw_dashes(ci, _quad(o, s, arc), false, Color(P.INK_SOFT, 0.55), 2.2 * s, 4.0 * s, 3.5 * s)
	var ball := o + Vector2(50, 38) * s
	ci.draw_circle(ball, 11.0 * s, P.MUSTARD)
	FeltDraw.draw_dashes(ci, FeltDraw.ellipse(ball, Vector2(7, 7) * s, 24), true,
			Color(P.ON_ACCENT, 0.8), 1.5 * s, 3.0 * s, 2.5 * s)
	for tick in [[Vector2(47, 54), Vector2(45, 59)], [Vector2(54, 54), Vector2(56, 59)]]:
		_stroke(ci, _map(o, s, tick), Color(P.INK_SOFT, 0.55), 1.8 * s)


## Three felt feathers hanging from a knot, fanned like the wand's.
static func _feathers(ci: CanvasItem, knot: Vector2, s: float, length: float, width: float) -> void:
	var colors := [P.ROSE, P.MUSTARD, P.DENIM]
	for i in 3:
		var dir := Vector2.from_angle(deg_to_rad(62.0 + 28.0 * i))
		var c := knot + dir * length * s
		var pts := Transform2D(dir.angle(), c) * FeltDraw.ellipse(Vector2.ZERO, Vector2(length, width) * s, 24)
		FeltDraw.fill(ci, pts, colors[i])
		FeltDraw.draw_dashes(ci, PackedVector2Array([knot + dir * 0.3 * length * s, knot + dir * 1.7 * length * s]),
				false, Color(P.ON_ACCENT, 0.8), 1.6 * s, 4.0 * s, 3.0 * s)
	ci.draw_circle(knot, 4.5 * s * width / 6.5, P.HOOP_NAIL)


static func _moon(ci: CanvasItem, o: Vector2, s: float) -> void:
	var disc := FeltDraw.ellipse(o + Vector2(27, 36) * s, Vector2(21, 21) * s, 48)
	var bite := FeltDraw.ellipse(o + Vector2(37, 26) * s, Vector2(17, 17) * s, 48)
	for part in Geometry2D.clip_polygons(disc, bite):
		FeltDraw.fill(ci, part, P.MOON)
	var seam := FeltDraw.ellipse(o + Vector2(27, 36) * s, Vector2(15.5, 15.5) * s, 48)
	for part in Geometry2D.clip_polyline_with_polygon(seam + PackedVector2Array([seam[0]]), bite):
		FeltDraw.draw_dashes(ci, part, false, P.SUN_RING, 1.6 * s, 3.5 * s, 3.0 * s)
	_stroke(ci, _map(o, s, [Vector2(43, 6), Vector2(52, 6), Vector2(43, 16), Vector2(52, 16)]), P.ENERGY_TEXT, 3.0 * s)
	_stroke(ci, _map(o, s, [Vector2(53, 22), Vector2(59, 22), Vector2(53, 29), Vector2(59, 29)]), P.ENERGY_TEXT, 2.5 * s)


## A sweat drop: its point up, a round belly below.
static func _drop(ci: CanvasItem, o: Vector2, s: float) -> void:
	var c := Vector2(32, 41)
	var r := 17.0
	var tangent := acos(r / 36.0)
	var pts: Array[Vector2] = [Vector2(32, 5)]
	var from := -PI * 0.5 + tangent
	var to := -PI * 0.5 - tangent + TAU
	for i in 25:
		pts.append(c + Vector2.from_angle(lerpf(from, to, i / 24.0)) * r)
	FeltDraw.fill(ci, _map(o, s, pts), P.CLOUD_STITCH)
	var inner: Array[Vector2] = []
	for i in 13:
		inner.append(c + Vector2.from_angle(lerpf(-0.4, PI * 0.95, i / 12.0)) * (r - 6.0))
	FeltDraw.draw_dashes(ci, _map(o, s, inner), false, P.ON_ACCENT, 1.6 * s, 3.5 * s, 3.0 * s)
	FeltDraw.fill(ci, FeltDraw.ellipse(o + Vector2(24, 40) * s, Vector2(3, 6) * s, 16), Color(P.ON_ACCENT, 0.7))


static func _spool(ci: CanvasItem, o: Vector2, s: float) -> void:
	FeltDraw.fill(ci, FeltDraw.rounded_rect(Rect2(o + Vector2(18, 18) * s, Vector2(28, 28) * s), 2.0 * s), P.TERRACOTTA)
	for y in [24.0, 30.0, 36.0, 42.0]:
		ci.draw_line(o + Vector2(18, y) * s, o + Vector2(46, y) * s, P.TERRACOTTA_LIP, 2.0 * s, true)
	for y in [11.0, 45.0]:
		FeltDraw.fill(ci, FeltDraw.rounded_rect(Rect2(o + Vector2(12, y) * s, Vector2(40, 9) * s), 3.5 * s), P.HOOP_WOOD)
	_stroke(ci, _quad(o, s, [Vector2(46, 30), Vector2(58, 24), Vector2(54, 12)]), P.TERRACOTTA, 2.2 * s)
	ci.draw_line(o + Vector2(60, 5) * s, o + Vector2(46, 59) * s, P.HOOP_NAIL, 3.4 * s, true)
	ci.draw_circle(o + Vector2(58.5, 10.5) * s, 1.2 * s, P.PANEL)


static func _heart(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	FeltDraw.fill(ci, _heart_points(c, r), color)


static func _heart_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * r / 17.0)
	return pts


static func _hand_outline() -> Array[Vector2]:
	var pts: Array[Vector2] = [Vector2(24, 34)]
	_arc(pts, Vector2(28, 9), 4.0, 180.0, 360.0)
	_arc(pts, Vector2(36, 27.5), 4.0, 187.0, 367.0)
	_arc(pts, Vector2(44, 30), 4.1, 194.0, 374.0)
	_arc(pts, Vector2(51.5, 34.5), 3.8, 203.0, 383.0)
	pts.append(Vector2(55, 45))
	for p in _bezier_points([Vector2(55, 45), Vector2(55, 55), Vector2(48, 62), Vector2(39, 62)]):
		pts.append(p)
	for p in _bezier_points([Vector2(35, 62), Vector2(28, 62), Vector2(24, 59), Vector2(21, 54)]):
		pts.append(p)
	pts.append(Vector2(11, 42))
	_arc(pts, Vector2(14, 39.5), 3.9, 140.0, 320.0)
	return pts


# ─── Geometry helpers (64-unit box → canvas) ─────────────────────────────────

static func _map(o: Vector2, s: float, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(o + p * s)
	return out


static func _arc(pts: Array[Vector2], c: Vector2, r: float, from_deg: float, to_deg: float) -> void:
	for i in 9:
		pts.append(c + Vector2.from_angle(deg_to_rad(lerpf(from_deg, to_deg, i / 8.0))) * r)


static func _bezier_points(ctrl: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in 13:
		var t := i / 12.0
		var u := 1.0 - t
		out.append(ctrl[0] * u * u * u + ctrl[1] * 3.0 * u * u * t + ctrl[2] * 3.0 * u * t * t + ctrl[3] * t * t * t)
	return out


static func _bezier(o: Vector2, s: float, ctrl: Array) -> PackedVector2Array:
	return _map(o, s, _bezier_points(ctrl))


static func _quad(o: Vector2, s: float, ctrl: Array) -> PackedVector2Array:
	var pts: Array[Vector2] = []
	for i in 13:
		var t := i / 12.0
		pts.append(ctrl[0].lerp(ctrl[1], t).lerp(ctrl[1].lerp(ctrl[2], t), t))
	return _map(o, s, pts)


## A felt line with round ends.
static func _stroke(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float) -> void:
	ci.draw_polyline(pts, color, width, true)
	ci.draw_circle(pts[0], width * 0.5, color)
	ci.draw_circle(pts[pts.size() - 1], width * 0.5, color)
