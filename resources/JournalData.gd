## JournalData.gd
## What the Libreta de Mochi has noted so far, beyond her tastes (Tastes keeps
## those): when she arrived, how many signs of each side of her temperament
## you've seen (three reveal it), which parts of her day you've watched, and
## whether there's something new you haven't read. Saved in the pet block.
extends RefCounted

const SIGNS_TO_KNOW := 3
const AXES := ["energy", "attach"]

var arrived_at := 0.0
var signs := {"energy": 0, "attach": 0}
var seen := {}          # routine block -> true once you watched her do its thing
var unread := false


## A brand-new cat: she arrives now and nothing is noted yet.
func start(now: float) -> void:
	arrived_at = now
	signs = {"energy": 0, "attach": 0}
	seen.clear()
	unread = false


func knows(axis: String) -> bool:
	return int(signs.get(axis, 0)) >= SIGNS_TO_KNOW


## One more sign of that side of her temperament; true when it just became known.
func add_sign(axis: String) -> bool:
	if not signs.has(axis) or knows(axis):
		return false
	signs[axis] += 1
	return knows(axis)


## You watched her do what she does at this time of day; true the first time.
func see(block: String) -> bool:
	if seen.has(block):
		return false
	seen[block] = true
	return true


func days_together(now: float) -> int:
	return maxi(1, floori((now - arrived_at) / 86400.0) + 1)


func to_dict() -> Dictionary:
	return {"arrived_at": arrived_at, "signs": signs.duplicate(), "seen": seen.keys(), "unread": unread}


## Restores the notebook; an older save starts it now, keeping nothing to lose.
func load_from(data: Dictionary, now: float) -> void:
	arrived_at = float(data.get("arrived_at", now))
	var saved: Dictionary = data.get("signs", {})
	for axis in AXES:
		signs[axis] = clampi(int(saved.get(axis, 0)), 0, SIGNS_TO_KNOW)
	seen.clear()
	for block in data.get("seen", []):
		seen[str(block)] = true
	unread = bool(data.get("unread", false))
