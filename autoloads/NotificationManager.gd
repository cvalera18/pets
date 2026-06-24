## NotificationManager.gd
## Autoload singleton — local push notification scheduling.
##
## Handles platform-specific notification APIs for iOS and Android.
## Requires third-party Godot plugins for actual delivery on device:
##
##   iOS     → godot-ios-plugins (Notifications module)
##             https://github.com/godotengine/godot-ios-plugins
##   Android → GodotAndroidLocalNotification or similar GDNative plugin
##
## On editor / PC builds: falls back to print() — no crashes, safe to test.
##
## Usage:
##   NotificationManager.schedule(NotificationManager.Type.HUNGRY, 1800.0)
##   NotificationManager.cancel_all()
extends Node


## Identifies each notification type. Used as stable integer IDs on device.
enum Type {
	HUNGRY,   ## Pet's hunger is low
	LONELY,   ## Pet misses the player (mood or affection low)
	TIRED,    ## Pet needs sleep (energy low)
}

var _plugin_ios:     Object = null
var _plugin_android: Object = null
var _is_mobile:      bool   = false


func _ready() -> void:
	_is_mobile = OS.get_name() in ["iOS", "Android"]
	_init_plugins()

	EventBus.notification_schedule_requested.connect(_on_schedule_requested)
	EventBus.notification_cancel_requested.connect(_on_cancel_requested)


# ─── Public API ───────────────────────────────────────────────────────────────

## Schedules a local notification after delay_seconds.
## Safe to call on all platforms — gracefully no-ops without a plugin.
func schedule(type: Type, delay_seconds: float) -> void:
	if not GameState.notifications_enabled:
		return  # Player opted out in Settings.

	var title := _get_title(type)
	var body  := _get_body(type)
	var id    := type as int

	if not _is_mobile:
		_log("Scheduled (editor only): [%s] '%s' in %.0fs" % [Type.keys()[type], title, delay_seconds])
		return

	match OS.get_name():
		"iOS":     _schedule_ios(id, title, body, delay_seconds)
		"Android": _schedule_android(id, title, body, delay_seconds)


## Cancels a specific pending notification by type.
func cancel(type: Type) -> void:
	if not _is_mobile:
		return
	_cancel_by_id(type as int)


## Cancels all pending notifications managed by this app.
func cancel_all() -> void:
	for t in Type.values():
		cancel(t as Type)


## Call when the player opens the app.
## Clears stale notifications; reschedule happens naturally as stats decay.
func refresh() -> void:
	cancel_all()
	# TODO v2: respect per-type notification opt-out stored in user settings.


# ─── Private ──────────────────────────────────────────────────────────────────

func _init_plugins() -> void:
	if not _is_mobile:
		return

	match OS.get_name():
		"iOS":
			# TODO: replace class name with the one your chosen iOS plugin registers.
			if ClassDB.class_exists("iOSNotifications"):
				_plugin_ios = ClassDB.instantiate("iOSNotifications")
				_plugin_ios.request_permission()
			else:
				_log("iOS notification plugin not found — install godot-ios-plugins.")
		"Android":
			# TODO: replace singleton name with the one your chosen Android plugin registers.
			if Engine.has_singleton("GodotAndroidLocalNotification"):
				_plugin_android = Engine.get_singleton("GodotAndroidLocalNotification")
			else:
				_log("Android notification plugin not found.")


func _schedule_ios(id: int, title: String, body: String, delay: float) -> void:
	if _plugin_ios == null:
		_log("iOS plugin not loaded — notification '%s' not sent." % title)
		return
	# TODO: call your plugin's actual scheduling method. Example (verify with plugin docs):
	# _plugin_ios.schedule_notification(id, title, body, int(delay))
	_log("TODO: call iOS plugin to schedule id=%d '%s' in %.0fs" % [id, title, delay])


func _schedule_android(id: int, title: String, body: String, delay: float) -> void:
	if _plugin_android == null:
		_log("Android plugin not loaded — notification '%s' not sent." % title)
		return
	# TODO: call your plugin's actual scheduling method. Example (verify with plugin docs):
	# var fire_at := int(Time.get_unix_time_from_system() + delay)
	# _plugin_android.schedule(id, title, body, fire_at)
	_log("TODO: call Android plugin to schedule id=%d '%s' in %.0fs" % [id, title, delay])


func _cancel_by_id(id: int) -> void:
	match OS.get_name():
		"iOS":
			if _plugin_ios:
				pass  # TODO: _plugin_ios.cancel_notification(id)
		"Android":
			if _plugin_android:
				pass  # TODO: _plugin_android.cancel(id)


func _get_title(type: Type) -> String:
	match type:
		Type.HUNGRY: return tr("NOTIF_HUNGRY_TITLE")
		Type.LONELY: return tr("NOTIF_LONELY_TITLE")
		Type.TIRED:  return tr("NOTIF_TIRED_TITLE")
	return ""


func _get_body(type: Type) -> String:
	match type:
		Type.HUNGRY: return tr("NOTIF_HUNGRY_BODY")
		Type.LONELY: return tr("NOTIF_LONELY_BODY")
		Type.TIRED:  return tr("NOTIF_TIRED_BODY")
	return ""


func _on_schedule_requested(type_name: String, delay_seconds: float) -> void:
	var idx := Type.keys().find(type_name)
	if idx == -1:
		push_warning("NotificationManager: unknown type '%s'" % type_name)
		return
	schedule(idx as Type, delay_seconds)


func _on_cancel_requested(type_name: String) -> void:
	var idx := Type.keys().find(type_name)
	if idx == -1:
		return
	cancel(idx as Type)


func _log(msg: String) -> void:
	print("[NotificationManager] ", msg)
