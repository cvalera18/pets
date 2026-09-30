## HUD.gd
## Heads-up display in the felt style — header (name, bond, trait), stat rows,
## thought bubble, toasts, the costurero and its trays. Layout and styling live
## in HUD.tscn + the felt Theme; this script only wires state to it.
##
## No fixed action bar: the costurero (bottom right) opens a fan of actions, and
## the bowl and the toy basket in the room open their tray directly. Mochi never
## talks: her thought bubble holds a drawing (FeltPicto) and gestures are shown
## by the ghost hand (GhostHand).
##
## The stat bars stay out of the way: a small tab of stat badges (alert ring when
## critical) opens the full card on tap, and a stat that goes up peeks its own
## row for a moment, so caring shows its effect without a wall of bars.
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
const FeltFood := preload("res://theme/felt/FeltFood.gd")

## food id → its FeltFood node on the food tray.
const FOODS := {"tuna": "TunaFood", "chicken": "ChickenFood", "kibble": "KibbleFood", "carrot": "CarrotFood"}

## stat → node-name prefix in HUD.tscn.
const STATS := {"hunger": "Hunger", "happiness": "Happiness", "energy": "Energy", "affection": "Affection"}
const THOUGHT_HOLD := 3.5
const PEEK_HOLD := 2.5      # seconds a rising stat's row stays after its last rise
const EXPAND_HOLD := 8.0    # the open card folds back on its own after this
const STATS_GAP := 6.0
const RADIAL_RADIUS := 170.0
const RADIAL_STEP := 30.0   # degrees between the costurero's actions, from its left going up

var _is_sleeping: bool = false
var _bond_level: int = 0   # 0 until the first broadcast, so loading never toasts
var _crit_fill: StyleBox
var _crit_row: StyleBoxFlat
var _thought_tween: Tween

var _expanded := false
var _expand_left := 0.0
var _peek := {}         # stat -> seconds its row keeps peeking
var _tab_badges := {}   # stat -> the tab's copy of that row's badge
var _stats_tween: Tween
var _tab_tween: Tween

var _ghost: FeltFood = null   # the food following your finger while you drag it
var _drag_food := ""
var _served := false
var _drag_hint_shown := false
var _play_active := false
var _radial_tween: Tween


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
	# A feeling pops where her thought bubble sits, and replaces the thought.
	EventBus.reaction_requested.connect(func(_kind: String, _at: Vector2) -> void: _hide_thought())

	%Costurero.pressed.connect(func() -> void: _open_radial(not %Radial.visible))
	%Scrim.gui_input.connect(_on_scrim_input)
	%FoodButton.pressed.connect(_show_tray.bind("food"))
	%ToysButton.pressed.connect(_show_tray.bind("toys"))
	%FoodsBack.pressed.connect(_show_tray.bind(""))
	%ToysBack.pressed.connect(_show_tray.bind(""))
	%WandToy.gui_input.connect(_on_wand_toy_input)
	EventBus.tray_requested.connect(_on_tray_requested)
	EventBus.hint_requested.connect(%GhostHand.play)
	# In the food tray you drag a food to the bowl.
	for food in FOODS:
		get_node("%" + FOODS[food]).gui_input.connect(_on_food_input.bind(food))
	EventBus.food_served.connect(func(_food: String) -> void: _served = true)
	EventBus.taste_discovered.connect(_on_taste_discovered)
	EventBus.play_mode_changed.connect(_on_play_mode_changed)
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

	# The tab reuses each row's badge so the look lives in one place (HUD.tscn),
	# a bit bigger, with its stitched ring working as a gauge of the stat.
	for stat in STATS:
		var badge = _row(stat).get_node("Items/Badge").duplicate()
		badge.diameter = 36.0
		badge.icon_size = 19.0
		badge.ring_inset = 3.5
		badge.ring_width = 2.0
		badge.ring_color.a = 1.0
		badge.ring_empty_alpha = 0.16
		%TabBadges.add_child(badge)
		_tab_badges[stat] = badge
	%StatsTab.gui_input.connect(_on_stats_input)
	%Stats.gui_input.connect(_on_stats_input)
	%StatsTab.resized.connect(_place_stats)
	%Stats.visible = false
	_refresh_stats()


func _process(delta: float) -> void:
	_tick_stats(delta)


# ─── Costurero and trays ──────────────────────────────────────────────────────

func _on_play_mode_changed(active: bool) -> void:
	_play_active = active
	if active:
		_show_tray("")


## While Mochi sleeps you can't play; you can still fill her bowl (she'll eat
## when she wakes), stroke her gently or wake her with a tap (she'll be grumpy).
func _on_sleeping_changed(is_sleeping: bool) -> void:
	_is_sleeping = is_sleeping
	if is_sleeping:
		_hide_thought()


## The costurero's actions fan out in an arc from its left going up, each with its
## name on a felt tag; the room dims behind them and a tap there closes them.
func _open_radial(on: bool) -> void:
	if on == %Radial.visible:
		return
	%CostureroIcon.kind = "cerrar" if on else "costurero"
	if _radial_tween:
		_radial_tween.kill()
	%Radial.visible = on
	if not on:
		return
	var center: Vector2 = %Costurero.get_global_rect().get_center() - %Radial.global_position
	%Scrim.modulate.a = 0.0
	_radial_tween = create_tween().set_parallel()
	_radial_tween.tween_property(%Scrim, "modulate:a", 1.0, 0.2)
	var items: Array[Control] = [$Control/Radial/FoodItem, $Control/Radial/ToysItem]
	for i in items.size():
		var item := items[i]
		var angle := deg_to_rad(180.0 + RADIAL_STEP * i)
		_place_tag(item.get_node("Tag"), angle)
		item.position = center
		item.scale = Vector2.ONE * 0.4
		item.modulate.a = 0.0
		var delay := 0.04 * i
		_radial_tween.tween_property(item, "position", center + Vector2.from_angle(angle) * RADIAL_RADIUS, 0.22) \
				.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_radial_tween.tween_property(item, "scale", Vector2.ONE, 0.22).set_delay(delay)
		_radial_tween.tween_property(item, "modulate:a", 1.0, 0.12).set_delay(delay)


## Tags sit on the outside of the arc: left of the lower actions, above the higher ones.
func _place_tag(tag: Control, angle: float) -> void:
	var tag_size := tag.get_combined_minimum_size()
	tag.size = tag_size
	if angle < deg_to_rad(225.0):
		tag.position = Vector2(-35.0 - tag_size.x, -tag_size.y * 0.5)
	else:
		tag.position = Vector2(-tag_size.x * 0.5, -35.0 - tag_size.y)


func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_open_radial(false)


## The tray at the bottom holds the foods or the toys ("" closes it); the
## costurero steps aside while it's open.
func _show_tray(which: String) -> void:
	_open_radial(false)
	%Foods.visible = which == "food"
	%Toys.visible = which == "toys"
	%Tray.visible = which != ""
	%Costurero.visible = which == ""
	_fit_tray.call_deferred()
	if which == "food" and not _drag_hint_shown:
		_drag_hint_shown = true
		_hint_food()


## The tray hangs from the bottom edge: its height has to follow the row it shows,
## and a bottom-anchored panel doesn't grow back on its own once it was emptied.
func _fit_tray() -> void:
	%Tray.offset_top = %Tray.offset_bottom - %Tray.get_combined_minimum_size().y


## The first time the food tray opens, the ghost hand drags a food to the bowl.
func _hint_food() -> void:
	await get_tree().process_frame
	EventBus.food_hint_wanted.emit((%TunaFood as Control).get_global_rect().get_center())


## The bowl and the toy basket in the room open their tray; with the wand out,
## tapping the basket puts it back.
func _on_tray_requested(which: String) -> void:
	if which == "toys" and _play_active:
		EventBus.play_requested.emit()
		return
	_show_tray(which)


func _on_wand_toy_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_tray("")
		if _play_active or not _is_sleeping:
			EventBus.play_requested.emit()


# ─── Food tray (drag a food to the bowl) ──────────────────────────────────────


## A discovered taste marks its food on the row (heart = favorite, cross = won't eat).
func _on_taste_discovered(food: String, taste: String) -> void:
	(get_node("%" + FOODS[food]) as FeltFood).taste = taste


func _on_food_input(event: InputEvent, food: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(food, event.global_position)
		elif _ghost:
			_end_drag(event.global_position)
	elif event is InputEventMouseMotion and _ghost:
		_ghost.position = event.global_position - _ghost.size * 0.5


func _start_drag(food: String, at: Vector2) -> void:
	_drag_food = food
	_ghost = FeltFood.new()
	_ghost.food = food
	_ghost.size = Vector2(64, 64)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Control.add_child(_ghost)
	_ghost.position = at - _ghost.size * 0.5
	get_node("%" + FOODS[food]).modulate.a = 0.35


## Dropped on the bowl: the food goes in and the row closes. Anywhere else: it
## flies back to its place.
func _end_drag(at: Vector2) -> void:
	var ghost := _ghost
	var slot: Control = get_node("%" + FOODS[_drag_food])
	_ghost = null
	_served = false
	EventBus.food_dropped.emit(_drag_food, at)
	var tween := create_tween()
	if _served:
		ghost.pivot_offset = ghost.size * 0.5
		tween.tween_property(ghost, "scale", Vector2.ZERO, 0.15)
		_show_tray("")
	else:
		tween.tween_property(ghost, "global_position", slot.global_position + (slot.size - ghost.size) * 0.5, 0.2)
	tween.tween_callback(ghost.queue_free)
	tween.tween_callback(func() -> void: slot.modulate.a = 1.0)


func _on_settings_pressed() -> void:
	add_child(SETTINGS.instantiate())


# ─── Stats ────────────────────────────────────────────────────────────────────

func _bar(stat: String) -> ProgressBar:
	return get_node("%" + STATS[stat] + "Bar")


func _row(stat: String) -> PanelContainer:
	return get_node("%" + STATS[stat] + "Row")


func _on_stats_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_expanded = not _expanded
		_expand_left = EXPAND_HOLD
		_refresh_stats()


## Stats only ever fall on their own, so any rise is care: show that row a moment.
func _peek_stat(stat: String) -> void:
	var fresh := not _peek.has(stat)
	_peek[stat] = PEEK_HOLD
	if fresh and not _expanded:
		_refresh_stats()


func _tick_stats(delta: float) -> void:
	var changed := false
	if _expanded:
		_expand_left -= delta
		if _expand_left <= 0.0:
			_expanded = false
			changed = true
	for stat in _peek.keys():
		_peek[stat] -= delta
		if _peek[stat] <= 0.0:
			_peek.erase(stat)
			changed = true
	if changed:
		_refresh_stats()


## Collapsed: only the tab. Peeking: the tab plus the rising rows under it.
## Open: the full card in the tab's place (tap it to fold it back). The card
## fades in and out, and the tab fades back in as the open card folds away.
func _refresh_stats() -> void:
	var any := _expanded or not _peek.is_empty()
	if _stats_tween:
		_stats_tween.kill()
	if any:
		for stat in STATS:
			_row(stat).visible = _expanded or _peek.has(stat)
		if not %Stats.visible:
			%Stats.modulate.a = 0.0
			%Stats.visible = true
		_place_stats()
		_stats_tween = create_tween()
		_stats_tween.tween_property(%Stats, "modulate:a", 1.0, 0.18)
	elif %Stats.visible:
		# Fade out where it stands; rows and position change only once it's gone.
		_stats_tween = create_tween()
		_stats_tween.tween_property(%Stats, "modulate:a", 0.0, 0.35)
		_stats_tween.tween_callback(_after_stats_faded)
	_show_tab(not _expanded)


func _after_stats_faded() -> void:
	%Stats.visible = false
	_place_stats()


func _show_tab(on: bool) -> void:
	if on == %StatsTab.visible:
		return
	if _tab_tween:
		_tab_tween.kill()
	%StatsTab.visible = on
	if on:
		%StatsTab.modulate.a = 0.0
		_tab_tween = create_tween()
		_tab_tween.tween_property(%StatsTab, "modulate:a", 1.0, 0.3)


func _place_stats() -> void:
	var top: float = %StatsTab.offset_top
	if not _expanded:
		top += %StatsTab.size.y + STATS_GAP
	%Stats.offset_top = top
	%Stats.offset_bottom = top


func _on_stat_changed(stat_name: String, new_value: float, old_value: float) -> void:
	if not STATS.has(stat_name):
		return
	if new_value > old_value:
		_peek_stat(stat_name)
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
	_tab_badges[stat_name].alert = crit
	_tab_badges[stat_name].ring_fill = new_value / GameConfig.STAT_MAX


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


func _on_pet_thought(kind: String) -> void:
	if _is_sleeping:
		return
	%ThoughtPicto.kind = kind
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
