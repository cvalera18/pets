## EffectsLayer.gd
## Listens for juice/feedback requests on the EventBus and spawns transient
## visual effects (floating text + particle bursts) at the requested world
## position.
##
## Holds NO game logic — pure presentation. It owns no references to the Pet or
## HUD; everything arrives via EventBus signals. Lives as a child of Room.
##
## The particle "texture" is a soft round dot generated procedurally at runtime,
## so this effect system needs zero art assets.
class_name EffectsLayer
extends Node2D

const FLOATING_TEXT := preload("res://scenes/effects/FloatingText.gd")

## Per-kind burst configuration. Tune freely — colors double as the stat hues.
const BURSTS := {
	"love":  {"color": Color(1.0, 0.45, 0.6), "amount": 12, "speed": 90.0,  "spread": 40.0,  "gravity": -60.0},
	"play":  {"color": Color(1.0, 0.85, 0.3), "amount": 14, "speed": 130.0, "spread": 180.0, "gravity": 140.0},
	"eat":   {"color": Color(1.0, 0.7, 0.35), "amount": 10, "speed": 80.0,  "spread": 55.0,  "gravity": 220.0},
	"sleep": {"color": Color(0.6, 0.8, 1.0),  "amount": 7,  "speed": 45.0,  "spread": 20.0,  "gravity": -50.0},
}

## Effects anchor a bit above the pet's origin (over its head).
const HEAD_OFFSET: Vector2 = Vector2(0.0, -110.0)

var _dot_texture: GradientTexture2D


func _ready() -> void:
	z_index = 50
	_dot_texture = _make_dot_texture()
	EventBus.floating_text_requested.connect(_on_floating_text_requested)
	EventBus.burst_requested.connect(_on_burst_requested)


func _on_floating_text_requested(content: String, color: Color, world_pos: Vector2) -> void:
	var ft := FLOATING_TEXT.new()
	add_child(ft)
	ft.begin(to_local(world_pos) + HEAD_OFFSET, content, color)


func _on_burst_requested(kind: String, world_pos: Vector2) -> void:
	var cfg: Dictionary = BURSTS.get(kind, BURSTS["love"])
	var base: Color = cfg["color"]

	var p := CPUParticles2D.new()
	p.texture = _dot_texture
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
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3

	# Fade each particle from its color to transparent over its lifetime.
	var ramp := Gradient.new()
	ramp.set_color(0, base)
	ramp.set_color(1, Color(base.r, base.g, base.b, 0.0))
	p.color_ramp = ramp

	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Builds a 16×16 soft radial dot used as the particle sprite (no art file).
func _make_dot_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 16
	tex.height = 16
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
