## EffectsLayer.gd
## Listens for juice/feedback requests on the EventBus and spawns transient
## visual effects (floating text + particle bursts) at the requested world
## position.
##
## Holds NO game logic — pure presentation. It owns no references to the Pet or
## HUD; everything arrives via EventBus signals. Lives as a child of Room.
##
## Particles are little felt cut-outs (hearts, stars, crumbs, sparkles)
## rasterized from inline SVG at runtime, so the system needs zero art files.
class_name EffectsLayer
extends Node2D

const FLOATING_TEXT := preload("res://scenes/effects/FloatingText.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")

const SHAPE_HEART := "M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z"
const SHAPE_STAR := "M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"
const SHAPE_CRUMB := "M12 5a7 7 0 1 1 0 14a7 7 0 1 1 0-14z"
const SHAPE_SPARKLE := "M12 2 L14 10 L22 12 L14 14 L12 22 L10 14 L2 12 L10 10 Z"

## Per-kind burst configuration. Tune freely — shape colors match the stat hues.
const BURSTS := {
	"love":  {"shape": SHAPE_HEART, "fill": "cf8290", "edge": "a85c6c", "amount": 10, "speed": 90.0,  "spread": 40.0,  "gravity": -60.0},
	"play":  {"shape": SHAPE_STAR, "fill": "dda843", "edge": "b8871f", "amount": 12, "speed": 130.0, "spread": 180.0, "gravity": 140.0},
	"eat":   {"shape": SHAPE_CRUMB, "fill": "d27449", "edge": "a9552c", "amount": 10, "speed": 80.0,  "spread": 55.0,  "gravity": 220.0},
	"sleep": {"shape": SHAPE_SPARKLE, "fill": "6f93b0", "edge": "587c99", "amount": 7,  "speed": 45.0,  "spread": 20.0,  "gravity": -50.0},
}

## Effects anchor above the pet's origin (its feet), over the head and a bit
## left, clear of the HUD's thought bubble.
const HEAD_OFFSET: Vector2 = Vector2(-30.0, -240.0)

var _textures := {}


func _ready() -> void:
	z_index = 50
	for kind in BURSTS:
		var cfg: Dictionary = BURSTS[kind]
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="%s" fill="#%s" stroke="#%s" stroke-width="1.4" stroke-linejoin="round"/></svg>' \
				% [cfg["shape"], cfg["fill"], cfg["edge"]]
		_textures[kind] = FeltDraw.svg_string_texture(svg, 2.0)
	EventBus.floating_text_requested.connect(_on_floating_text_requested)
	EventBus.burst_requested.connect(_on_burst_requested)


func _on_floating_text_requested(content: String, color: Color, world_pos: Vector2) -> void:
	var ft := FLOATING_TEXT.new()
	add_child(ft)
	ft.begin(to_local(world_pos) + HEAD_OFFSET, content, color)


func _on_burst_requested(kind: String, world_pos: Vector2) -> void:
	if not BURSTS.has(kind):
		kind = "love"
	var cfg: Dictionary = BURSTS[kind]

	var p := CPUParticles2D.new()
	p.texture = _textures[kind]
	p.position = to_local(world_pos) + HEAD_OFFSET
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = int(cfg["amount"])
	p.lifetime = 0.9
	p.direction = Vector2(0.0, -1.0)
	p.spread = float(cfg["spread"])
	p.initial_velocity_min = float(cfg["speed"]) * 0.6
	p.initial_velocity_max = float(cfg["speed"])
	p.gravity = Vector2(0.0, float(cfg["gravity"]))
	p.angle_min = -25.0
	p.angle_max = 25.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.55
	p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	# The shapes carry their own colors; the ramp only fades them out.
	var ramp := Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	p.color_ramp = ramp

	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
