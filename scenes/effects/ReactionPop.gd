## ReactionPop.gd
## One of Mochi's feelings (a FeltPicto symbol) popping over her head: it springs
## up, stays a moment, then drifts up and fades.
extends Node2D

const FeltPicto := preload("res://theme/felt/FeltPicto.gd")
const SIZE := 58.0

var kind := "enojo"


func begin(at: Vector2, which: String) -> void:
	position = at
	kind = which
	scale = Vector2.ONE * 0.5
	modulate.a = 0.0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(self, "scale", Vector2.ONE * 1.12, 0.22) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2.ONE, 0.12)
	t.tween_interval(1.1)
	t.tween_property(self, "position:y", at.y - 18.0, 0.45)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.45)
	t.tween_callback(queue_free)
	queue_redraw()


func _draw() -> void:
	FeltPicto.draw_picto(self, kind, Vector2.ZERO, SIZE)
