## AudioManager.gd
## Autoload singleton — procedural sound effects, fully synthesized in code.
##
## No audio assets: each SFX is built at startup as an AudioStreamWAV from raw
## 16-bit PCM samples (simple decaying sine "notes"). This keeps the project
## asset-free and license-clean; swap in real .wav/.ogg later by replacing the
## _make_* builders with preloaded streams.
##
## Decoupled like everything else: it listens to EventBus.burst_requested (the
## same signal the particle juice uses, so a sound only plays on a *successful*
## interaction), sound_requested, pet_woken and purr_changed, and respects
## GameState.sfx_enabled.
extends Node

const RATE: int       = 22050
const POOL_SIZE: int  = 5
const VOLUME_DB: float = -4.0

## One purr "breath" (inhale + exhale), replayed while Mochi purrs.
const PURR_LOOP: float = 2.4
const PURR_GAIN: float = 0.8

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0

var _purr_player: AudioStreamPlayer
var _purr_level: float = 0.0
var _purr_target: float = 0.0


func _ready() -> void:
	for _i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.volume_db = VOLUME_DB
		add_child(p)
		_players.append(p)

	_sfx = {
		"eat":     _make_eat(),
		"play":    _make_play(),
		"love":    _make_love(),
		"sleep":   _make_sleep(),
		"wake":    _make_wake(),
		"achieve": _make_achieve(),
		"mrrp":    _make_mrrp(),
		"grumble": _make_grumble(),
		"meow":    _make_meow(),
		"tap":     _make_tap(),
		"yawn":    _make_yawn(),
	}

	_purr_player = AudioStreamPlayer.new()
	_purr_player.stream = _make_purr()
	add_child(_purr_player)

	EventBus.burst_requested.connect(_on_burst_requested)
	EventBus.sound_requested.connect(_play)
	EventBus.pet_woken.connect(_on_pet_woken)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)
	EventBus.purr_changed.connect(func(intensity: float) -> void: _purr_target = intensity)


## Eases the purr's volume toward the pet's purr intensity and replays it while
## she purrs.
func _process(delta: float) -> void:
	_purr_level = move_toward(_purr_level, _purr_target, delta * 2.0)
	if _purr_level <= 0.01 or not GameState.sfx_enabled:
		if _purr_player.playing:
			_purr_player.stop()
		return
	_purr_player.volume_db = linear_to_db(_purr_level * PURR_GAIN * clampf(GameState.sfx_volume, 0.0, 1.0))
	if not _purr_player.playing:
		_purr_player.play()


# ─── Playback ─────────────────────────────────────────────────────────────────

func _on_burst_requested(kind: String, _world_pos: Vector2) -> void:
	_play(kind)  # kind == "eat" | "play" | "love" | "sleep"


func _on_pet_woken() -> void:
	_play("wake")


func _on_achievement_unlocked(_id: String, _title_key: String) -> void:
	_play("achieve")


## Plays a named SFX through a round-robin player pool (allows overlap).
func _play(key: String) -> void:
	if not GameState.sfx_enabled:
		return
	var stream: AudioStream = _sfx.get(key)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = linear_to_db(clampf(GameState.sfx_volume, 0.0, 1.0))
	p.play()


## Plays a short sample so the Settings volume slider gives immediate feedback.
func play_preview() -> void:
	_play("love")


# ─── Synthesis ────────────────────────────────────────────────────────────────

## Appends a single decaying sine "note" to a float sample buffer.
func _note(buf: PackedFloat32Array, freq: float, dur: float, vol: float, decay: float = 6.0) -> void:
	var n := int(dur * RATE)
	for i in n:
		var t := float(i) / float(RATE)
		var env := exp(-t * decay)
		var attack := minf(1.0, t / 0.004)  # tiny fade-in avoids a click
		buf.append(sin(TAU * freq * t) * env * attack * vol)


func _silence(buf: PackedFloat32Array, dur: float) -> void:
	for _i in int(dur * RATE):
		buf.append(0.0)


func _to_stream(buf: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))

	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	return s


func _make_eat() -> AudioStreamWAV:
	var b := PackedFloat32Array()
	_note(b, 200.0, 0.06, 0.5, 16.0)
	_silence(b, 0.03)
	_note(b, 160.0, 0.07, 0.5, 16.0)
	return _to_stream(b)


func _make_play() -> AudioStreamWAV:
	var b := PackedFloat32Array()  # cheerful C-E-G arpeggio
	_note(b, 523.25, 0.09, 0.4)
	_note(b, 659.25, 0.09, 0.4)
	_note(b, 783.99, 0.13, 0.4)
	return _to_stream(b)


func _make_love() -> AudioStreamWAV:
	var b := PackedFloat32Array()  # warm two-tone chime
	_note(b, 587.33, 0.16, 0.4, 4.0)
	_note(b, 880.00, 0.22, 0.35, 4.0)
	return _to_stream(b)


func _make_sleep() -> AudioStreamWAV:
	var b := PackedFloat32Array()  # soft descending
	_note(b, 392.0, 0.16, 0.35, 5.0)
	_note(b, 261.63, 0.24, 0.35, 4.0)
	return _to_stream(b)


func _make_wake() -> AudioStreamWAV:
	var b := PackedFloat32Array()  # gentle ascending
	_note(b, 261.63, 0.10, 0.35)
	_note(b, 392.00, 0.16, 0.35)
	return _to_stream(b)


func _make_achieve() -> AudioStreamWAV:
	var b := PackedFloat32Array()  # triumphant rising fanfare C-E-G-C
	_note(b, 523.25, 0.10, 0.4)
	_note(b, 659.25, 0.10, 0.4)
	_note(b, 783.99, 0.10, 0.4)
	_note(b, 1046.50, 0.22, 0.4, 4.0)
	return _to_stream(b)


## A purr: dark noise chopped into ~25 rumbles per second, swelling on the exhale.
## 25 Hz and the breath both complete whole cycles in PURR_LOOP and the chop is
## silent at both ends, so replaying it back to back has no click. It is not a WAV
## loop on purpose: Godot's looped WAV playback crashed Android's audio thread
## (SIGSEGV in AudioTrack) at the seam; _process restarts it instead.
func _make_purr() -> AudioStreamWAV:
	var n := int(PURR_LOOP * RATE)
	var b := PackedFloat32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp1 := 0.0
	var lp2 := 0.0
	var peak := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		lp1 += (rng.randf_range(-1.0, 1.0) - lp1) * 0.16
		lp2 += (lp1 - lp2) * 0.16
		var chop := pow(maxf(0.0, sin(TAU * 25.0 * t)), 2.0)
		var breath := 0.6 + 0.4 * sin(TAU * t / PURR_LOOP)
		var v := lp2 * chop * breath
		b.append(v)
		peak = maxf(peak, absf(v))
	for i in n:
		b[i] = b[i] / peak * 0.7
	return _to_stream(b)


func _make_mrrp() -> AudioStreamWAV:
	var b := PackedFloat32Array()  # short rising trill, a cat's "hi"
	var dur := 0.22
	var phase := 0.0
	for i in int(dur * RATE):
		var t := float(i) / float(RATE)
		var p := t / dur
		phase += TAU * lerpf(380.0, 640.0, sqrt(p)) / float(RATE)
		var trill := 0.65 + 0.35 * sin(TAU * 32.0 * t)
		b.append((sin(phase) + 0.3 * sin(2.0 * phase)) * sin(PI * p) * trill * 0.35)
	return _to_stream(b)


func _make_grumble() -> AudioStreamWAV:
	var b := PackedFloat32Array()  # low falling "mrrr", rough with a slow flutter
	var dur := 0.28
	var phase := 0.0
	for i in int(dur * RATE):
		var t := float(i) / float(RATE)
		var p := t / dur
		phase += TAU * lerpf(230.0, 150.0, p) / float(RATE)
		var flutter := 0.5 + 0.5 * sin(TAU * 18.0 * t)
		var env := minf(1.0, t / 0.02) * pow(1.0 - p, 1.5)
		b.append((sin(phase) + 0.5 * sin(2.0 * phase) + 0.25 * sin(3.0 * phase)) * env * flutter * 0.3)
	return _to_stream(b)


## "Mi-au": the pitch rises and falls while the vowel opens and then rounds.
func _make_meow() -> AudioStreamWAV:
	var b := PackedFloat32Array()
	var dur := 0.55
	var phase := 0.0
	for i in int(dur * RATE):
		var t := float(i) / float(RATE)
		var p := t / dur
		var f := lerpf(520.0, 780.0, smoothstep(0.0, 0.3, p)) if p < 0.3 else lerpf(780.0, 470.0, smoothstep(0.3, 1.0, p))
		phase += TAU * f * (1.0 + 0.012 * sin(TAU * 6.0 * t)) / float(RATE)
		var open := sin(PI * minf(p * 1.4, 1.0))
		var v := sin(phase) + open * (0.55 * sin(2.0 * phase) + 0.3 * sin(3.0 * phase))
		var env := minf(1.0, t / 0.04) * pow(1.0 - p, 0.6)
		b.append(v * env * 0.3)
	return _to_stream(b)


## A soft yawn: a breathy tone that opens and sinks.
func _make_yawn() -> AudioStreamWAV:
	var b := PackedFloat32Array()
	var dur := 0.8
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var breath := 0.0
	for i in int(dur * RATE):
		var t := float(i) / float(RATE)
		var p := t / dur
		phase += TAU * lerpf(420.0, 210.0, p * p) / float(RATE)
		breath += (rng.randf_range(-1.0, 1.0) - breath) * 0.2
		var env := sin(PI * minf(p * 1.25, 1.0)) * (1.0 - 0.5 * p)
		b.append((0.7 * sin(phase) + 0.25 * sin(2.0 * phase) + 0.35 * breath) * env * 0.22)
	return _to_stream(b)


func _make_tap() -> AudioStreamWAV:
	var b := PackedFloat32Array()  # a soft paw on the felt bowl
	_note(b, 240.0, 0.07, 0.45, 35.0)
	return _to_stream(b)
