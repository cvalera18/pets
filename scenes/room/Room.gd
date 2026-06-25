## Room.gd
## The main gameplay screen — the pet's living space.
##
## Responsibilities:
##   • Spawning and positioning the Pet
##   • Instantiating the HUD overlay
##   • Owning the save/load lifecycle for the current session
##   • Auto-saving on a timer and on save_requested events
##   • Hosting the DecorationLayer for room items
##     (TODO v2: purchasable / unlockable furniture)
extends Node2D


const PET_SCENE: PackedScene = preload("res://scenes/pet/Pet.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/hud/HUD.tscn")
const EFFECTS_LAYER: GDScript = preload("res://scenes/effects/EffectsLayer.gd")
const COZY_ROOM:     GDScript = preload("res://scenes/effects/CozyRoom.gd")

@onready var pet_spawn_point:   Marker2D = $PetSpawnPoint
@onready var decoration_layer:  Node2D   = $DecorationLayer

var _pet:              Node  = null
var _hud:              Node  = null
var _auto_save_timer:  float = 0.0


func _ready() -> void:
	_spawn_room()
	_load_or_create_pet()
	_spawn_hud()
	_spawn_effects_layer()
	# Sync HUD with actual stat values — must happen after both pet and HUD
	# are in the scene tree so HUD's stat_changed connection is active.
	_pet.broadcast_stats()
	Personality.emit_current()  # sync Mochi tint + HUD trait badge with loaded state

	EventBus.save_requested.connect(_on_save_requested)


func _process(delta: float) -> void:
	if GameConfig.AUTO_SAVE_INTERVAL <= 0.0:
		return
	_auto_save_timer += delta
	if _auto_save_timer >= GameConfig.AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		_save()


# ─── Private ──────────────────────────────────────────────────────────────────

func _load_or_create_pet() -> void:
	_pet = PET_SCENE.instantiate()
	add_child(_pet)
	_pet.global_position = pet_spawn_point.global_position

	if SaveSystem.has_save():
		var data := SaveSystem.load_game()
		if not data.is_empty():
			var offline_secs := SaveSystem.get_offline_seconds(data)
			_pet.load_from_save(data.get("pet", {}), offline_secs)
			_apply_settings(data.get("settings", {}))
			Achievements.load_from(data.get("achievements", {}))
			Personality.load_from(data.get("personality", {}))
			return

	# No valid save — start fresh with the name chosen during onboarding.
	var chosen_name := GameState.pending_pet_name if GameState.pending_pet_name != "" else "Mochi"
	Personality.load_from({})  # reset emergent traits for a brand-new pet
	_pet.initialize_fresh(chosen_name)
	_save()  # Persist immediately so the chosen name is never lost.


func _spawn_hud() -> void:
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)  # CanvasLayer renders on top automatically.


## Spawns the EffectsLayer that turns EventBus juice requests into visuals.
func _spawn_effects_layer() -> void:
	add_child(EFFECTS_LAYER.new())


## Adds the cozy room backdrop (gradient wall, window, floor, rug, plant)
## behind everything, with a time-of-day tint.
func _spawn_room() -> void:
	add_child(COZY_ROOM.new())


func _save() -> void:
	if _pet == null:
		return

	var settings := {
		"locale":                TranslationServer.get_locale().split("_")[0],
		"notifications_enabled": GameState.notifications_enabled,
		"sfx_enabled":           GameState.sfx_enabled,
		"sfx_volume":            GameState.sfx_volume,
		"decay_test_mode":       GameState.decay_test_mode,
	}
	var cosmetics := {
		"equipped_skin": "skin_default",  # TODO v2: read from CosmeticManager.
	}

	SaveSystem.save_game(_pet.stats, _pet.pet_name, settings, cosmetics,
			_pet.bond_xp, Achievements.to_dict(), Personality.to_dict())


func _apply_settings(settings: Dictionary) -> void:
	# Normalize "es_MX" → "es" so saves from a regional system locale still match.
	var locale: String = str(settings.get("locale", GameConfig.DEFAULT_LOCALE)).split("_")[0]
	if locale in GameConfig.SUPPORTED_LOCALES:
		TranslationServer.set_locale(locale)
	GameState.notifications_enabled = bool(settings.get("notifications_enabled", true))
	GameState.sfx_enabled = bool(settings.get("sfx_enabled", true))
	GameState.sfx_volume = float(settings.get("sfx_volume", 0.8))
	GameState.decay_test_mode = bool(settings.get("decay_test_mode", false))


func _on_save_requested() -> void:
	_save()
