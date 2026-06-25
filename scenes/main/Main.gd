## Main.gd
## Root scene — manages screen navigation and app lifecycle.
##
## Responsibilities:
##   • Loading / switching screens (Room, and future MainMenu / Settings)
##   • Listening for app lifecycle notifications (pause, quit) to trigger saves
##   • Bootstrapping: decide whether to show a "new game" or "continue" flow
##
## Navigation is signal-driven: any scene can call
##   EventBus.navigate_to.emit("room")
## without knowing anything about Main or other screens.
extends Node


## Registered screens. Add new entries here — no other navigation code changes needed.
const SCREENS: Dictionary = {
	"room":       preload("res://scenes/room/Room.tscn"),
	"onboarding": preload("res://scenes/ui/Onboarding.tscn"),
	# TODO: "main_menu": preload("res://scenes/ui/MainMenu.tscn"),
	# TODO: "settings":  preload("res://scenes/ui/Settings.tscn"),
}

var _current_screen: Node       = null
var _screen_history: Array[String] = []


func _ready() -> void:
	# Handle close/back manually so we can save before quitting.
	get_tree().set_auto_accept_quit(false)

	EventBus.navigate_to.connect(_on_navigate_to)
	EventBus.navigate_back.connect(_on_navigate_back)

	_start_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_WM_GO_BACK_REQUEST:
			EventBus.save_requested.emit()
			get_tree().quit()

		NOTIFICATION_APPLICATION_PAUSED:
			# App backgrounded on mobile — save and refresh notifications.
			EventBus.save_requested.emit()
			NotificationManager.refresh()


# ─── Private ──────────────────────────────────────────────────────────────────

func _start_game() -> void:
	# TODO: add a loading/splash screen while reading the save file.
	if SaveSystem.has_save():
		_navigate_to("room")
	else:
		# First launch — let the player name their pet before entering the room.
		_navigate_to("onboarding")


func _navigate_to(screen_name: String) -> void:
	if not SCREENS.has(screen_name):
		push_error("Main: unknown screen '%s'" % screen_name)
		return

	if _current_screen != null:
		_screen_history.append(_current_screen.name)
		_current_screen.queue_free()

	_current_screen = SCREENS[screen_name].instantiate()
	_current_screen.name = screen_name
	add_child(_current_screen)


func _on_navigate_to(screen_name: String) -> void:
	_navigate_to(screen_name)


func _on_navigate_back() -> void:
	if _screen_history.is_empty():
		return
	_navigate_to(_screen_history.pop_back())
