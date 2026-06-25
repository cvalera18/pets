## Onboarding.gd
## First-launch screen, restyled to the cozy design: the room backdrop + Mochi,
## a "Pets" wordmark, and a white name card with the gradient "¡Vamos!" button.
## The chosen name flows to Room via GameState.pending_pet_name (no direct refs).
extends Control

const P := preload("res://theme/Palette.gd")
const COZY_ROOM := preload("res://scenes/effects/CozyRoom.gd")
const MOCHI := preload("res://scenes/pet/Mochi.gd")
const MAX_NAME_LENGTH: int = 16
const DEFAULT_NAME: String = "Mochi"

var _name_input: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(COZY_ROOM.new())

	var mochi := MOCHI.new()
	mochi.position = Vector2(195, 320)
	mochi.scale = Vector2(1.5, 1.5)
	add_child(mochi)

	_build_wordmark()
	_build_name_card()


func _build_wordmark() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 34)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	var title := Label.new()
	title.text = "Pets"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if Fonts.display != null:
		title.add_theme_font_override("font", Fonts.display)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", P.ACCENT_DEEP)
	box.add_child(title)

	var sub := Label.new()
	sub.text = tr("ONBOARDING_TAGLINE")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", P.TEXT_FAINT)
	box.add_child(sub)


func _build_name_card() -> void:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = P.CARD
	sb.set_corner_radius_all(28)
	sb.set_content_margin_all(22)
	sb.shadow_color = Color(0.47, 0.29, 0.16, 0.18)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 8)
	card.add_theme_stylebox_override("panel", sb)
	card.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	card.offset_left = 18.0
	card.offset_right = -18.0
	card.offset_top = -212.0
	card.offset_bottom = -42.0
	add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)

	var title := Label.new()
	title.text = tr("ONBOARDING_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if Fonts.display != null:
		title.add_theme_font_override("font", Fonts.display)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", P.TEXT)
	v.add_child(title)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = tr("ONBOARDING_PLACEHOLDER")
	_name_input.text = DEFAULT_NAME
	_name_input.max_length = MAX_NAME_LENGTH
	_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_input.custom_minimum_size = Vector2(0, 52)
	if Fonts.display != null:
		_name_input.add_theme_font_override("font", Fonts.display)
	_name_input.add_theme_font_size_override("font_size", 18)
	_name_input.add_theme_color_override("font_color", P.TEXT)
	var le := StyleBoxFlat.new()
	le.bg_color = Color.WHITE
	le.set_corner_radius_all(16)
	le.set_border_width_all(2)
	le.border_color = Color("ead7c2")
	le.set_content_margin_all(12)
	_name_input.add_theme_stylebox_override("normal", le)
	var lef: StyleBoxFlat = le.duplicate()
	lef.border_color = P.ACCENT
	_name_input.add_theme_stylebox_override("focus", lef)
	_name_input.text_submitted.connect(_on_submit)
	v.add_child(_name_input)

	var go := Button.new()
	go.text = tr("ONBOARDING_CONFIRM")
	go.custom_minimum_size = Vector2(0, 54)
	if Fonts.display != null:
		go.add_theme_font_override("font", Fonts.display)
	go.add_theme_font_size_override("font_size", 18)
	go.add_theme_color_override("font_color", P.ON_ACCENT)
	go.add_theme_color_override("font_hover_color", P.ON_ACCENT)
	go.add_theme_color_override("font_pressed_color", P.ON_ACCENT)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = P.ACCENT_DEEP
	gsb.set_corner_radius_all(18)
	gsb.set_content_margin_all(8)
	gsb.border_width_bottom = 5  # chunky "0 6px 0" feel
	gsb.border_color = Color("c4764a")
	go.add_theme_stylebox_override("normal", gsb)
	var gh: StyleBoxFlat = gsb.duplicate()
	gh.bg_color = P.ACCENT_DEEP.lightened(0.05)
	go.add_theme_stylebox_override("hover", gh)
	var gp: StyleBoxFlat = gsb.duplicate()
	gp.bg_color = P.ACCENT_DEEP.darkened(0.05)
	gp.border_width_bottom = 1
	go.add_theme_stylebox_override("pressed", gp)
	go.pressed.connect(_on_confirm)
	v.add_child(go)

	_name_input.grab_focus()
	_name_input.select_all()


func _on_submit(_submitted: String) -> void:
	_on_confirm()


func _on_confirm() -> void:
	var chosen := _name_input.text.strip_edges()
	if chosen.is_empty():
		chosen = DEFAULT_NAME
	GameState.pending_pet_name = chosen
	EventBus.navigate_to.emit("room")
