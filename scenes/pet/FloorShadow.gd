## FloorShadow.gd
## Mochi's contact shadow: a soft radial falloff on the floor, with no edge. It
## lives apart from the rig so it stays on the floor while the body bobs; Pet.gd
## only scales and fades it as Mochi lifts off.
@tool
extends Node2D

@export var center := Vector2(0, 4):
	set(v):
		center = v
		queue_redraw()
@export var radii := Vector2(118, 11):
	set(v):
		radii = v
		queue_redraw()
@export var color := Color(0.353, 0.235, 0.137, 0.46):
	set(v):
		color = v
		_texture = null
		queue_redraw()

var _texture: GradientTexture2D


func _draw() -> void:
	if _texture == null:
		_texture = _make_texture()
	draw_texture_rect(_texture, Rect2(center - radii, radii * 2.0), false)


func _make_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([color, Color(color, color.a * 0.8), Color(color, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 128
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex
