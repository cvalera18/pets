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
const AMBIENT_SKY:   GDScript = preload("res://scenes/effects/AmbientSky.gd")

@onready var pet_spawn_point:   Marker2D = $PetSpawnPoint
@onready var decoration_layer:  Node2D   = $DecorationLayer

var _pet:              Node  = null
var _hud:              Node  = null
var _auto_save_timer:  float = 0.0


func _ready() -> void:
	_spawn_ambient_sky()
	_load_or_create_pet()
	_spawn_hud()
	_spawn_effects_layer()
	# Sync HUD with actual stat values — must happen after both pet and HUD
	# are in the scene tree so HUD's stat_changed connection is active.
	_pet.broadcast_stats()

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
			return

	# No valid save — start fresh with the name chosen during onboarding.
	var chosen_name := GameState.pending_pet_name if GameState.pending_pet_name != "" else "Mochi"
	_pet.initialize_fresh(chosen_name)
	_save()  # Persist immediately so the chosen name is never lost.


func _spawn_hud() -> void:
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)  # CanvasLayer renders on top automatically.


## Spawns the EffectsLayer that turns EventBus juice requests into visuals.
func _spawn_effects_layer() -> void:
	add_child(EFFECTS_LAYER.new())


## Adds the time-of-day backdrop behind everything in the room.
func _spawn_ambient_sky() -> void:
	add_child(AMBIENT_SKY.new())


func _save() -> void:
	if _pet == null:
		return

	var settings := {
		"locale":                TranslationServer.get_locale().split("_")[0],
		"notifications_enabled": GameState.notifications_enabled,
		"sfx_enabled":           GameState.sfx_enabled,
	}
	var cosmetics := {
		"equipped_skin": "skin_default",  # TODO v2: read from CosmeticManager.
	}

	SaveSystem.save_game(_pet.stats, _pet.pet_name, settings, cosmetics, _pet.bond_xp)


func _apply_settings(settings: Dictionary) -> void:
	# Normalize "es_MX" → "es" so saves from a regional system locale still match.
	var locale: String = str(settings.get("locale", GameConfig.DEFAULT_LOCALE)).split("_")[0]
	if locale in GameConfig.SUPPORTED_LOCALES:
		TranslationServer.set_locale(locale)
	GameState.notifications_enabled = bool(settings.get("notifications_enabled", true))
	GameState.sfx_enabled = bool(settings.get("sfx_enabled", true))


func _on_save_requested() -> void:
	_save()
