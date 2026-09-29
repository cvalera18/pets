## TimeTint.gd
## Multiply-blend overlay that deepens the room (and Mochi) at dusk and night,
## following the device clock. White = identity (daytime).
##
## To check dusk/night visuals at any hour, set forced_hour (e.g. 22) before the
## scene loads; -1 follows the real clock.
extends ColorRect

const P := preload("res://theme/Palette.gd")
const UPDATE_INTERVAL := 60.0

enum Phase { DAY, DUSK, NIGHT }

static var forced_hour := -1

var _timer := 0.0


static func phase() -> Phase:
	var hour: int = forced_hour if forced_hour >= 0 else Time.get_time_dict_from_system().get("hour", 12)
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
	_apply()


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= UPDATE_INTERVAL:
		_timer = 0.0
		_apply()


func _apply() -> void:
	match phase():
		Phase.NIGHT:
			color = P.TINT_NIGHT_MUL
		Phase.DUSK:
			color = P.TINT_DUSK_MUL
		_:
			color = Color.WHITE
