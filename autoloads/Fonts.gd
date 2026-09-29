## Fonts.gd
## Autoload — exposes the Mali weights for text built in code (floating texts,
## etc.). Controls get Mali from the felt Theme (theme/felt_theme.tres) instead.
##
## The fonts are native FontFile resources (.res) generated from the OFL Mali
## TTFs, so they load without the editor import step (headless / first run).
extends Node

var medium: Font     # Mali Medium — soft body copy
var semibold: Font   # Mali SemiBold — labels, body (Theme default)
var bold: Font       # Mali Bold — titles, numbers, buttons


func _ready() -> void:
	medium = _load("res://assets/fonts/Mali-Medium.res")
	semibold = _load("res://assets/fonts/Mali-SemiBold.res")
	bold = _load("res://assets/fonts/Mali-Bold.res")


func _load(path: String) -> Font:
	var f := load(path) as Font
	if f == null:
		push_warning("Fonts: could not load %s" % path)
	return f
