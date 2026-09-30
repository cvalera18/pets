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
const FELT_ROOM:     PackedScene = preload("res://scenes/room/FeltRoom.tscn")
const FEATHER_WAND:  GDScript = preload("res://scenes/play/FeatherWand.gd")
const FOOD_BOWL:     GDScript = preload("res://scenes/play/FoodBowl.gd")
const TOY_BASKET:    GDScript = preload("res://scenes/play/ToyBasket.gd")

## Where the wand's feather rests, from Mochi's feet: beside her face, clear of the hoop.
const WAND_REST := Vector2(125.0, -175.0)
## How far in front of her feet the wand she brings lands on the floor.
const WAND_DROP_Y := 26.0
## The toy basket, from Mochi's feet: to her right, partly behind her.
const BASKET_OFFSET := Vector2(164.0, 0.0)

@onready var pet_spawn_point:   Marker2D = $PetSpawnPoint
@onready var decoration_layer:  Node2D   = $DecorationLayer

var _pet:              Node  = null
var _hud:              Node  = null
var _auto_save_timer:  float = 0.0


func _ready() -> void:
	_spawn_room()
	_load_or_create_pet()
	_spawn_bowl()
	_spawn_basket()
	_spawn_wand()
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
	_pet.global_position = pet_spawn_point.global_position + Vector2(0.0, _floor_offset())

	if SaveSystem.has_save():
		var data := SaveSystem.load_game()
		if not data.is_empty():
			var offline_secs := SaveSystem.get_offline_seconds(data)
			_pet.load_from_save(data.get("pet", {}), offline_secs)
			_apply_settings(data.get("settings", {}))
			Achievements.load_from(data.get("achievements", {}))
			Personality.load_from(data.get("personality", {}))
			# Persist right away: offline decay is applied and tastes rolled for an
			# older save must not be rolled again on the next launch.
			_save()
			return

	# No valid save — start fresh with the name chosen during onboarding.
	var chosen_name := GameState.pending_pet_name if GameState.pending_pet_name != "" else "Mochi"
	Personality.load_from({})  # reset emergent traits for a brand-new pet
	_pet.initialize_fresh(chosen_name)
	_save()  # Persist immediately so the chosen name is never lost.


func _spawn_hud() -> void:
	_hud = HUD_SCENE.instantiate()
	add_child(_hud)  # CanvasLayer renders on top automatically.


## Mochi's food bowl, on the floor beside her.
func _spawn_bowl() -> void:
	var bowl: Node2D = FOOD_BOWL.new()
	add_child(bowl)
	bowl.position = _pet.position + GameConfig.BOWL_OFFSET


## The toy basket, drawn just behind Mochi.
func _spawn_basket() -> void:
	var basket: Node2D = TOY_BASKET.new()
	add_child(basket)
	move_child(basket, _pet.get_index())
	basket.position = _pet.position + BASKET_OFFSET


## The feather wand toy, stored in the basket until you take it out.
func _spawn_wand() -> void:
	var wand = FEATHER_WAND.new()
	add_child(wand)
	wand.rest_point = _pet.global_position + WAND_REST
	wand.focus_x = _pet.global_position.x
	wand.floor_y = _pet.global_position.y + WAND_DROP_Y


## Spawns the EffectsLayer that turns EventBus juice requests into visuals.
func _spawn_effects_layer() -> void:
	add_child(EFFECTS_LAYER.new())


## On screens taller than the 844 px design (stretch "expand") the floor and
## cushion hug the bottom edge, so the pet shifts down by the same amount.
func _floor_offset() -> float:
	var design_h := float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	return get_viewport_rect().size.y - design_h


## Adds the felt room backdrop (wall, floor seam, hoop, cushion) behind
## everything, with a time-of-day tint over the room and the pet.
func _spawn_room() -> void:
	add_child(FELT_ROOM.instantiate())


func _save() -> void:
	if _pet == null:
		return

	var settings := {
		"locale":                TranslationServer.get_locale().split("_")[0],
		"notifications_enabled": GameState.notifications_enabled,
		"sfx_enabled":           GameState.sfx_enabled,
		"sfx_volume":            GameState.sfx_volume,
		"haptics_enabled":       GameState.haptics_enabled,
		"decay_test_mode":       GameState.decay_test_mode,
	}
	var cosmetics := {
		"equipped_skin": "skin_default",  # TODO v2: read from CosmeticManager.
	}

	SaveSystem.save_game(_pet.stats, _pet.pet_name, settings, cosmetics,
			_pet.bond_xp, Achievements.to_dict(), Personality.to_dict(),
			{"tastes": _pet.tastes.to_dict()})


func _apply_settings(settings: Dictionary) -> void:
	# Normalize "es_MX" → "es" so saves from a regional system locale still match.
	var locale: String = str(settings.get("locale", GameConfig.DEFAULT_LOCALE)).split("_")[0]
	if locale in GameConfig.SUPPORTED_LOCALES:
		TranslationServer.set_locale(locale)
	GameState.notifications_enabled = bool(settings.get("notifications_enabled", true))
	GameState.sfx_enabled = bool(settings.get("sfx_enabled", true))
	GameState.sfx_volume = float(settings.get("sfx_volume", 0.8))
	GameState.haptics_enabled = bool(settings.get("haptics_enabled", true))
	GameState.decay_test_mode = bool(settings.get("decay_test_mode", false))


func _on_save_requested() -> void:
	_save()
