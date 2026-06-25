## Achievements.gd
## Autoload singleton — tracks milestone unlocks and announces them.
##
## Decoupled like everything else: it watches EventBus.burst_requested (which
## only fires on a *successful* care interaction) and EventBus.bond_level_changed,
## and emits EventBus.achievement_unlocked when a new milestone is reached.
##
## State (unlocked set + interaction count) persists inside the main save: Room
## reads it via load_from() and writes it via to_dict().
extends Node

## id → { "title": <i18n key> }. Add entries here; no other code changes needed.
const CATALOG := {
	"first_care":     {"title": "ACH_FIRST_CARE"},
	"bond_3":         {"title": "ACH_BOND_3"},
	"bond_5":         {"title": "ACH_BOND_5"},
	"caretaker_50":   {"title": "ACH_CARETAKER_50"},
	"caretaker_200":  {"title": "ACH_CARETAKER_200"},
}

## Kinds (from burst_requested) that count as caring for the pet.
const CARE_KINDS := ["eat", "play", "love"]

var _unlocked: Dictionary = {}   # id -> true (used as a set)
var _interactions: int = 0


func _ready() -> void:
	EventBus.burst_requested.connect(_on_burst_requested)
	EventBus.bond_level_changed.connect(_on_bond_level_changed)


# ─── Persistence (orchestrated by Room) ───────────────────────────────────────

func to_dict() -> Dictionary:
	return {"unlocked": _unlocked.keys(), "interactions": _interactions}


func load_from(data: Dictionary) -> void:
	_unlocked.clear()
	for id in data.get("unlocked", []):
		_unlocked[id] = true
	_interactions = int(data.get("interactions", 0))


# ─── Triggers ─────────────────────────────────────────────────────────────────

func _on_burst_requested(kind: String, _world_pos: Vector2) -> void:
	if kind not in CARE_KINDS:
		return
	_interactions += 1
	_unlock("first_care")
	if _interactions >= 50:
		_unlock("caretaker_50")
	if _interactions >= 200:
		_unlock("caretaker_200")


func _on_bond_level_changed(level: int) -> void:
	if level >= 3:
		_unlock("bond_3")
	if level >= 5:
		_unlock("bond_5")


# ─── Private ──────────────────────────────────────────────────────────────────

func _unlock(id: String) -> void:
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	EventBus.achievement_unlocked.emit(id, CATALOG[id]["title"])
