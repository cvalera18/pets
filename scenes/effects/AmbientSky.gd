## AmbientSky.gd
## A full-screen backdrop whose tint follows the device's real local time — airy
## and bright at midday, warm at dusk, deep blue at night. Pure code, no art.
##
## Lives behind everything in the Room (very negative z_index) and ignores input.
extends ColorRect

## How often the tint is re-evaluated against the wall clock.
const UPDATE_INTERVAL: float = 60.0

var _timer: float = 0.0


func _ready() -> void:
	z_index = -100
	set_anchors_preset(Control.PRESET_FULL_RECT)  # Fill the viewport.
	mouse_filter = Control.MOUSE_FILTER_IGNORE     # Never swallow taps.
	_apply_tint()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= UPDATE_INTERVAL:
		_timer = 0.0
		_apply_tint()


func _apply_tint() -> void:
	var hour: int = Time.get_time_dict_from_system().get("hour", 12)
	color = _color_for_hour(hour)


func _color_for_hour(hour: int) -> Color:
	if hour < 5:
		return Color(0.16, 0.18, 0.30)   # deep night
	elif hour < 8:
		return Color(0.70, 0.72, 0.88)   # soft dawn
	elif hour < 17:
		return Color(0.85, 0.93, 1.00)   # bright day
	elif hour < 20:
		return Color(0.98, 0.80, 0.62)   # warm dusk
	return Color(0.16, 0.18, 0.30)       # deep night
