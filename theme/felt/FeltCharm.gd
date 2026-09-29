## FeltCharm.gd
## A small felt cut-out (star, heart or sparkle) with a darker edge that gently
## bobs in place. Decorative only.
@tool
extends Control

const FeltDraw := preload("res://theme/felt/FeltDraw.gd")

const SHAPES := {
	"star": "M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z",
	"heart": "M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z",
	"sparkle": "M12 2 L14 10 L22 12 L14 14 L12 22 L10 14 L2 12 L10 10 Z",
}

@export_enum("star", "heart", "sparkle") var shape := "star":
	set(v):
		shape = v
		_rebuild()
@export var fill_color := Color("dda843"):
	set(v):
		fill_color = v
		_rebuild()
@export var edge_color := Color("b8871f"):
	set(v):
		edge_color = v
		_rebuild()
@export var bob_period := 3.2
@export var bob_delay := 0.0

var _tex: Texture2D


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	pivot_offset = size * 0.5
	rotation_degrees = -6.0
	var t := create_tween().set_loops()
	t.tween_interval(bob_delay)
	t.tween_property(self, "position:y", position.y - 7.0, bob_period * 0.5).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "rotation_degrees", 6.0, bob_period * 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "position:y", position.y, bob_period * 0.5).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "rotation_degrees", -6.0, bob_period * 0.5).set_trans(Tween.TRANS_SINE)


func _rebuild() -> void:
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="%s" fill="#%s" stroke="#%s" stroke-width="1.3" stroke-linejoin="round"/></svg>' \
			% [SHAPES.get(shape, SHAPES["star"]), fill_color.to_html(false), edge_color.to_html(false)]
	_tex = FeltDraw.svg_string_texture(svg, 4.0)
	queue_redraw()


func _draw() -> void:
	if _tex:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
