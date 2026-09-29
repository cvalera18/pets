## Onboarding.gd
## First-launch screen in the felt style: garland, wordmark, Mochi on her
## cushion and the name card (layout in Onboarding.tscn). The chosen name flows
## to Room via GameState.pending_pet_name (no direct refs).
extends Control

const DEFAULT_NAME: String = "Mochi"
const MOOD_HAPPY := 0
const MOOD_CONTENT := 3


func _ready() -> void:
	%NameInput.text = DEFAULT_NAME
	%NameInput.text_changed.connect(_on_name_changed)
	%NameInput.text_submitted.connect(func(_t: String) -> void: _on_confirm())
	%GoButton.pressed.connect(_on_confirm)
	_on_name_changed(%NameInput.text)
	%NameInput.grab_focus()
	%NameInput.select_all()


func _on_name_changed(text: String) -> void:
	var has_name := text.strip_edges() != ""
	%GoButton.disabled = not has_name
	%Mochi.set_mood(MOOD_CONTENT if has_name else MOOD_HAPPY)


func _on_confirm() -> void:
	var chosen: String = %NameInput.text.strip_edges()
	if chosen.is_empty():
		return
	GameState.pending_pet_name = chosen
	EventBus.navigate_to.emit("room")
