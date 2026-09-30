## Temperament.gd
## Who Mochi is from birth: how much energy she has (tranquila −1 … inquieta +1)
## and how attached she is (independiente −1 … pegote +1). Rolled once per cat
## and saved in the pet block; it never shows as a number, it shows in what she
## does. It never changes her stats: it moves how soon she asks for things and
## what she likes to do with her free time, together with the hour (Routine) and
## the habits she picks up from you (Personality's trait).
extends RefCounted

var energy := 0.0
var attachment := 0.0


## Picks a new temperament (pass an rng to make it deterministic).
func roll(rng: RandomNumberGenerator = null) -> void:
	energy = rng.randf_range(-1.0, 1.0) if rng else randf_range(-1.0, 1.0)
	attachment = rng.randf_range(-1.0, 1.0) if rng else randf_range(-1.0, 1.0)


## How low a stat has to fall before she asks for it with her body. An attached
## cat asks for cuddles early and an independent one only when she really needs
## them; mornings bring breakfast forward, the active hours and a restless nature
## bring play forward, dusk brings cuddles forward. `habit` is her trait.
func asks_below(stat: String, block: String, habit: String) -> float:
	var t := GameConfig.LOW_THRESHOLD
	match stat:
		"hunger":
			if block == "manana":
				t += 20.0
			if habit == "glotona":
				t += 15.0
		"happiness":
			if block == "activa":
				t += 10.0
			t += 10.0 * energy
			if habit == "juguetona":
				t += 15.0
		"affection":
			t += 20.0 * attachment
			if block == "atardecer" and attachment > -0.3:
				t += 15.0
			if habit == "mimosa":
				t += 15.0
	return clampf(t, GameConfig.CRITICAL_THRESHOLD, 75.0)


## Below this energy she dozes off on her own: at night she's sleepy early, and
## in the afternoon she takes a nap even when not that tired (calmer cats sooner).
func sleepy_energy(block: String, habit: String) -> float:
	var e := GameConfig.SLEEPY_ENERGY
	match block:
		"noche":
			e = GameConfig.SLEEPY_ENERGY_NIGHT
		"siesta":
			e = GameConfig.SLEEPY_ENERGY_SIESTA - 15.0 * energy
	if habit == "dormilona":
		e += 10.0
	return e


## What she might do with free time right now, as weights ("rest" = just be).
func free_time_weights(block: String, habit: String) -> Dictionary:
	var w := {"rest": 1.2, "groom": 1.0, "stretch": 0.4, "zoomies": 0.3 * (1.0 + energy)}
	match block:
		"manana":
			w["stretch"] *= 3.0
		"activa":
			w["zoomies"] *= 4.0
		"calma":
			w["groom"] *= 3.0
			w["zoomies"] *= 0.3
		"noche", "siesta":
			w["zoomies"] = 0.0
	if energy < 0.0:
		w["groom"] *= 1.0 - 0.3 * energy
	if habit == "juguetona":
		w["zoomies"] *= 1.5
	return w


## Picks one of the weighted options.
static func pick(weights: Dictionary, roll_value: float) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := roll_value * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return weights.keys().back()


func to_dict() -> Dictionary:
	return {"energy": energy, "attachment": attachment}


## Restores a saved temperament; a missing one (older saves) is rolled anew.
func load_from(data: Dictionary) -> void:
	if not (data.has("energy") and data.has("attachment")):
		roll()
		return
	energy = clampf(float(data["energy"]), -1.0, 1.0)
	attachment = clampf(float(data["attachment"]), -1.0, 1.0)
