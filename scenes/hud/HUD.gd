## HUD.gd
## Heads-up display in the felt style — header (name, bond, trait), stat rows,
## thought bubble, toasts and the sewing-button action bar. Layout and styling
## live in HUD.tscn + the felt Theme; this script only wires state to it.
##
## HUD subscribes to EventBus signals to update in real time and emits EventBus
## signals from its buttons — it holds no reference to Pet whatsoever.
##
## Static labels hold translation keys and auto-translate; dynamic text uses tr().
## Add new keys to i18n/en.po and i18n/es.po when adding UI text here.
extends CanvasLayer

const SETTINGS := preload("res://scenes/ui/Settings.tscn")
const TOAST := preload("res://scenes/hud/Toast.tscn")
const P := preload("res://theme/Palette.gd")
const StyleBoxKnit := preload("res://theme/felt/StyleBoxKnit.gd")

## stat → node-name prefix in HUD.tscn.
const STATS := {"hunger": "Hunger", "happiness": "Happiness", "energy": "Energy", "affection": "Affection"}
## stat → the action button that fixes it (gets an alert ring while critical).
const FIXES := {"hunger": "FeedButton", "happiness": "PlayButton", "energy": "SleepButton", "affection": "PetButton"}
const THOUGHT_HOLD := 3.5
const ICON_MOON := "res://assets/icons/moon.svg"
const ICON_SUN := "res://assets/icons/sun.svg"

var _cooldown_timer: float = 0.0
var _is_sleeping: bool = false
var _bond_level: int = 0   # 0 until the first broadcast, so loading never toasts
var _crit_fill: StyleBox
var _crit_row: StyleBoxFlat
var _thought_tween: Tween


func _ready() -> void:
	EventBus.stat_changed.connect(_on_stat_changed)
	EventBus.sleeping_changed.connect(_on_sleeping_changed)
	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.bond_level_changed.connect(_on_bond_level_changed)
	EventBus.bond_progress_changed.connect(_on_bond_progress)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	EventBus.pet_name_changed.connect(_on_pet_name_changed)
	EventBus.personality_updated.connect(_on_personality_updated)
	EventBus.trait_revealed.connect(_on_trait_revealed)
	EventBus.pet_thought.connect(_on_pet_thought)

	# Buttons emit straight to the EventBus — no Pet reference needed.
	%FeedButton.pressed.connect(_on_action_button_pressed.bind(EventBus.pet_fed))
	%PlayButton.pressed.connect(_on_action_button_pressed.bind(EventBus.pet_played))
	%SleepButton.pressed.connect(_on_sleep_button_pressed)
	%PetButton.pressed.connect(_on_action_button_pressed.bind(EventBus.pet_petted))
	%SettingsButton.pressed.connect(_on_settings_pressed)

	_crit_fill = StyleBoxKnit.new()
	_crit_fill.bg_color = P.CRIT
	_crit_fill.stripe_color = Color(1, 1, 1, 0.22)
	_crit_row = (%HungerRow.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	_crit_row.bg_color = P.CRIT_ROW

	%TraitTag.resized.connect(func() -> void: %TraitTag.pivot_offset = %TraitTag.size * 0.5)
	%Thought.hide()
	# Bars start empty — Room.gd calls Pet.broadcast_stats() once both are ready.
	for stat in STATS:
		_bar(stat).value = 0.0


func _process(delta: float) -> void:
	if _cooldown_timer <= 0.0:
		return
	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		_set_buttons_disabled(false)


# ─── Actions ──────────────────────────────────────────────────────────────────

func _on_action_button_pressed(signal_to_emit: Signal) -> void:
	signal_to_emit.emit()
	_start_cooldown()


func _on_sleep_button_pressed() -> void:
	if _is_sleeping:
		EventBus.pet_woken.emit()
	else:
		EventBus.pet_slept.emit()
		_start_cooldown()


func _on_sleeping_changed(is_sleeping: bool) -> void:
	_is_sleeping = is_sleeping
	%SleepLabel.text = "ACTION_WAKE" if is_sleeping else "ACTION_SLEEP"
	%SleepButton.icon_path = ICON_SUN if is_sleeping else ICON_MOON
	# While sleeping, only the sleep button (now "wake") stays usable.
	%FeedButton.disabled = is_sleeping
	%PlayButton.disabled = is_sleeping
	%PetButton.disabled = is_sleeping
	if is_sleeping:
		_hide_thought()


func _start_cooldown() -> void:
	_cooldown_timer = GameConfig.INTERACTION_COOLDOWN
	_set_buttons_disabled(true)


func _set_buttons_disabled(disabled: bool) -> void:
	# The sleep button is managed by _on_sleeping_changed while asleep.
	%FeedButton.disabled = disabled or _is_sleeping
	%PlayButton.disabled = disabled or _is_sleeping
	%PetButton.disabled = disabled or _is_sleeping
	if not _is_sleeping:
		%SleepButton.disabled = disabled


func _on_settings_pressed() -> void:
	add_child(SETTINGS.instantiate())


# ─── Stats ────────────────────────────────────────────────────────────────────

func _bar(stat: String) -> ProgressBar:
	return get_node("%" + STATS[stat] + "Bar")


func _on_stat_changed(stat_name: String, new_value: float, old_value: float) -> void:
	if not STATS.has(stat_name):
		return
	var key: String = STATS[stat_name]
	var bar := _bar(stat_name)
	# Animate big jumps (interaction gains); apply gradual decay instantly so the
	# bar doesn't spawn a fresh tween on every decay frame.
	if absf(new_value - old_value) > 3.0:
		create_tween().tween_property(bar, "value", new_value, 0.35) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		bar.value = new_value

	var crit := new_value <= GameConfig.CRITICAL_THRESHOLD
	var value_label: Label = get_node("%" + key + "Value")
	value_label.text = str(roundi(new_value))
	var row: PanelContainer = get_node("%" + key + "Row")
	if crit:
		bar.add_theme_stylebox_override("fill", _crit_fill)
		value_label.add_theme_color_override("font_color", P.CRIT_TEXT)
		row.add_theme_stylebox_override("panel", _crit_row)
	else:
		bar.remove_theme_stylebox_override("fill")
		value_label.remove_theme_color_override("font_color")
		row.remove_theme_stylebox_override("panel")
	get_node("%" + FIXES[stat_name]).alert = crit


# ─── Header ───────────────────────────────────────────────────────────────────

func _on_pet_name_changed(pet_name: String) -> void:
	%NameLabel.text = pet_name


func _on_bond_level_changed(level: int) -> void:
	if _bond_level > 0 and level > _bond_level:
		_toast().show_level(level)
	_bond_level = level
	%LevelLabel.text = tr("BOND_CHIP") % level


func _on_bond_progress(ratio: float) -> void:
	create_tween().tween_property(%BondBar, "value", ratio * 100.0, 0.35) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Shows/updates the trait tag ("Glotona", etc.); hidden while equilibrada.
func _on_personality_updated(profile: Dictionary) -> void:
	var dom: String = profile.get("dominant", "")
	%TraitTag.visible = dom != ""
	if dom != "":
		%TraitLabel.text = "TRAIT_NAME_" + dom


func _on_locale_changed() -> void:
	if _bond_level > 0:
		%LevelLabel.text = tr("BOND_CHIP") % _bond_level


# ─── Moments ──────────────────────────────────────────────────────────────────

func _toast() -> Node:
	var t := TOAST.instantiate()
	%Toasts.add_child(t)
	return t


func _on_achievement_unlocked(_id: String, title_key: String) -> void:
	_toast().show_achievement(title_key)


func _on_trait_revealed(trait_id: String) -> void:
	_toast().show_trait(trait_id)


func _on_pet_thought(text: String, _kind: String) -> void:
	if _is_sleeping:
		return
	%ThoughtLabel.text = text
	if _thought_tween:
		_thought_tween.kill()
	%Thought.show()
	%Thought.modulate.a = 0.0
	_thought_tween = create_tween()
	_thought_tween.tween_property(%Thought, "modulate:a", 1.0, 0.25)
	_thought_tween.tween_interval(THOUGHT_HOLD)
	_thought_tween.tween_property(%Thought, "modulate:a", 0.0, 0.4)
	_thought_tween.tween_callback(%Thought.hide)


func _hide_thought() -> void:
	if _thought_tween:
		_thought_tween.kill()
	%Thought.hide()
