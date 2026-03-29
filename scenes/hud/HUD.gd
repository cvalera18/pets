## HUD.gd
## Heads-up display — stat bars and action buttons.
##
## HUD subscribes to EventBus.stat_changed to update bar values in real time.
## Buttons emit EventBus signals — HUD holds no reference to Pet whatsoever.
##
## All displayed strings use tr() so they respond to locale changes automatically.
## Add new keys to i18n/en.po and i18n/es.po when adding UI text here.
extends CanvasLayer


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
	feed_button.pressed.connect(EventBus.pet_fed.emit)
	play_button.pressed.connect(EventBus.pet_played.emit)
	sleep_button.pressed.connect(EventBus.pet_slept.emit)
	pet_button.pressed.connect(EventBus.pet_petted.emit)

	_refresh_labels()
	_init_bars()


# ─── Private ──────────────────────────────────────────────────────────────────

func _on_stat_changed(stat_name: String, new_value: float, _old_value: float) -> void:
	_set_bar(stat_name, new_value)


func _init_bars() -> void:
	for stat in ["hunger", "happiness", "energy", "affection"]:
		_set_bar(stat, GameConfig.STAT_MAX)


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
