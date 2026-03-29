## HUD.gd
## Heads-up display — stat bars and action buttons.
##
## HUD subscribes to EventBus.stat_changed to update bar values in real time.
## Buttons emit EventBus signals — HUD holds no reference to Pet whatsoever.
##
## All displayed strings use tr() so they respond to locale changes automatically.
## Add new keys to i18n/en.po and i18n/es.po when adding UI text here.
extends CanvasLayer

var _cooldown_timer: float = 0.0
var _is_sleeping: bool = false

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


func _on_stat_changed(stat_name: String, new_value: float, _old_value: float) -> void:
	_set_bar(stat_name, new_value)


func _init_bars() -> void:
	# Bars start at 0 — Room.gd calls Pet.broadcast_stats() after both
	# pet and HUD are ready, which triggers the real initial values.
	for stat in ["hunger", "happiness", "energy", "affection"]:
		_set_bar(stat, 0.0)


func _set_bar(stat_name: String, value: float) -> void:
	var bar: ProgressBar
	match stat_name:
		"hunger":    bar = hunger_bar
		"happiness": bar = happiness_bar
		"energy":    bar = energy_bar
		"affection": bar = affection_bar
		_: return

	bar.value = value

	# Tint red when critical — simple visual urgency cue.
	# TODO: replace with a Theme-based StyleBox swap for more polished visuals.
	bar.modulate = Color.RED if value <= GameConfig.CRITICAL_THRESHOLD else Color.WHITE


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
