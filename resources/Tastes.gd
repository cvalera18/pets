## Tastes.gd
## What Mochi thinks of each food: one she loves, one she won't eat unless she's
## starving, and the rest she likes. Rolled once per cat and saved in the pet
## block; the player discovers them by serving each food, and known ones get a
## mark on the food tray.
extends RefCounted

const FOODS := ["tuna", "chicken", "kibble", "carrot"]

var taste := {}   # food -> "love" | "like" | "dislike"
var known := {}   # food -> true once she has eaten or refused it


## Picks a new set of tastes (pass an rng to make it deterministic).
func roll(rng: RandomNumberGenerator = null) -> void:
	var order: Array = FOODS.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i) if rng else randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	taste.clear()
	for i in order.size():
		taste[order[i]] = "love" if i == 0 else "dislike" if i == order.size() - 1 else "like"
	known.clear()


func of(food: String) -> String:
	return taste.get(food, "like")


## Whether she'd go eat this food now, at this hunger.
func wants(food: String, hunger: float) -> bool:
	match of(food):
		"love":
			return hunger < GameConfig.EAT_LOVED_BELOW
		"dislike":
			return hunger <= GameConfig.CRITICAL_THRESHOLD
		_:
			return hunger < GameConfig.EAT_BELOW


func to_dict() -> Dictionary:
	return {"taste": taste.duplicate(), "known": known.keys()}


## Restores saved tastes; a missing or broken set (old saves) is rolled anew.
func load_from(data: Dictionary) -> void:
	var saved: Dictionary = data.get("taste", {})
	taste.clear()
	for food in FOODS:
		if saved.get(food, "") in ["love", "like", "dislike"]:
			taste[food] = saved[food]
	if taste.size() != FOODS.size() or taste.values().count("love") != 1:
		roll()
		return
	known.clear()
	for food in data.get("known", []):
		if food in FOODS:
			known[food] = true
