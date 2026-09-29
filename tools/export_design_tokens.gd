## export_design_tokens.gd
## Writes design/tokens.json for the "PetBond · Fieltro" design system from the
## game's own sources, so the code stays the single source of truth:
##   • colors + usage notes  ← theme/Palette.gd (the trailing comment of each const)
##   • type scale            ← the Label/Button/LineEdit variations in theme/felt_theme.tres
##   • radius, padding, shadow, stitch ← the felt StyleBoxes in that Theme
##   • gutter                ← scenes/hud/HUD.tscn
## Run headless from the project root:
##   godot --headless --path . --script res://tools/export_design_tokens.gd
extends SceneTree

const PALETTE_PATH := "res://theme/Palette.gd"
const THEME_PATH := "res://theme/felt_theme.tres"
const HUD_PATH := "res://scenes/hud/HUD.tscn"
const OUT_PATH := "res://design/tokens.json"

## Text colors → the grounds they are used on (contrast is appended to the usage note).
const TEXT_GROUNDS := {
	"INK": ["PANEL", "CARD", "WALL"],
	"INK_SOFT": ["PANEL", "TRACK"],
	"MUTED": ["PANEL", "CARD"],
	"SECTION": ["PANEL", "CARD"],
	"FAINT": ["CARD"],
	"WORDMARK": ["WALL"],
	"ON_ACCENT": ["TERRACOTTA", "CRIT"],
	"LEVEL_TEXT": ["PANEL", "TOAST_ROSE"],
	"TRAIT_TEXT": ["CARD"],
	"KICKER_TEXT": ["CARD"],
	"CRIT_TEXT": ["CRIT_ROW", "DANGER_BG"],
	"HUNGER_TEXT": ["WALL"],
	"HAPPY_TEXT": ["WALL"],
	"ENERGY_TEXT": ["WALL"],
	"AFFECTION_TEXT": ["WALL"],
}

## Theme variation → [style name, usage]. Order = order in the type scale.
const TYPE_STYLES := [
	["WordmarkLabel", "Label", "wordmark", "The PetBond wordmark on the welcome screen only."],
	["TitleLabel", "Label", "title", "Pet name in the header and screen titles."],
	["HeadingLabel", "Label", "heading", "Card and dialog headings."],
	["ToastTitle", "Label", "toast-title", "Title line of toasts (achievement, level, trait)."],
	["LineEdit", "LineEdit", "field", "Text typed in fields (the pet's name)."],
	["Button", "Button", "button", "Labels of primary, secondary and destructive buttons."],
	["SegmentButton", "Button", "segment", "Options of a segmented control."],
	["BubbleLabel", "Label", "bubble", "The pet's thought inside a bubble."],
	["BodyLabel", "Label", "body", "Setting rows, dialog copy and other body text."],
	["StatLabel", "Label", "stat-label", "Stat names in the stats panel."],
	["ValueLabel", "Label", "stat-value", "Stat values (0–100) at the end of each row."],
	["TaglineLabel", "Label", "tagline", "Tagline under the wordmark."],
	["QuoteLabel", "Label", "quote", "A trait's catchphrase, in «…»."],
	["ActionLabel", "Label", "action", "Labels under the sewing buttons of the action bar."],
	["SettingValueLabel", "Label", "setting-value", "Values shown beside a setting (e.g. 70%)."],
	["LevelLabel", "Label", "level", "\"Nivel N\" and bond copy."],
	["ToastBody", "Label", "toast-body", "Second line of a toast."],
	["TagLabel", "Label", "tag", "The trait tag (\"Glotona\")."],
	["SectionLabel", "Label", "section", "Uppercase section labels in settings."],
	["KickerLabel", "Label", "kicker", "Uppercase kicker above an achievement title."],
]

## [token name, theme type, stylebox name, usage] for felt surfaces.
const SURFACES := [
	["panel", "PanelContainer", "panel", "Stats panel and any plain felt panel."],
	["header", "HeaderPanel", "panel", "Header with the pet's name, bond and settings."],
	["actions", "ActionsPanel", "panel", "Action bar holding the sewing buttons."],
	["card-panel", "CardPanel", "panel", "Large felt card (the welcome name card)."],
	["inner-card", "InnerCard", "panel", "Cards inside a sheet (setting rows)."],
	["bubble", "BubblePanel", "panel", "Thought bubbles."],
	["toast", "ToastPanel", "panel", "Toasts under the header."],
	["dialog", "DialogPanel", "panel", "Confirmation dialogs."],
	["sheet", "SheetPanel", "panel", "Bottom sheets (settings); only the top corners are rounded."],
	["segment-track", "SegmentTrack", "panel", "Sunken track of a segmented control."],
	["button", "Button", "normal", "Primary button (CTA)."],
	["button-secondary", "SecondaryButton", "normal", "Secondary button (\"No\")."],
	["button-danger", "DangerButton", "normal", "Destructive secondary button (\"Borrar partida\")."],
	["button-crit", "CritButton", "normal", "Destructive confirm button (\"Sí\")."],
	["segment-selected", "SegmentButton", "pressed", "Selected option of a segmented control."],
	["field", "LineEdit", "normal", "Text fields."],
	["stat-row", "StatRow", "panel", "A stat row; gets CRIT_ROW while critical."],
	["trait-tag", "TraitTag", "panel", "The woven trait tag in the header."],
]

var _palette_values := {}


func _init() -> void:
	var theme := load(THEME_PATH) as Theme
	_palette_values = (load(PALETTE_PATH) as GDScript).get_script_constant_map()
	var colors := _colors()
	var tokens := {
		"name": "PetBond · Fieltro",
		"version": 1,
		"meta": {
			"source": "godot",
			"repo": "cvalera18/pets",
			"paths": {"colors": PALETTE_PATH, "theme": THEME_PATH, "layout": HUD_PATH},
			"generator": "res://tools/export_design_tokens.gd",
			"synced": Time.get_datetime_string_from_system(true) + "Z",
		},
		"color": {"themes": [{"id": "fieltro", "name": "Fieltro"}], "tokens": colors},
		"type": _type(theme),
		"spacing": {"tokens": _spacing(theme)},
		"radius": {"tokens": _radius(theme)},
		"shadow": {"tokens": _shadows(theme)},
		"stitch": {
			"note": "Seams stitched inside felt surfaces: inset, width, dash, gap.",
			"tokens": _stitches(theme),
		},
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://design"))
	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(tokens, "  ", false) + "\n")
	f.close()
	print("wrote %s: %d colors, %d type styles" % [OUT_PATH, colors.size(), tokens["type"]["groups"][0]["styles"].size()])
	quit()


# ─── Colors ───────────────────────────────────────────────────────────────────

func _colors() -> Array:
	var out := []
	var re := RegEx.create_from_string("^const\\s+(\\w+)\\s*:=\\s*(.+?)\\s*(?:#\\s*(.*))?$")
	for line in FileAccess.get_file_as_string(PALETTE_PATH).split("\n"):
		var m := re.search(line.strip_edges())
		if m == null:
			continue
		var const_name := m.get_string(1)
		var raw := m.get_string(2)
		var usage := m.get_string(3)
		var value: String
		if _palette_values.has(raw):
			value = "{%s}" % _kebab(raw)
		elif _palette_values.get(const_name) is Color:
			value = _css(_palette_values[const_name])
		else:
			continue
		if TEXT_GROUNDS.has(const_name):
			usage += " " + _contrast_note(const_name)
		out.append({"name": _kebab(const_name), "value": value, "usage": usage.strip_edges()})
	return out


func _contrast_note(text_name: String) -> String:
	var parts := []
	var fg: Color = _palette_values[text_name]
	for ground in TEXT_GROUNDS[text_name]:
		var bg: Color = _palette_values[ground]
		parts.append("%.1f:1 on %s" % [_contrast(fg, bg), _kebab(ground)])
	return "Contrast " + ", ".join(parts) + "."


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	var ch := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * ch.call(c.r) + 0.7152 * ch.call(c.g) + 0.0722 * ch.call(c.b)


# ─── Type ─────────────────────────────────────────────────────────────────────

func _type(theme: Theme) -> Dictionary:
	var styles := []
	for s in TYPE_STYLES:
		var type_name: String = s[0]
		var font := theme.get_font("font", type_name) if theme.has_font("font", type_name) else theme.default_font
		var size := theme.get_font_size("font_size", type_name) if theme.has_font_size("font_size", type_name) \
				else theme.default_font_size
		var style := {
			"name": s[2],
			"fontSize": "%dpx" % size,
			"lineHeight": "%dpx" % roundi(font.get_height(size)),
			"fontWeight": 700 if font.resource_path.contains("Bold") and not font.resource_path.contains("Semi") else 600,
			"usage": s[3],
		}
		if type_name in ["SectionLabel", "KickerLabel"]:
			style["usage"] += " Set in uppercase."
		styles.append(style)
	return {
		"fonts": [],
		"families": {"mali": "Mali, ui-rounded, \"Segoe UI\", system-ui, sans-serif"},
		"groups": [{"name": "Mali", "family": "mali",
			"note": "One family: Mali SemiBold (600) by default, Bold (700) for titles, numbers and buttons.",
			"styles": styles}],
	}


# ─── Felt surfaces ────────────────────────────────────────────────────────────

func _box(theme: Theme, type_name: String, box: String) -> StyleBox:
	return theme.get_stylebox(box, type_name)


func _radius(theme: Theme) -> Array:
	var out := []
	for s in SURFACES:
		var sb = _box(theme, s[1], s[2])
		var r := 0.0
		if sb is StyleBoxFlat:
			r = (sb as StyleBoxFlat).corner_radius_top_left
		elif "corner_radius" in sb:
			r = sb.corner_radius
		out.append({"name": "radius-" + s[0], "value": "%dpx" % roundi(r), "usage": s[3]})
	out.append({"name": "radius-pill", "value": "9999px", "usage": "Bars, tracks and switches: fully rounded ends."})
	return out


func _spacing(theme: Theme) -> Array:
	var out := [{"name": "gutter", "value": "%dpx" % _hud_gutter(), "usage": "Space between the screen edge and felt panels."}]
	for s in SURFACES:
		var sb = _box(theme, s[1], s[2])
		var x: float = sb.content_margin_left
		var y: float = sb.content_margin_top
		if x < 0.0 and y < 0.0:
			continue
		out.append({"name": "pad-%s-x" % s[0], "value": "%dpx" % roundi(maxf(x, 0.0)), "usage": "Horizontal padding inside: " + s[3]})
		out.append({"name": "pad-%s-y" % s[0], "value": "%dpx" % roundi(maxf(y, 0.0)), "usage": "Vertical padding inside: " + s[3]})
	return out


func _shadows(theme: Theme) -> Array:
	var out := []
	for s in SURFACES:
		var sb = _box(theme, s[1], s[2])
		if not ("lip_offset" in sb):
			continue
		var layers := []
		if sb.lip_offset > 0.0 and sb.lip_color.a > 0.0:
			layers.append("0 %dpx 0 %s" % [roundi(sb.lip_offset), _css(sb.lip_color)])
		if sb.shadow_size > 0 and sb.shadow_color.a > 0.0:
			layers.append("%dpx %dpx %dpx %s" % [roundi(sb.shadow_offset.x), roundi(sb.shadow_offset.y),
					sb.shadow_size * 2, _css(sb.shadow_color)])
		if layers.is_empty():
			continue
		out.append({"name": "shadow-" + s[0], "value": ", ".join(layers),
				"usage": "Lip + soft shadow of: " + s[3]})
	return out


func _stitches(theme: Theme) -> Array:
	var out := []
	for s in SURFACES:
		var sb = _box(theme, s[1], s[2])
		if not ("stitch_width" in sb) or sb.stitch_width <= 0.0:
			continue
		out.append({"name": "stitch-" + s[0],
				"value": "%spx %spx %spx %spx" % [_num(sb.stitch_inset), _num(sb.stitch_width), _num(sb.stitch_dash), _num(sb.stitch_gap)],
				"usage": "Seam (inset width dash gap), color %s, in: %s" % [_css(sb.stitch_color), s[3]]})
	return out


func _hud_gutter() -> int:
	var text := FileAccess.get_file_as_string(HUD_PATH)
	var i := text.find("[node name=\"Header\"")
	var m := RegEx.create_from_string("offset_left = ([0-9.]+)").search(text, i)
	return roundi(float(m.get_string(1))) if m else 0


# ─── Helpers ──────────────────────────────────────────────────────────────────

func _kebab(const_name: String) -> String:
	return const_name.to_lower().replace("_", "-")


func _css(c: Color) -> String:
	if c.a >= 0.999:
		return "#" + c.to_html(false)
	return "rgba(%d, %d, %d, %s)" % [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0), _num(snappedf(c.a, 0.01))]


func _num(v: float) -> String:
	return str(v).trim_suffix(".0")
