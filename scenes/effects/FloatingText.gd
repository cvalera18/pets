## FloatingText.gd
## A transient label that floats upward and fades out, then frees itself.
##
## Reusable for any feedback: stat gains ("+20"), status messages, currency
## pickups, achievements, etc. Spawn it via the static helper — it self-animates
## and self-destructs, so callers never have to manage its lifecycle.
##
## Usage:
##   var ft := FLOATING_TEXT.new(); add_child(ft)
##   ft.begin(anchor_pos, "+20", Color.PINK)
class_name FloatingText
extends Label

const RISE_DISTANCE: float = 70.0
const DURATION:      float = 1.0
const DRIFT_X_RANGE: float = 24.0
const FONT_SIZE:     int   = 28


## Starts the float-and-fade animation. Call right after adding to the scene
## tree. `anchor` is the centered position in the parent's local space.
func begin(anchor: Vector2, content: String, color: Color) -> void:
	text = content
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	z_index = 100

	# Fixed box so centering is stable without waiting a frame for autosize.
	size = Vector2(140.0, 40.0)
	pivot_offset = size * 0.5
	position = anchor - pivot_offset

	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_color", color)
	# Dark outline keeps light text readable over any background.
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
	add_theme_constant_override("outline_size", 6)

	var drift := randf_range(-DRIFT_X_RANGE, DRIFT_X_RANGE)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", position.x + drift, DURATION)
	tween.tween_property(self, "modulate:a", 0.0, DURATION * 0.45).set_delay(DURATION * 0.55)
	tween.finished.connect(queue_free)
