## TimeTint.gd
## Multiply-blend overlay over the room (and Mochi) that follows the device clock.
## It's an indoor room: warm light at dusk, and at night the lamp stays on (a soft
## warm tint) until Mochi falls asleep; then the lights go off. White = identity
## (daytime).
##
## To check dusk/night visuals at any hour, set Routine.forced_hour (e.g. 22)
## before the scene loads.
extends ColorRect

const P := preload("res://theme/Palette.gd")
const Routine := preload("res://systems/Routine.gd")
const UPDATE_INTERVAL := 60.0
const LIGHTS_FADE := 0.8

enum Phase { DAY, DUSK, NIGHT }

var _timer := 0.0
var _asleep := false
var _tween: Tween


static func phase() -> Phase:
	var hour := Routine.hour()
	if hour < 5 or hour >= 20:
		return Phase.NIGHT
	if hour >= 17:
		return Phase.DUSK
	return Phase.DAY


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = mat
	color = _target()
	EventBus.sleeping_changed.connect(_on_sleeping_changed)


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= UPDATE_INTERVAL:
		_timer = 0.0
		_apply()


func _on_sleeping_changed(asleep: bool) -> void:
	_asleep = asleep
	_apply()


func _apply() -> void:
	var goal := _target()
	if goal == color:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "color", goal, LIGHTS_FADE)


func _target() -> Color:
	match phase():
		Phase.NIGHT:
			return P.TINT_NIGHT_MUL if _asleep else P.TINT_LAMP_MUL
		Phase.DUSK:
			return P.TINT_DUSK_MUL
	return Color.WHITE
