## SaveSystem.gd
## Autoload singleton — save/load façade.
##
## Delegates all persistence to the active BaseSaveProvider.
## Callers (Room.gd, Main.gd) never touch providers directly.
##
## Switching to cloud save (v2) only requires:
##   1. Implementing SupabaseSaveProvider extends BaseSaveProvider
##   2. Setting GameConfig.FEATURE_CLOUD_SAVE = true
##   Everything else stays unchanged.
##
## ─── Save data schema (version 1) ────────────────────────────────────────────
##  {
##    "version":   1,              # schema version — used for migrations
##    "saved_at":  1710000000.0,   # Unix timestamp — offline decay calculation
##    "pet": {
##      "hunger":    80.0,
##      "happiness": 75.0,
##      "energy":    60.0,
##      "affection": 90.0,
##      "name":      "Mochi"
##    },
##    "settings": {
##      "locale":                "es",
##      "notifications_enabled": true
##    },
##    "cosmetics": {
##      "equipped_skin": "skin_default"
##    }
##  }
extends Node

const SAVE_SCHEMA_VERSION: int = 1

var _provider: BaseSaveProvider


func _ready() -> void:
	# TODO v2: when FEATURE_CLOUD_SAVE is true and user is authenticated,
	#          instantiate SupabaseSaveProvider here instead.
	_provider = LocalSaveProvider.new()

	EventBus.save_requested.connect(_on_save_requested)


# ─── Public API ───────────────────────────────────────────────────────────────

## Builds the full save dictionary from current state and persists it.
## Includes a Unix timestamp so offline decay can be calculated on next load.
func save_game(pet_stats: PetStats, pet_name: String,
		settings: Dictionary, cosmetics: Dictionary) -> bool:

	var data := {
		"version":   SAVE_SCHEMA_VERSION,
		"saved_at":  Time.get_unix_time_from_system(),
		"pet": {
			"hunger":    pet_stats.hunger,
			"happiness": pet_stats.happiness,
			"energy":    pet_stats.energy,
			"affection": pet_stats.affection,
			"name":      pet_name,
		},
		"settings":  settings,
		"cosmetics": cosmetics,
	}

	var success := _provider.save(data)
	EventBus.save_completed.emit(success)
	return success


## Loads and returns the save dictionary. Returns {} if no save exists.
## Always check is_empty() before reading fields.
func load_game() -> Dictionary:
	if not _provider.has_save():
		EventBus.load_completed.emit(false)
		return {}

	var data: Dictionary = _provider.load_data()
	if data.is_empty():
		EventBus.load_completed.emit(false)
		return {}

	data = _migrate(data)
	EventBus.load_completed.emit(true)
	return data


## Returns seconds elapsed since the last save (for offline decay).
## Returns 0.0 if the timestamp is missing.
func get_offline_seconds(save_data: Dictionary) -> float:
	if not save_data.has("saved_at"):
		return 0.0
	var elapsed := Time.get_unix_time_from_system() - float(save_data["saved_at"])
	return maxf(0.0, elapsed)


## Returns true if a save file exists.
func has_save() -> bool:
	return _provider.has_save()


## Deletes the save. Always confirm with the user before calling.
func delete_save() -> bool:
	return _provider.delete_save()


# ─── Private ──────────────────────────────────────────────────────────────────

## save_requested is a no-op here: Room.gd listens to it and calls save_game()
## with full context (pet_stats, pet_name, settings, cosmetics).
func _on_save_requested() -> void:
	pass


## Migrates save data between schema versions.
## Add a new block here for every schema change — never remove old blocks.
func _migrate(data: Dictionary) -> Dictionary:
	var version: int = data.get("version", 0)

	# v0 → v1: add cosmetics block if absent
	if version < 1:
		if not data.has("cosmetics"):
			data["cosmetics"] = {"equipped_skin": "skin_default"}
		data["version"] = 1

	# TODO v2: add v1 → v2 migration here

	return data
