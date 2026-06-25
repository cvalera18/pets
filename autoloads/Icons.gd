## Icons.gd
## Autoload — loads the redesign's vector icons at runtime by rasterizing the
## SVGs (Image.load_svg_from_string), so no editor import step is needed.
##
## All glyphs are white 24×24; tint them with `modulate` (or icon color overrides)
## where the design wants a colored icon.
extends Node

const SCALE: float = 5.0  # rasterize at 5× for crispness when shown small

var bowl: Texture2D
var star: Texture2D
var bolt: Texture2D
var heart: Texture2D
var ball: Texture2D
var moon: Texture2D
var gear: Texture2D


func _ready() -> void:
	bowl = _svg("res://assets/icons/bowl.svg")
	star = _svg("res://assets/icons/star.svg")
	bolt = _svg("res://assets/icons/bolt.svg")
	heart = _svg("res://assets/icons/heart.svg")
	ball = _svg("res://assets/icons/ball.svg")
	moon = _svg("res://assets/icons/moon.svg")
	gear = _svg("res://assets/icons/gear.svg")


func _svg(path: String) -> Texture2D:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("Icons: missing %s" % path)
		return null
	var img := Image.new()
	if img.load_svg_from_string(f.get_as_text(), SCALE) != OK:
		push_warning("Icons: could not rasterize %s" % path)
		return null
	return ImageTexture.create_from_image(img)
