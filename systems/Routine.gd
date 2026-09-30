## Routine.gd
## Mochi's day by the real clock (the phone's hour), in blocks that make some
## things likelier: waking up and breakfast, an active late morning, an afternoon
## nap, a cuddly dusk, a calm evening and the night's sleep. Her temperament and
## habits weigh on top (see Temperament).
##
## forced_hour overrides the clock (e.g. 22) to check hour-dependent behavior and
## visuals; -1 follows the phone.
extends RefCounted

const BLOCKS := ["manana", "activa", "siesta", "atardecer", "calma", "noche"]
const HOURS := {"manana": "7–10", "activa": "10–14", "siesta": "14–17", "atardecer": "17–20", "calma": "20–22", "noche": "22–7"}

static var forced_hour := -1


static func hour() -> int:
	if forced_hour >= 0:
		return forced_hour
	return int(Time.get_time_dict_from_system().get("hour", 12))


static func block(h: int = -1) -> String:
	if h < 0:
		h = hour()
	if h >= GameConfig.NIGHT_START_HOUR or h < GameConfig.NIGHT_END_HOUR:
		return "noche"
	if h < 10:
		return "manana"
	if h < 14:
		return "activa"
	if h < 17:
		return "siesta"
	if h < 20:
		return "atardecer"
	return "calma"
