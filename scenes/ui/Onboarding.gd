## Onboarding.gd
## First-launch screen: lets the player name their new pet, then enters the Room.
##
## The chosen name is handed to Room via GameState.pending_pet_name — this screen
## holds no reference to Room or Pet. The UI is built in code so the .tscn stays a
## trivial script host (no fragile hand-authored node graph).
extends Control

const MAX_NAME_LENGTH: int    = 16
const DEFAULT_NAME:    String = "Mochi"

var _name_input: LineEdit


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.custom_minimum_size = Vector2(280.0, 0.0)
	center.add_child(box)

	var title := Label.new()
	title.text = tr("ONBOARDING_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = tr("ONBOARDING_PLACEHOLDER")
	_name_input.max_length = MAX_NAME_LENGTH
	_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_input.custom_minimum_size = Vector2(0.0, 48.0)
	_name_input.text_submitted.connect(_on_submit)
	box.add_child(_name_input)

	var confirm := Button.new()
	confirm.text = tr("ONBOARDING_CONFIRM")
	confirm.custom_minimum_size = Vector2(0.0, 52.0)
	confirm.pressed.connect(_on_confirm)
	box.add_child(confirm)

	_name_input.grab_focus()


func _on_submit(_submitted: String) -> void:
	_on_confirm()


func _on_confirm() -> void:
	var chosen := _name_input.text.strip_edges()
	if chosen.is_empty():
		chosen = DEFAULT_NAME
	GameState.pending_pet_name = chosen
	EventBus.navigate_to.emit("room")
