## HUD.gd
## Heads-up display — stat bars and action buttons.
##
## HUD subscribes to EventBus.stat_changed to update bar values in real time.
## Buttons emit EventBus signals — HUD holds no reference to Pet whatsoever.
##
## All displayed strings use tr() so they respond to locale changes automatically.
## Add new keys to i18n/en.po and i18n/es.po when adding UI text here.
extends CanvasLayer

const SETTINGS := preload("res://scenes/ui/Settings.tscn")
const PAL := preload("res://theme/Palette.gd")

var _cooldown_timer: float = 0.0
var _bar_fills: Dictionary = {}
var _is_sleeping: bool = false
var _settings_button: Button
var _name_label: Label
var _bond_label: Label
var _bond_level: int = 1
var _pet_name: String = ""

# ─── Stat Bars ────────────────────────────────────────────────────────────────

@onready var hunger_label:    Label       = $Control/StatsPanel/HungerRow/HungerLabel
@onready var hunger_bar:      ProgressBar = $Control/StatsPanel/HungerRow/HungerBar

@onready var happiness_label:  Label       = $Control/StatsPanel/HappinessRow/HappinessLabel
@onready var happiness_bar:    ProgressBar = $Control/StatsPanel/HappinessRow/HappinessBar

@onready var energy_label:    Label       = $Control/StatsPanel/EnergyRow/EnergyLabel
@onready var energy_bar:      ProgressBar = $Control/StatsPanel/EnergyRow/EnergyBar

@onready var affection_label: Label       = $Control/StatsPanel/AffectionRow/AffectionLabel
@onready var affection_bar:   ProgressBar = $Control/StatsPanel/AffectionRow/AffectionBar

# ─── Action Buttons ───────────────────────────────────────────────────────────

@onready var feed_button:  Button = $Control/ActionButtons/FeedButton
@onready var play_button:  Button = $Control/ActionButtons/PlayButton
@onready var sleep_button: Button = $Control/ActionButtons/SleepButton
@onready var pet_button:   Button = $Control/ActionButtons/PetButton


func _ready() -> void:
	EventBus.stat_changed.connect(_on_stat_changed)

	# Wire buttons directly to EventBus signals — no Pet reference needed.
	feed_button.pressed.connect(_on_action_button_pressed.bind(EventBus.pet_fed))
	play_button.pressed.connect(_on_action_button_pressed.bind(EventBus.pet_played))
	sleep_button.pressed.connect(_on_sleep_button_pressed)
	pet_button.pressed.connect(_on_action_button_pressed.bind(EventBus.pet_petted))

	EventBus.sleeping_changed.connect(_on_sleeping_changed)
	EventBus.locale_changed.connect(_on_locale_changed)
	EventBus.bond_level_changed.connect(_on_bond_level_changed)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	EventBus.pet_name_changed.connect(_on_pet_name_changed)

	_create_settings_button()
	_create_status_panel()
	_apply_theme()
	_refresh_labels()
	_init_bars()


# ─── Private ──────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _cooldown_timer <= 0.0:
		return
	_cooldown_timer -= delta
	if _cooldown_timer <= 0.0:
		_set_buttons_disabled(false)


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
	sleep_button.text = tr("ACTION_WAKE") if is_sleeping else tr("ACTION_SLEEP")
	# While sleeping, disable all buttons except sleep (which becomes Wake).
	feed_button.disabled  = is_sleeping
	play_button.disabled  = is_sleeping
	pet_button.disabled   = is_sleeping


## Adds a small settings entry button (top-right) that opens the Settings overlay.
func _create_settings_button() -> void:
	_settings_button = Button.new()
	_settings_button.text = tr("UI_SETTINGS")
	_settings_button.set_anchors_and_offsets_preset(
			Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_settings_button.add_theme_stylebox_override("normal", _card_sb(PAL.CARD, 14, 4))
	_settings_button.add_theme_stylebox_override("hover", _card_sb(PAL.CARD.lightened(0.04), 14, 4))
	_settings_button.add_theme_stylebox_override("pressed", _card_sb(PAL.CARD.darkened(0.05), 14, 1))
	_settings_button.add_theme_color_override("font_color", PAL.TEXT_MUTED)
	_settings_button.add_theme_font_size_override("font_size", 13)
	_settings_button.pressed.connect(_on_settings_pressed)
	$Control.add_child(_settings_button)


func _on_settings_pressed() -> void:
	add_child(SETTINGS.instantiate())


## Top-left status panel: the pet's name above its bond-level badge.
func _create_status_panel() -> void:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _card_sb(PAL.CARD, 18, 4))
	pill.set_anchors_and_offsets_preset(
			Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 12)
	$Control.add_child(pill)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	pill.add_child(box)

	_name_label = Label.new()
	_name_label.text = _pet_name
	if Fonts.display != null:
		_name_label.add_theme_font_override("font", Fonts.display)
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", PAL.TEXT)
	box.add_child(_name_label)

	_bond_label = Label.new()
	_bond_label.text = tr("BOND_BADGE") % _bond_level
	_bond_label.add_theme_font_size_override("font_size", 13)
	_bond_label.add_theme_color_override("font_color", PAL.BOND_BADGE_FG)
	box.add_child(_bond_label)


func _on_pet_name_changed(pet_name: String) -> void:
	_pet_name = pet_name
	_name_label.text = pet_name


func _on_bond_level_changed(level: int) -> void:
	_bond_level = level
	_bond_label.text = tr("BOND_BADGE") % level


## Slides a celebratory toast in at top-center when a milestone unlocks.
func _on_achievement_unlocked(_id: String, title_key: String) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(
			Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 20)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	var header := Label.new()
	header.text = tr("ACHIEVEMENT_UNLOCKED")
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	box.add_child(header)

	var title := Label.new()
	title.text = tr(title_key)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	$Control.add_child(panel)

	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.2)
	tween.tween_property(panel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(panel.queue_free)


## Re-translates HUD text when the locale changes while this HUD is alive.
func _on_locale_changed() -> void:
	_refresh_labels()
	_settings_button.text = tr("UI_SETTINGS")
	_bond_label.text = tr("BOND_BADGE") % _bond_level
	sleep_button.text = tr("ACTION_WAKE") if _is_sleeping else tr("ACTION_SLEEP")


func _start_cooldown() -> void:
	_cooldown_timer = GameConfig.INTERACTION_COOLDOWN
	_set_buttons_disabled(true)


func _set_buttons_disabled(disabled: bool) -> void:
	# Don't touch sleep button here — it's managed by _on_sleeping_changed.
	feed_button.disabled  = disabled or _is_sleeping
	play_button.disabled  = disabled or _is_sleeping
	pet_button.disabled   = disabled or _is_sleeping
	if not _is_sleeping:
		sleep_button.disabled = disabled


func _on_stat_changed(stat_name: String, new_value: float, old_value: float) -> void:
	_set_bar(stat_name, new_value, old_value)


func _init_bars() -> void:
	# Bars start at 0 — Room.gd calls Pet.broadcast_stats() after both
	# pet and HUD are ready, which triggers the real initial values.
	for stat in ["hunger", "happiness", "energy", "affection"]:
		_set_bar(stat, 0.0)


func _set_bar(stat_name: String, value: float, old_value: float = value) -> void:
	var bar: ProgressBar
	match stat_name:
		"hunger":    bar = hunger_bar
		"happiness": bar = happiness_bar
		"energy":    bar = energy_bar
		"affection": bar = affection_bar
		_: return

	# Animate big jumps (interaction gains); apply gradual decay instantly so the
	# bar doesn't spawn a fresh tween on every decay frame.
	if absf(value - old_value) > 3.0:
		var tween := create_tween()
		tween.tween_property(bar, "value", value, 0.35) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		bar.value = value

	if _bar_fills.has(stat_name):
		_bar_fills[stat_name].bg_color = _bar_color(value)


## Three-tier readability tint: critical / low / healthy.
func _bar_color(value: float) -> Color:
	if value <= GameConfig.CRITICAL_THRESHOLD:
		return Color(1.0, 0.45, 0.45)   # red — critical
	elif value <= GameConfig.LOW_THRESHOLD:
		return Color(1.0, 0.80, 0.45)   # amber — low
	return Color(0.55, 0.85, 0.55)      # green — healthy


# ─── Cozy theme (StyleBoxFlat) ────────────────────────────────────────────────

func _apply_theme() -> void:
	# Lift the stat panel up under the name pill so the cozy room shows below.
	var sp: Control = $Control/StatsPanel
	sp.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sp.offset_left = 16.0
	sp.offset_right = -16.0
	sp.offset_top = 150.0
	sp.add_theme_constant_override("separation", 9)

	_style_bar(hunger_bar, "hunger")
	_style_bar(happiness_bar, "happiness")
	_style_bar(energy_bar, "energy")
	_style_bar(affection_bar, "affection")
	for lbl in [hunger_label, happiness_label, energy_label, affection_label]:
		lbl.add_theme_color_override("font_color", PAL.TEXT_BODY)
		lbl.add_theme_font_size_override("font_size", 13)

	for b in [feed_button, play_button, sleep_button, pet_button]:
		_style_button(b)


func _card_sb(color: Color, radius: int, shadow: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(10)
	sb.border_color = Color(1, 1, 1, 0.55)
	sb.set_border_width_all(1)
	if shadow > 0:
		sb.shadow_color = Color(0.59, 0.39, 0.24, 0.16)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, 4)
	return sb


func _style_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _card_sb(PAL.CARD, 18, 5))
	b.add_theme_stylebox_override("hover", _card_sb(PAL.CARD.lightened(0.04), 18, 5))
	b.add_theme_stylebox_override("pressed", _card_sb(PAL.CARD.darkened(0.05), 18, 1))
	b.add_theme_stylebox_override("disabled", _card_sb(Color(0.93, 0.89, 0.83), 18, 0))
	b.add_theme_color_override("font_color", PAL.TEXT_BODY)
	b.add_theme_color_override("font_hover_color", PAL.TEXT)
	b.add_theme_color_override("font_pressed_color", PAL.ACCENT_DEEP)
	b.add_theme_color_override("font_disabled_color", PAL.TEXT_FAINT)
	b.add_theme_font_size_override("font_size", 14)
	b.custom_minimum_size = Vector2(0, 62)


func _style_bar(bar: ProgressBar, stat: String) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.35, 0.27, 0.22, 0.15)
	track.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", track)

	var fill := StyleBoxFlat.new()
	fill.bg_color = PAL.TIER_HEALTHY_B
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	_bar_fills[stat] = fill

	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	bar.add_theme_font_size_override("font_size", 11)


## Refreshes all text labels. Call again if the locale changes at runtime.
func _refresh_labels() -> void:
	hunger_label.text    = tr("STAT_HUNGER")
	happiness_label.text = tr("STAT_HAPPINESS")
	energy_label.text    = tr("STAT_ENERGY")
	affection_label.text = tr("STAT_AFFECTION")

	feed_button.text  = tr("ACTION_FEED")
	play_button.text  = tr("ACTION_PLAY")
	sleep_button.text = tr("ACTION_SLEEP")
	pet_button.text   = tr("ACTION_PET")
