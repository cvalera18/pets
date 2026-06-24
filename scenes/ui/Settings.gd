## Settings.gd
## In-game settings overlay: language, notifications opt-out, and save reset.
##
## Implemented as a CanvasLayer overlay ON TOP of the Room (not a screen swap) so
## the pet/session stays alive underneath and changes persist through the normal
## Room save via EventBus.save_requested. Built in code so the .tscn stays a
## trivial host. Self-frees on Back.
extends CanvasLayer

var _retranslatables: Array[Dictionary] = []  # [{ node, key }]
var _lang_buttons: Dictionary = {}
var _notif_check: CheckButton


func _ready() -> void:
	layer = 10

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	margin.add_child(box)

	_add_label(box, "UI_SETTINGS", 32)
	box.add_child(HSeparator.new())

	_add_label(box, "SETTINGS_LANGUAGE", 20)
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 12)
	box.add_child(lang_row)
	_lang_buttons["es"] = _add_lang_button(lang_row, "Español", "es")
	_lang_buttons["en"] = _add_lang_button(lang_row, "English", "en")
	_reflect_language()

	box.add_child(HSeparator.new())

	_notif_check = CheckButton.new()
	_notif_check.button_pressed = GameState.notifications_enabled
	_notif_check.toggled.connect(_on_notifications_toggled)
	box.add_child(_notif_check)
	_register_text(_notif_check, "SETTINGS_NOTIFICATIONS")

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var reset_btn := Button.new()
	reset_btn.pressed.connect(_on_reset_pressed)
	box.add_child(reset_btn)
	_register_text(reset_btn, "SETTINGS_RESET")

	var back_btn := Button.new()
	back_btn.custom_minimum_size = Vector2(0.0, 52.0)
	back_btn.pressed.connect(_on_back_pressed)
	box.add_child(back_btn)
	_register_text(back_btn, "SETTINGS_BACK")


# ─── UI builders ──────────────────────────────────────────────────────────────

func _add_label(parent: Node, key: String, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	_register_text(l, key)
	return l


func _add_lang_button(parent: Node, label: String, locale: String) -> Button:
	var b := Button.new()
	b.text = label
	b.toggle_mode = true
	b.pressed.connect(_on_locale_selected.bind(locale))
	parent.add_child(b)
	return b


## Registers a node whose `text` should follow the current locale, and sets it.
func _register_text(node: Object, key: String) -> void:
	_retranslatables.append({"node": node, "key": key})
	node.text = tr(key)


func _retranslate() -> void:
	for entry in _retranslatables:
		entry["node"].text = tr(entry["key"])


# ─── Handlers ─────────────────────────────────────────────────────────────────

func _on_locale_selected(locale: String) -> void:
	if TranslationServer.get_locale().split("_")[0] == locale:
		_reflect_language()  # Re-assert toggle state; no change needed.
		return
	TranslationServer.set_locale(locale)
	_reflect_language()
	_retranslate()
	EventBus.locale_changed.emit()  # Let the HUD underneath re-translate live.
	_persist()


func _on_notifications_toggled(enabled: bool) -> void:
	GameState.notifications_enabled = enabled
	if not enabled:
		NotificationManager.cancel_all()
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
	EventBus.navigate_to.emit("onboarding")  # Frees the Room underneath.


func _on_back_pressed() -> void:
	queue_free()


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _reflect_language() -> void:
	var cur := TranslationServer.get_locale().split("_")[0]
	for key in _lang_buttons:
		_lang_buttons[key].button_pressed = (key == cur)


func _persist() -> void:
	# Room is alive underneath and owns the save context (pet stats + name).
	EventBus.save_requested.emit()
