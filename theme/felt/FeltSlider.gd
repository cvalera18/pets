## FeltSlider.gd
## HSlider with a knitted track (from the theme) and a sewing-button knob drawn
## on top. The theme's grabber icon is swapped for a transparent one of the
## knob's size so dragging and hit-testing keep working natively.
@tool
extends HSlider

const KNOB := 26.0

@export var knob_color := Color("fbf4e6"):
	set(v):
		knob_color = v
		queue_redraw()


func _ready() -> void:
	var img := Image.create(int(KNOB), int(KNOB), false, Image.FORMAT_RGBA8)
	var clear := ImageTexture.create_from_image(img)
	add_theme_icon_override("grabber", clear)
	add_theme_icon_override("grabber_highlight", clear)
	add_theme_icon_override("grabber_disabled", clear)
	custom_minimum_size.y = maxf(custom_minimum_size.y, KNOB)
	focus_mode = Control.FOCUS_NONE
	value_changed.connect(func(_v: float) -> void: queue_redraw())


func _draw() -> void:
	var k := Vector2(KNOB * 0.5 + ratio * (size.x - KNOB), size.y * 0.5)
	draw_circle(k + Vector2(0, 2), KNOB * 0.5, Color(0.24, 0.16, 0.08, 0.3), true, -1.0, true)
	draw_circle(k, KNOB * 0.5, knob_color, true, -1.0, true)
	var hole := Color(0.43, 0.33, 0.25, 0.55)
	draw_circle(k + Vector2(-3.5, 0), 1.6, hole, true, -1.0, true)
	draw_circle(k + Vector2(3.5, 0), 1.6, hole, true, -1.0, true)
