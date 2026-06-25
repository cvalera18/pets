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
## interaction) plus pet_woken, and respects GameState.sfx_enabled.
extends Node

const RATE: int       = 22050
const POOL_SIZE: int  = 5
const VOLUME_DB: float = -4.0

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0


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
	}

	EventBus.burst_requested.connect(_on_burst_requested)
	EventBus.pet_woken.connect(_on_pet_woken)
	EventBus.achievement_unlocked.connect(_on_achievement_unlocked)


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
