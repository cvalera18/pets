## Haptics.gd
## Vibration for the game, through Android's media channel (VibrationAttributes
## USAGE_MEDIA, "games and interactive media"). Input.vibrate_handheld uses the
## touch-feedback channel instead, which Android silently drops when the phone's
## touch haptics are off — so most feedback would never be felt.
##
## Reaches Android through AndroidRuntime + JavaClassWrapper; if that is missing
## (desktop, old Android) it falls back to Input.vibrate_handheld. Everything is a
## no-op while GameState.haptics_enabled is off.
extends RefCounted

const USAGE_MEDIA := 19          # android.os.VibrationAttributes.USAGE_MEDIA
const PURR_HZ := 25.0            # a cat purrs at ~25 rumbles per second

static var _setup_done := false
static var _vibrator = null
static var _effects = null
static var _attrs = null


## One vibration of `ms` milliseconds. amplitude in [0, 1], or -1 for the default.
static func vibrate(ms: int, amplitude: float = -1.0) -> void:
	if ms <= 0 or not GameState.haptics_enabled or not OS.has_feature("mobile"):
		return
	_setup()
	if _vibrator == null:
		Input.vibrate_handheld(ms, amplitude)
		return
	var amp := -1 if amplitude < 0.0 else clampi(roundi(amplitude * 255.0), 1, 255)
	_vibrator.vibrate(_effects.createOneShot(ms, amp), _attrs)


## True when native waveforms (and so purr_breath) are available.
static func has_waveforms() -> bool:
	if not OS.has_feature("mobile"):
		return false
	_setup()
	return _vibrator != null


## One purr breath of `seconds`: PURR_HZ pulses swelling on the exhale, scaled by
## `level` in [0, 1]. Deliberately not a repeating waveform, so a stalled game can
## never leave the phone buzzing: the caller plays one per breath.
static func purr_breath(seconds: float, level: float) -> void:
	if not GameState.haptics_enabled or not has_waveforms():
		return
	var half := int(round(500.0 / PURR_HZ))   # ms on, then ms off
	var pulses := int(seconds * PURR_HZ)
	var timings := PackedInt64Array()
	var amps := PackedInt32Array()
	for i in pulses:
		var breath := 0.5 + 0.5 * sin(TAU * float(i) / float(pulses))
		timings.append(half)
		amps.append(clampi(roundi(255.0 * level * (0.35 + 0.45 * breath)), 1, 255))
		timings.append(half)
		amps.append(0)
	_vibrator.vibrate(_effects.createWaveform(timings, amps, -1), _attrs)


static func stop() -> void:
	if _vibrator != null:
		_vibrator.cancel()


static func _setup() -> void:
	if _setup_done:
		return
	_setup_done = true
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return
	var context = Engine.get_singleton("AndroidRuntime").getApplicationContext()
	var vibrator = context.getSystemService("vibrator") if context else null
	var effects = JavaClassWrapper.wrap("android.os.VibrationEffect")
	var attributes = JavaClassWrapper.wrap("android.os.VibrationAttributes")
	var attrs = attributes.createForUsage(USAGE_MEDIA) if attributes else null
	if vibrator == null or effects == null or attrs == null:
		print("[Haptics] media channel unavailable, using Input.vibrate_handheld")
		return
	_vibrator = vibrator
	_effects = effects
	_attrs = attrs
	print("[Haptics] media channel ready")
