## GhostHand.gd
## A dashed felt hand that shows the player a gesture instead of telling it:
## "drag" (a food from its slot to the bowl), "hold" (still, on the wand's grip)
## and "stroke" (along Mochi's back). Moving gestures leave a dotted trail and
## play twice; it never takes input.
extends Control

const FeltPicto := preload("res://theme/felt/FeltPicto.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")
const P := preload("res://theme/Palette.gd")

const SIZE := 60.0
const REPEATS := 2
const MOVE_TIME := 1.0
const HOLD_TIME := 2.4

var _kind := ""
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _pulse := 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	set_process(false)


func play(kind: String, from: Vector2, to: Vector2) -> void:
	_kind = kind
	_from = from - global_position
	_to = to - global_position
	_t = 0.0
	_pulse = 0.0
	modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if kind == "hold":
		_tween.tween_property(self, "modulate:a", 1.0, 0.2)
		_tween.tween_property(self, "_pulse", 3.0, HOLD_TIME)
		_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	else:
		for i in REPEATS:
			_tween.tween_property(self, "_t", 0.0, 0.0)
			_tween.tween_property(self, "modulate:a", 1.0, 0.2)
			_tween.tween_property(self, "_t", 1.0, MOVE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_tween.tween_interval(0.3)
			_tween.tween_property(self, "modulate:a", 0.0, 0.3)
			_tween.tween_interval(0.25)
	_tween.tween_callback(_done)
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _done() -> void:
	_kind = ""
	set_process(false)
	queue_redraw()


func _draw() -> void:
	if _kind == "":
		return
	var tip := _from
	if _kind == "hold":
		for i in 2:
			var k := fmod(_pulse + i * 0.5, 1.0)
			FeltDraw.draw_dashes(self, FeltDraw.ellipse(tip, Vector2.ONE * (12.0 + 16.0 * k), 32), true,
					Color(P.INK_SOFT, 0.7 * (1.0 - k)), 1.8, 3.0, 3.0)
	else:
		var path := _path()
		FeltDraw.draw_dashes(self, path, false, Color(P.INK_SOFT, 0.8), 2.4, 5.0, 5.0)
		var end := path[path.size() - 1]
		var back := (path[path.size() - 4] - end).normalized() * 11.0
		draw_polyline(PackedVector2Array([end + back.rotated(0.5), end, end + back.rotated(-0.5)]),
				Color(P.INK_SOFT, 0.8), 2.4, true)
		tip = _point(_t)
	var center := tip + (Vector2(32, 32) - FeltPicto.FINGERTIP) * SIZE / 64.0
	FeltPicto.draw_picto(self, "mano", center, SIZE)


func _control() -> Vector2:
	var mid := (_from + _to) * 0.5
	var lift := 14.0 if _kind == "stroke" else minf(90.0, _from.distance_to(_to) * 0.35)
	return mid + Vector2(0.0, -lift)


func _point(t: float) -> Vector2:
	var c := _control()
	return _from.lerp(c, t).lerp(c.lerp(_to, t), t)


func _path() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 25:
		pts.append(_point(i / 24.0))
	return pts
