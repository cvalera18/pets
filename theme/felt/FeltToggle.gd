## FeltToggle.gd
## Felt on/off switch: a sunken track with a two-hole sewing-button knob.
@tool
extends BaseButton

@export var on_color := Color("7f9a70"):
	set(v):
		on_color = v
		queue_redraw()
@export var off_color := Color("d9c8b0"):
	set(v):
		off_color = v
		queue_redraw()
@export var knob_color := Color("fbf4e6"):
	set(v):
		knob_color = v
		queue_redraw()

var _knob_t := 0.0


func _init() -> void:
	toggle_mode = true
	custom_minimum_size = Vector2(54, 30)
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	_knob_t = 1.0 if button_pressed else 0.0
	toggled.connect(_on_toggled)


## Sets the state without emitting toggled or animating (for loading settings).
func set_on(on: bool) -> void:
	set_pressed_no_signal(on)
	_knob_t = 1.0 if on else 0.0
	queue_redraw()


func _on_toggled(on: bool) -> void:
	if not is_inside_tree():
		_knob_t = 1.0 if on else 0.0
		return
	create_tween().tween_method(_set_knob, _knob_t, 1.0 if on else 0.0, 0.16) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_knob(t: float) -> void:
	_knob_t = t
	queue_redraw()


func _draw() -> void:
	var track := Vector2(54, 30)
	var o := (size - track) * 0.5
	var r := track.y * 0.5
	var col := off_color.lerp(on_color, _knob_t)
	draw_circle(o + Vector2(r, r), r, col, true, -1.0, true)
	draw_circle(o + Vector2(track.x - r, r), r, col, true, -1.0, true)
	draw_rect(Rect2(o + Vector2(r, 0), Vector2(track.x - 2.0 * r, track.y)), col)
	draw_rect(Rect2(o + Vector2(r, 0), Vector2(track.x - 2.0 * r, 2.0)), Color(0.24, 0.16, 0.08, 0.14))

	var k := o + Vector2(lerpf(15.0, 39.0, _knob_t), 15.0)
	draw_circle(k + Vector2(0, 2), 12.0, Color(0.24, 0.16, 0.08, 0.25), true, -1.0, true)
	draw_circle(k, 12.0, knob_color, true, -1.0, true)
	var hole := Color(0.43, 0.33, 0.25, 0.55)
	draw_circle(k + Vector2(-3.5, 0), 1.6, hole, true, -1.0, true)
	draw_circle(k + Vector2(3.5, 0), 1.6, hole, true, -1.0, true)
