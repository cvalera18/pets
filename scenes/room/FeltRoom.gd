## FeltRoom.gd
## The felt room backdrop (wall, floor seam, embroidery hoop and the cushion
## Mochi sits on) plus the time-of-day tint over the room and the pet.
## Layout lives in FeltRoom.tscn; this only sizes it, since a Control parented to
## a Node2D doesn't anchor to the viewport on its own.
extends Control


func _ready() -> void:
	z_index = -100
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)


func _fit_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
