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
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Never swallow taps.
	# A Control parented to a Node2D does NOT auto-anchor to the viewport, so it
	# would stay size (0,0) and be invisible. Size it explicitly and oversize
	# generously so it covers any window aspect (stretch "expand") without having
	# to track resizes — it's just a flat backdrop sitting behind everything.
	position = Vector2(-2000.0, -2000.0)
	size = Vector2(8000.0, 8000.0)
	_apply_tint()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= UPDATE_INTERVAL:
		_timer = 0.0
		_apply_tint()


func _apply_tint() -> void:
	var hour: int = Time.get_time_dict_from_system().get("hour", 12)
	color = _color_for_hour(hour)


## Muted tones on purpose: the HUD uses white text, so the backdrop stays
## medium-dark for readability while still shifting hue across the day.
func _color_for_hour(hour: int) -> Color:
	if hour < 5:
		return Color(0.14, 0.16, 0.26)   # deep night
	elif hour < 8:
		return Color(0.42, 0.40, 0.52)   # muted dawn
	elif hour < 17:
		return Color(0.40, 0.55, 0.68)   # soft day sky
	elif hour < 20:
		return Color(0.55, 0.42, 0.40)   # warm dusk
	return Color(0.14, 0.16, 0.26)       # deep night
