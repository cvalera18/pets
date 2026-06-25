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

# Rounded horizontal-gradient progress bar, drawn in one ColorRect. The gradient
# is fixed across the full bar width and clipped at `value` (0..1); the rest shows
# the track. `bar_size` (px) must track the control size for correct rounded ends.
const BAR_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_mix;

uniform vec4 fill_a : source_color = vec4(1.0);
uniform vec4 fill_b : source_color = vec4(1.0);
uniform vec4 track_color : source_color = vec4(0.0);
uniform float value = 0.0;
uniform vec2 bar_size = vec2(100.0, 8.0);

void fragment() {
	vec2 p = (UV - 0.5) * bar_size;
	float r = bar_size.y * 0.5;
	float half_len = max(bar_size.x * 0.5 - r, 0.0);
	vec2 q = vec2(max(abs(p.x) - half_len, 0.0), p.y);
	float d = length(q) - r;
	float cov = clamp(0.5 - d, 0.0, 1.0);
	if (cov <= 0.0) {
		discard;
	}
	vec3 grad = mix(fill_a.rgb, fill_b.rgb, clamp(UV.x, 0.0, 1.0));
	bool filled = UV.x <= value;
	vec3 rgb = filled ? grad : track_color.rgb;
	float a = filled ? 1.0 : track_color.a;
	COLOR = vec4(rgb, a * cov);
}
"""

# Rounded-rect with a 2-stop gradient along grad_dir (no value clip) — the action
# buttons' inner circle: a soft ~160° light→deep fill instead of a flat color.
const RECT_GRAD_SHADER_CODE := """
shader_type canvas_item;
render_mode blend_mix;

uniform vec4 col_a : source_color = vec4(1.0);
uniform vec4 col_b : source_color = vec4(1.0);
uniform vec2 rect_size = vec2(40.0, 40.0);
uniform float radius = 20.0;
uniform vec2 grad_dir = vec2(-0.3, 0.95);

void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	vec2 b = rect_size * 0.5 - vec2(radius);
	vec2 q = abs(p) - b;
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float cov = clamp(0.5 - d, 0.0, 1.0);
	if (cov <= 0.0) {
		discard;
	}
	float t = clamp(dot(UV - 0.5, normalize(grad_dir)) + 0.5, 0.0, 1.0);
	COLOR = vec4(mix(col_a.rgb, col_b.rgb, t), cov);
}
"""

var _cooldown_timer: float = 0.0
var _bar_mats: Dictionary = {}
var _action_labels: Dictionary = {}
var _bar_shader: Shader
var _rect_grad_shader: Shader
var _value_labels: Dictionary = {}
var _stat_labels: Dictionary = {}
var _icon_styles: Dictionary = {}
var _cards: Dictionary = {}
var _pulse: Dictionary = {}
var _is_sleeping: bool = false
var _settings_button: Button
var _name_label: Label
var _bond_label: Label
var _bond_bar: ColorRect
var _bond_bar_mat: ShaderMaterial
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
	EventBus.bond_progress_changed.connect(_on_bond_progress)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	EventBus.pet_name_changed.connect(_on_pet_name_changed)

	_bar_shader = Shader.new()
	_bar_shader.code = BAR_SHADER_CODE
	_rect_grad_shader = Shader.new()
	_rect_grad_shader.code = RECT_GRAD_SHADER_CODE

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
	if _action_labels.has("sleep"):
		_action_labels["sleep"].text = tr("ACTION_WAKE") if is_sleeping else tr("ACTION_SLEEP")
	# While sleeping, disable all buttons except sleep (which becomes Wake).
	feed_button.disabled  = is_sleeping
	play_button.disabled  = is_sleeping
	pet_button.disabled   = is_sleeping


## Adds a small settings entry button (top-right) that opens the Settings overlay.
func _create_settings_button() -> void:
	_settings_button = Button.new()
	_settings_button.icon = Icons.gear
	_settings_button.expand_icon = true
	_settings_button.custom_minimum_size = Vector2(46, 46)
	_settings_button.anchor_left = 1.0
	_settings_button.anchor_right = 1.0
	_settings_button.offset_left = -60.0
	_settings_button.offset_right = -14.0
	_settings_button.offset_top = 14.0
	_settings_button.offset_bottom = 60.0
	_settings_button.add_theme_stylebox_override("normal", _card_sb(PAL.CARD, 16, 4))
	_settings_button.add_theme_stylebox_override("hover", _card_sb(PAL.CARD.lightened(0.04), 16, 4))
	_settings_button.add_theme_stylebox_override("pressed", _card_sb(PAL.CARD.darkened(0.05), 16, 1))
	_settings_button.add_theme_color_override("icon_normal_color", PAL.TEXT_MUTED)
	_settings_button.add_theme_color_override("icon_pressed_color", PAL.ACCENT_DEEP)
	_settings_button.pressed.connect(_on_settings_pressed)
	$Control.add_child(_settings_button)


func _on_settings_pressed() -> void:
	add_child(SETTINGS.instantiate())


## Top-left status panel: the pet's name above its bond-level badge.
func _create_status_panel() -> void:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _card_sb(PAL.CARD, 20, 4))
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

	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var chsb := StyleBoxFlat.new()
	chsb.bg_color = PAL.BOND_BADGE_BG
	chsb.set_corner_radius_all(9)
	chsb.content_margin_left = 8
	chsb.content_margin_right = 9
	chsb.content_margin_top = 3
	chsb.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", chsb)
	var bondrow := HBoxContainer.new()
	bondrow.add_theme_constant_override("separation", 7)
	box.add_child(bondrow)
	bondrow.add_child(chip)

	var chrow := HBoxContainer.new()
	chrow.add_theme_constant_override("separation", 4)
	chip.add_child(chrow)

	var heart := TextureRect.new()
	heart.texture = Icons.heart
	heart.modulate = PAL.BOND_BADGE_FG
	heart.custom_minimum_size = Vector2(11, 11)
	heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chrow.add_child(heart)

	_bond_label = Label.new()
	_bond_label.text = tr("BOND_CHIP") % _bond_level
	_bond_label.add_theme_font_size_override("font_size", 11)
	_bond_label.add_theme_color_override("font_color", PAL.BOND_BADGE_FG)
	chrow.add_child(_bond_label)

	_bond_bar = ColorRect.new()
	_bond_bar.color = Color.WHITE
	_bond_bar.custom_minimum_size = Vector2(54, 6)
	_bond_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bond_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bond_bar_mat = ShaderMaterial.new()
	_bond_bar_mat.shader = _bar_shader
	_bond_bar_mat.set_shader_parameter("fill_a", PAL.BOND_A)
	_bond_bar_mat.set_shader_parameter("fill_b", PAL.BOND_B)
	_bond_bar_mat.set_shader_parameter("track_color", Color(0.35, 0.27, 0.22, 0.16))
	_bond_bar_mat.set_shader_parameter("value", 0.0)
	_bond_bar_mat.set_shader_parameter("bar_size", Vector2(54, 6))
	_bond_bar.material = _bond_bar_mat
	_bond_bar.resized.connect(func() -> void: _bond_bar_mat.set_shader_parameter("bar_size", _bond_bar.size))
	bondrow.add_child(_bond_bar)


func _on_pet_name_changed(pet_name: String) -> void:
	_pet_name = pet_name
	_name_label.text = pet_name


func _on_bond_level_changed(level: int) -> void:
	_bond_level = level
	_bond_label.text = tr("BOND_CHIP") % level


func _on_bond_progress(ratio: float) -> void:
	if _bond_bar_mat != null:
		_bond_bar_mat.set_shader_parameter("value", ratio)


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
	_bond_label.text = tr("BOND_CHIP") % _bond_level


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
	if not _bar_mats.has(stat_name):
		return
	var mat: ShaderMaterial = _bar_mats[stat_name]

	# Animate big jumps (interaction gains); apply gradual decay instantly so the
	# bar doesn't spawn a fresh tween on every decay frame.
	var target := value / 100.0
	if absf(value - old_value) > 3.0:
		var from_v: float = mat.get_shader_parameter("value")
		create_tween().tween_method(
				func(v: float) -> void: mat.set_shader_parameter("value", v),
				from_v, target, 0.35) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		mat.set_shader_parameter("value", target)

	var crit := value <= GameConfig.CRITICAL_THRESHOLD
	var grad := _stat_grad(stat_name, value)
	mat.set_shader_parameter("fill_a", grad[0])
	mat.set_shader_parameter("fill_b", grad[1])
	if _icon_styles.has(stat_name):
		_icon_styles[stat_name].bg_color = PAL.TIER_CRIT_B if crit else _stat_base(stat_name)
	if _value_labels.has(stat_name):
		_value_labels[stat_name].text = str(roundi(value))
		_value_labels[stat_name].add_theme_color_override(
				"font_color", PAL.TIER_CRIT_B if crit else PAL.TEXT_MUTED)

	# Gently pulse a card while its stat is critical.
	if crit and not _pulse.has(stat_name) and _cards.has(stat_name):
		var pt := create_tween().set_loops()
		pt.tween_property(_cards[stat_name], "modulate", Color(1.0, 0.85, 0.83), 0.7) \
				.set_trans(Tween.TRANS_SINE)
		pt.tween_property(_cards[stat_name], "modulate", Color.WHITE, 0.7) \
				.set_trans(Tween.TRANS_SINE)
		_pulse[stat_name] = pt
	elif not crit and _pulse.has(stat_name):
		_pulse[stat_name].kill()
		_pulse.erase(stat_name)
		if _cards.has(stat_name):
			_cards[stat_name].modulate = Color.WHITE


## Bar gradient ends [a, b]: the stat's own hue pair, turning red when critical.
func _stat_grad(stat: String, value: float) -> Array:
	if value <= GameConfig.CRITICAL_THRESHOLD:
		return [PAL.TIER_CRIT_A, PAL.TIER_CRIT_B]
	match stat:
		"hunger":    return [PAL.HUNGER_A, PAL.HUNGER_B]
		"happiness": return [PAL.HAPPY_A, PAL.HAPPY_B]
		"energy":    return [PAL.ENERGY_A, PAL.ENERGY_B]
		"affection": return [PAL.AFFECTION_A, PAL.AFFECTION_B]
	return [PAL.HUNGER_A, PAL.HUNGER_B]


## The stat's own icon-square hue (healthy state).
func _stat_base(stat: String) -> Color:
	match stat:
		"hunger":    return PAL.HUNGER
		"happiness": return PAL.HAPPY
		"energy":    return PAL.ENERGY
		"affection": return PAL.AFFECTION
	return PAL.HUNGER


# ─── Cozy theme (StyleBoxFlat) ────────────────────────────────────────────────

func _apply_theme() -> void:
	# Replace the old stat list with the cozy 2×2 card grid.
	$Control/StatsPanel.hide()
	_build_stat_grid()

	for b in [feed_button, play_button, sleep_button, pet_button]:
		_style_button(b)

	_action_labels["feed"]  = _decorate_action(feed_button,  Icons.bowl,  Color("f0b98e"), Color("e2925e"))
	_action_labels["play"]  = _decorate_action(play_button,  Icons.ball,  Color("f4d079"), Color("e7b24b"))
	_action_labels["sleep"] = _decorate_action(sleep_button, Icons.moon,  Color("a6c3e2"), Color("7ba0ce"))
	_action_labels["pet"]   = _decorate_action(pet_button,   Icons.heart, Color("eba6ba"), Color("db85a0"))


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


## Builds the 2×2 grid of stat cards (icon square + label + value + bar).
func _build_stat_grid() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 11)
	grid.add_theme_constant_override("v_separation", 11)
	grid.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	grid.offset_left = 16.0
	grid.offset_right = -16.0
	grid.offset_top = 96.0
	$Control.add_child(grid)

	_make_stat_card(grid, "hunger", Icons.bowl, PAL.HUNGER, "STAT_HUNGER")
	_make_stat_card(grid, "happiness", Icons.star, PAL.HAPPY, "STAT_HAPPINESS")
	_make_stat_card(grid, "energy", Icons.bolt, PAL.ENERGY, "STAT_ENERGY")
	_make_stat_card(grid, "affection", Icons.heart, PAL.AFFECTION, "STAT_AFFECTION")


func _make_stat_card(parent: Node, stat: String, icon: Texture2D, color: Color, label_key: String) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_sb(PAL.CARD, 18, 3))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	_cards[stat] = card

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	v.add_child(row)

	var sq := Panel.new()
	sq.custom_minimum_size = Vector2(26, 26)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = color
	ssb.set_corner_radius_all(9)
	sq.add_theme_stylebox_override("panel", ssb)
	_icon_styles[stat] = ssb
	row.add_child(sq)
	var ic := TextureRect.new()
	ic.texture = icon
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(5.5, 5.5)
	ic.size = Vector2(15, 15)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sq.add_child(ic)

	var lbl := Label.new()
	lbl.text = tr(label_key)
	if Fonts.body_strong != null:
		lbl.add_theme_font_override("font", Fonts.body_strong)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", PAL.TEXT_BODY)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	_stat_labels[stat] = lbl

	var val := Label.new()
	if Fonts.display != null:
		val.add_theme_font_override("font", Fonts.display)
	val.add_theme_font_size_override("font_size", 13)
	val.add_theme_color_override("font_color", PAL.TEXT_MUTED)
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val)
	_value_labels[stat] = val

	var bar := ColorRect.new()
	bar.color = Color.WHITE
	bar.custom_minimum_size = Vector2(0, 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _bar_shader
	mat.set_shader_parameter("fill_a", color)
	mat.set_shader_parameter("fill_b", color)
	mat.set_shader_parameter("track_color", Color(0.35, 0.27, 0.22, 0.14))
	mat.set_shader_parameter("value", 0.0)
	mat.set_shader_parameter("bar_size", Vector2(100, 8))
	bar.material = mat
	bar.resized.connect(func() -> void: mat.set_shader_parameter("bar_size", bar.size))
	v.add_child(bar)
	_bar_mats[stat] = mat


## Turns a plain action Button into a cozy card: a colored circle with a white
## icon above the label. Returns the label so it can be re-translated later.
func _decorate_action(btn: Button, icon: Texture2D, grad_a: Color, grad_b: Color) -> Label:
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, 66)

	# Chunky "bottom-lip" look (design's `0 6px 0` shadow): a hue-matched colored
	# base under the white card, kept above the existing soft drop shadow.
	for state in ["normal", "hover"]:
		var lip: StyleBoxFlat = _card_sb(
				PAL.CARD if state == "normal" else PAL.CARD.lightened(0.04), 22, 5)
		lip.set_border_width_all(0)
		lip.border_width_bottom = 5
		lip.border_color = grad_b
		btn.add_theme_stylebox_override(state, lip)
	var press: StyleBoxFlat = _card_sb(PAL.CARD.darkened(0.04), 22, 1)
	press.set_border_width_all(0)
	press.border_width_bottom = 2
	press.border_color = grad_b
	btn.add_theme_stylebox_override("pressed", press)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	btn.add_child(box)

	# Inner circle: a ~160° light→deep gradient via the rounded-rect shader.
	var circle := ColorRect.new()
	circle.color = Color.WHITE
	circle.custom_minimum_size = Vector2(40, 40)
	circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cmat := ShaderMaterial.new()
	cmat.shader = _rect_grad_shader
	cmat.set_shader_parameter("col_a", grad_a)
	cmat.set_shader_parameter("col_b", grad_b)
	cmat.set_shader_parameter("rect_size", Vector2(40, 40))
	cmat.set_shader_parameter("radius", 20.0)
	cmat.set_shader_parameter("grad_dir", Vector2(-0.3, 0.95))
	circle.material = cmat
	circle.resized.connect(func() -> void: cmat.set_shader_parameter("rect_size", circle.size))
	box.add_child(circle)

	var ic := TextureRect.new()
	ic.texture = icon
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.position = Vector2(9, 9)
	ic.size = Vector2(22, 22)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.add_child(ic)

	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if Fonts.body_strong != null:
		lbl.add_theme_font_override("font", Fonts.body_strong)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", PAL.TEXT_BODY)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	return lbl


## Refreshes all text labels. Call again if the locale changes at runtime.
func _refresh_labels() -> void:
	if not _stat_labels.is_empty():
		_stat_labels["hunger"].text    = tr("STAT_HUNGER")
		_stat_labels["happiness"].text = tr("STAT_HAPPINESS")
		_stat_labels["energy"].text    = tr("STAT_ENERGY")
		_stat_labels["affection"].text = tr("STAT_AFFECTION")

	if not _action_labels.is_empty():
		_action_labels["feed"].text  = tr("ACTION_FEED")
		_action_labels["play"].text  = tr("ACTION_PLAY")
		_action_labels["sleep"].text = tr("ACTION_WAKE") if _is_sleeping else tr("ACTION_SLEEP")
		_action_labels["pet"].text   = tr("ACTION_PET")
