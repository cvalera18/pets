## PaletteSwatches.gd
## Dev helper for FeltGallery: draws every color constant in Palette.gd with its
## name, so the gallery follows the palette without being edited by hand.
@tool
extends Control

const P := preload("res://theme/Palette.gd")
const COLUMNS := 3
const CELL := Vector2(118, 58)
const SWATCH := Vector2(110, 32)


func _ready() -> void:
	custom_minimum_size = Vector2(COLUMNS * CELL.x, ceilf(_colors().size() / float(COLUMNS)) * CELL.y)


func _colors() -> Array:
	var out := []
	var consts := (P as GDScript).get_script_constant_map()
	for key in consts:
		if consts[key] is Color:
			out.append([key, consts[key]])
	return out


func _draw() -> void:
	var font := get_theme_default_font()
	var i := 0
	for entry in _colors():
		var origin := Vector2((i % COLUMNS) * CELL.x, (i / COLUMNS) * CELL.y)
		var box := StyleBoxFlat.new()
		box.bg_color = entry[1]
		box.set_corner_radius_all(8)
		box.border_color = Color(0, 0, 0, 0.12)
		box.set_border_width_all(1)
		draw_style_box(box, Rect2(origin, SWATCH))
		draw_string(font, origin + Vector2(2, SWATCH.y + 15), String(entry[0]).to_lower().replace("_", "-"),
				HORIZONTAL_ALIGNMENT_LEFT, CELL.x - 4, 11, P.INK_SOFT)
		i += 1
