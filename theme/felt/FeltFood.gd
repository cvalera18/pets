## FeltFood.gd
## A food drawn in felt: tuna, chicken, kibble or carrot. A Control on the food
## tray, and draw_food() paints the same food inside the bowl. Once the player has
## discovered Mochi's taste for it, a small badge shows: a rose heart for her
## favorite, a red cross for the one she won't eat.
@tool
extends Control

const P := preload("res://theme/Palette.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")
const DESIGN := 56.0   # drawn for a 56 px box and scaled to fit

@export_enum("tuna", "chicken", "kibble", "carrot") var food := "tuna":
	set(v):
		food = v
		queue_redraw()

## "" while unknown, else "love" | "like" | "dislike".
@export var taste := "":
	set(v):
		taste = v
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y) / DESIGN
	draw_food(self, food, size * 0.5, s)
	var badge := Vector2(size.x * 0.5 + 18.0 * s, size.y * 0.5 - 18.0 * s)
	if taste == "love":
		_draw_heart(badge, 7.0 * s)
	elif taste == "dislike":
		draw_circle(badge, 7.5 * s, P.CARD)
		var d := 3.6 * s
		draw_line(badge + Vector2(-d, -d), badge + Vector2(d, d), P.CRIT, 2.2 * s, true)
		draw_line(badge + Vector2(-d, d), badge + Vector2(d, -d), P.CRIT, 2.2 * s, true)


func _draw_heart(c: Vector2, r: float) -> void:
	draw_circle(c, r + 1.5, P.CARD)
	var pts := PackedVector2Array()
	for i in 24:
		var t := TAU * i / 24.0
		pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * r / 17.0)
	FeltDraw.fill(self, pts, P.ROSE)


## The food's main felt color, for the bowl's mound.
static func color_of(which: String) -> Color:
	match which:
		"tuna":
			return P.CLOUD_STITCH
		"chicken":
			return P.HOOP_WOOD
		"kibble":
			return P.HOOP_INNER
		"carrot":
			return P.TERRACOTTA
	return P.HOOP_WOOD


## Paints `which` centered at `c`, scaled by `s` (1 = a 56 px food).
static func draw_food(ci: CanvasItem, which: String, c: Vector2, s: float) -> void:
	match which:
		"tuna":
			FeltDraw.fill(ci, _poly([Vector2(10, 0), Vector2(22, -10), Vector2(22, 10)], c, s), P.DENIM)
			FeltDraw.fill(ci, _oval(c + Vector2(-4, 0) * s, Vector2(17, 10) * s, 0.0), P.CLOUD_STITCH)
			FeltDraw.draw_dashes(ci, _poly([Vector2(-14, 1), Vector2(-4, 3), Vector2(8, 1)], c, s), false,
					P.CARD, 1.4 * s, 3.0 * s, 2.5 * s)
			ci.draw_circle(c + Vector2(-13, -2) * s, 2.2 * s, P.INK)
		"chicken":
			# The bone gets a brown outline so it reads on the cream tray.
			for pass_color in [P.HOOP_INNER, P.CARD]:
				var grow := 1.6 if pass_color == P.HOOP_INNER else 0.0
				ci.draw_line(c + Vector2(1, 1) * s, c + Vector2(15, 15) * s, pass_color, (5.0 + grow * 2.0) * s, true)
				ci.draw_circle(c + Vector2(18, 13) * s, (3.8 + grow) * s, pass_color)
				ci.draw_circle(c + Vector2(13, 18) * s, (3.8 + grow) * s, pass_color)
			FeltDraw.fill(ci, _oval(c + Vector2(-6, -6) * s, Vector2(13, 11) * s, -0.7), P.HOOP_WOOD)
			FeltDraw.draw_dashes(ci, _oval(c + Vector2(-6, -6) * s, Vector2(8.5, 6.5) * s, -0.7), true,
					P.MOON, 1.4 * s, 3.0 * s, 2.5 * s)
		"kibble":
			for o in [Vector2(-9, 6), Vector2(0, 7), Vector2(9, 6), Vector2(-4, -2), Vector2(5, -2), Vector2(0, -10)]:
				ci.draw_circle(c + o * s, 5.5 * s, P.HOOP_INNER)
				ci.draw_circle(c + (o + Vector2(-1.5, -1.5)) * s, 1.4 * s, P.HOOP_WOOD)
		"carrot":
			for leaf in [-0.5, 0.1, 0.7]:
				FeltDraw.fill(ci, _oval(c + (Vector2(10, -12) + Vector2.from_angle(-PI * 0.5 + leaf) * 7) * s,
						Vector2(3, 7) * s, leaf), P.SAGE)
			FeltDraw.fill(ci, _poly([Vector2(3, -14), Vector2(14, -3), Vector2(-14, 16)], c, s), P.TERRACOTTA)
			for t in [0.3, 0.55]:
				var a := Vector2(3, -14).lerp(Vector2(-14, 16), t)
				var b := Vector2(14, -3).lerp(Vector2(-14, 16), t)
				ci.draw_line(c + a.lerp(b, 0.2) * s, c + a.lerp(b, 0.7) * s, P.TERRACOTTA_LIP, 1.4 * s, true)


static func _poly(points: Array, c: Vector2, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(c + p * s)
	return out


static func _oval(center: Vector2, radii: Vector2, angle: float) -> PackedVector2Array:
	return Transform2D(angle, center) * FeltDraw.ellipse(Vector2.ZERO, radii, 32)
