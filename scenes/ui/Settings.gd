## Settings.gd
## In-game settings, restyled to the cozy bottom-sheet design. CanvasLayer overlay
## on top of the Room (session stays alive; changes persist via the Room save).
## Built in code; self-frees on "Listo"/back.
extends CanvasLayer

const P := preload("res://theme/Palette.gd")

var _retranslatables: Array[Dictionary] = []   # [{ node, key }]
var _lang_buttons: Dictionary = {}


func _ready() -> void:
	layer = 10

	var dim := ColorRect.new()
	dim.color = Color(0.29, 0.20, 0.13, 0.34)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var sheet := Panel.new()
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = P.SHEET
	ssb.corner_radius_top_left = 30
	ssb.corner_radius_top_right = 30
	ssb.shadow_color = Color(0.35, 0.22, 0.12, 0.22)
	ssb.shadow_size = 14
	sheet.add_theme_stylebox_override("panel", ssb)
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.offset_top = 96.0
	add_child(sheet)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 22)
	sheet.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	# Grabber.
	var grab := Panel.new()
	grab.custom_minimum_size = Vector2(44, 5)
	grab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color("e2d2bf")
	gsb.set_corner_radius_all(3)
	grab.add_theme_stylebox_override("panel", gsb)
	box.add_child(grab)

	# Title.
	var title := Label.new()
	title.text = tr("UI_SETTINGS")
	if Fonts.display != null:
		title.add_theme_font_override("font", Fonts.display)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", P.TEXT)
	box.add_child(title)
	_retranslatables.append({"node": title, "key": "UI_SETTINGS"})

	# Language.
	box.add_child(_header("SETTINGS_LANGUAGE"))
	box.add_child(_language_segment())

	# Notifications + sound card.
	var c1 := _card()
	c1.add_child(_toggle_row("SETTINGS_NOTIFICATIONS", GameState.notifications_enabled, _on_notifications_toggled))
	c1.add_child(_hsep())
	c1.add_child(_toggle_row("SETTINGS_SOUND", GameState.sfx_enabled, _on_sfx_toggled))
	box.add_child(_card_panel(c1))

	# Volume card.
	var c2 := _card()
	var vol_lbl := _row_label("SETTINGS_VOLUME")
	c2.add_child(vol_lbl)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = GameState.sfx_volume
	slider.custom_minimum_size = Vector2(0, 22)
	slider.value_changed.connect(_on_volume_changed)
	slider.drag_ended.connect(_on_volume_drag_ended)
	c2.add_child(slider)
	box.add_child(_card_panel(c2))

	# Test mode card.
	var c3 := _card()
	c3.add_child(_toggle_row("SETTINGS_TEST_MODE", GameState.decay_test_mode, _on_test_mode_toggled))
	box.add_child(_card_panel(c3))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	# Actions.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var reset := _pill_button("SETTINGS_RESET", false)
	reset.pressed.connect(_on_reset_pressed)
	actions.add_child(reset)
	var done := _pill_button("SETTINGS_DONE", true)
	done.pressed.connect(_on_back_pressed)
	actions.add_child(done)


# ─── Builders ─────────────────────────────────────────────────────────────────

func _card() -> VBoxContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = P.CARD
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(14)
	sb.shadow_color = Color(0.59, 0.39, 0.24, 0.08)
	sb.shadow_size = 6
	panel.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	# Return the inner VBox but attach the panel to the tree via the caller.
	panel.set_meta("inner", v)
	v.set_meta("panel", panel)
	return v


# Note: callers add the returned VBox; its PanelContainer parent is added lazily.
func _card_panel(v: VBoxContainer) -> Control:
	return v.get_meta("panel")


func _header(key: String) -> Label:
	var l := Label.new()
	l.text = tr(key).to_upper()
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", P.TEXT_FAINT)
	_retranslatables.append({"node": l, "key": key, "upper": true})
	return l


func _row_label(key: String) -> Label:
	var l := Label.new()
	l.text = tr(key)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", P.TEXT)
	_retranslatables.append({"node": l, "key": key})
	return l


func _toggle_row(key: String, value: bool, cb: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := _row_label(key)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var tb := CheckButton.new()
	tb.button_pressed = value
	tb.toggled.connect(cb)
	row.add_child(tb)
	return row


func _hsep() -> HSeparator:
	return HSeparator.new()


func _language_segment() -> Control:
	var pill := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color("f1e2cf")
	psb.set_corner_radius_all(16)
	psb.set_content_margin_all(5)
	pill.add_theme_stylebox_override("panel", psb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	pill.add_child(row)
	_lang_buttons["es"] = _seg_button(row, "Español", "es")
	_lang_buttons["en"] = _seg_button(row, "English", "en")
	_reflect_language()
	return pill


func _seg_button(parent: Node, label: String, locale: String) -> Button:
	var b := Button.new()
	b.text = label
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 40)
	if Fonts.display != null:
		b.add_theme_font_override("font", Fonts.display)
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(_on_locale_selected.bind(locale))
	parent.add_child(b)
	return b


func _pill_button(key: String, accent: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Fonts.display != null:
		b.add_theme_font_override("font", Fonts.display)
	b.add_theme_font_size_override("font_size", 16)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(16)
	sb.set_content_margin_all(10)
	if accent:
		sb.bg_color = P.ACCENT_DEEP
		sb.border_width_bottom = 5
		sb.border_color = Color("c4764a")
		b.add_theme_color_override("font_color", P.ON_ACCENT)
	else:
		sb.bg_color = Color("fff6f3")
		sb.set_border_width_all(2)
		sb.border_color = Color("e59a8c")
		b.add_theme_color_override("font_color", Color("d4634f"))
	b.add_theme_stylebox_override("normal", sb)
	var h: StyleBoxFlat = sb.duplicate()
	h.bg_color = sb.bg_color.lightened(0.04)
	b.add_theme_stylebox_override("hover", h)
	_set_text(b, key)
	return b


func _set_text(node: Object, key: String) -> void:
	node.text = tr(key)
	_retranslatables.append({"node": node, "key": key})


# ─── Language ─────────────────────────────────────────────────────────────────

func _reflect_language() -> void:
	var cur := TranslationServer.get_locale().split("_")[0]
	for key in _lang_buttons:
		var b: Button = _lang_buttons[key]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(12)
		if key == cur:
			sb.bg_color = P.ACCENT_DEEP
			b.add_theme_color_override("font_color", P.ON_ACCENT)
		else:
			sb.bg_color = Color(0, 0, 0, 0)
			b.add_theme_color_override("font_color", P.TEXT_MUTED)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)


func _retranslate() -> void:
	for e in _retranslatables:
		var t: String = tr(e["key"])
		if e.get("upper", false):
			t = t.to_upper()
		e["node"].text = t


# ─── Handlers ─────────────────────────────────────────────────────────────────

func _on_locale_selected(locale: String) -> void:
	if TranslationServer.get_locale().split("_")[0] == locale:
		_reflect_language()
		return
	TranslationServer.set_locale(locale)
	_reflect_language()
	_retranslate()
	EventBus.locale_changed.emit()
	_persist()


func _on_notifications_toggled(enabled: bool) -> void:
	GameState.notifications_enabled = enabled
	if not enabled:
		NotificationManager.cancel_all()
	_persist()


func _on_sfx_toggled(enabled: bool) -> void:
	GameState.sfx_enabled = enabled
	_persist()


func _on_volume_changed(value: float) -> void:
	GameState.sfx_volume = value


func _on_volume_drag_ended(_value_changed: bool) -> void:
	AudioManager.play_preview()
	_persist()


func _on_test_mode_toggled(enabled: bool) -> void:
	GameState.decay_test_mode = enabled
	_persist()


func _on_reset_pressed() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = tr("UI_CONFIRM_DELETE")
	dialog.ok_button_text = tr("UI_YES")
	dialog.cancel_button_text = tr("UI_NO")
	dialog.confirmed.connect(_do_reset)
	add_child(dialog)
	dialog.popup_centered()


func _do_reset() -> void:
	SaveSystem.delete_save()
	GameState.pending_pet_name = ""
	EventBus.navigate_to.emit("onboarding")


func _on_back_pressed() -> void:
	queue_free()


func _persist() -> void:
	EventBus.save_requested.emit()
