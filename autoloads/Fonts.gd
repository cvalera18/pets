## Fonts.gd
## Autoload — loads the redesign's typefaces and exposes them, and sets Quicksand
## as the global fallback so every Control picks it up without per-node wiring.
##   • display  → Fredoka  (titles, pet name, numbers)
##   • body     → Quicksand (labels, body, buttons)
##
## Loaded via load_dynamic_font so the .ttf works straight from disk without the
## editor import step (matters for headless / first-run).
extends Node

var display: Font       # Fredoka 600 — titles, pet name, numbers
var display_xl: Font    # Fredoka 700 — hero wordmark / screen titles
var body: Font          # Quicksand 500 — body, captions (global fallback)
var body_strong: Font   # Quicksand 600 — labels, buttons (design weight)


func _ready() -> void:
	var fredoka := _load("res://assets/fonts/Fredoka.ttf")
	var quicksand := _load("res://assets/fonts/Quicksand.ttf")

	display = _weight(fredoka, 600)
	display_xl = _weight(fredoka, 700)
	body = _weight(quicksand, 500)
	body_strong = _weight(quicksand, 600)

	if body != null:
		ThemeDB.fallback_font = body
		ThemeDB.fallback_font_size = 15


func _load(path: String) -> FontFile:
	var f := FontFile.new()
	if f.load_dynamic_font(path) != OK:
		push_warning("Fonts: could not load %s" % path)
		return null
	return f


## Wraps a variable font at a given weight (600 = semibold, etc.).
func _weight(base: FontFile, w: int) -> Font:
	if base == null:
		return null
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_opentype = {"wght": float(w)}
	return fv
