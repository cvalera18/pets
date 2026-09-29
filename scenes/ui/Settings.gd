## Settings.gd
## In-game settings as a felt bottom sheet over the Room (CanvasLayer overlay;
## the session stays alive and changes persist via the Room save). Layout lives
## in Settings.tscn; this wires it to GameState. Self-frees on "Listo"/back.
extends CanvasLayer

const Haptics := preload("res://systems/Haptics.gd")

func _ready() -> void:
	var cur := TranslationServer.get_locale().split("_")[0]
	%LangEs.set_pressed_no_signal(cur == "es")
	%LangEn.set_pressed_no_signal(cur == "en")
	%LangEs.pressed.connect(_on_locale_selected.bind("es"))
	%LangEn.pressed.connect(_on_locale_selected.bind("en"))

	%Notifications.set_on(GameState.notifications_enabled)
	%Notifications.toggled.connect(_on_notifications_toggled)
	%Sound.set_on(GameState.sfx_enabled)
	%Sound.toggled.connect(_on_sfx_toggled)
	%Vibration.set_on(GameState.haptics_enabled)
	%Vibration.toggled.connect(_on_vibration_toggled)
	%TestMode.set_on(GameState.decay_test_mode)
	%TestMode.toggled.connect(_on_test_mode_toggled)

	%Volume.value = GameState.sfx_volume
	%Volume.value_changed.connect(_on_volume_changed)
	%Volume.drag_ended.connect(_on_volume_drag_ended)
	_show_volume(GameState.sfx_volume)

	%BackButton.pressed.connect(queue_free)
	%DoneButton.pressed.connect(queue_free)
	%ResetButton.pressed.connect(%Confirm.show)
	%ConfirmNo.pressed.connect(%Confirm.hide)
	%ConfirmYes.pressed.connect(_do_reset)
	%Confirm.hide()


func _on_locale_selected(locale: String) -> void:
	if TranslationServer.get_locale().split("_")[0] == locale:
		return
	TranslationServer.set_locale(locale)
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


func _on_vibration_toggled(enabled: bool) -> void:
	GameState.haptics_enabled = enabled
	if enabled:
		Haptics.vibrate(40)
	else:
		Haptics.stop()
	_persist()


func _on_volume_changed(value: float) -> void:
	GameState.sfx_volume = value
	_show_volume(value)


func _on_volume_drag_ended(_value_changed: bool) -> void:
	AudioManager.play_preview()
	_persist()


func _show_volume(value: float) -> void:
	%VolumeValue.text = "%d%%" % roundi(value * 100.0)


func _on_test_mode_toggled(enabled: bool) -> void:
	GameState.decay_test_mode = enabled
	_persist()


func _do_reset() -> void:
	SaveSystem.delete_save()
	GameState.pending_pet_name = ""
	EventBus.navigate_to.emit("onboarding")


func _persist() -> void:
	EventBus.save_requested.emit()
