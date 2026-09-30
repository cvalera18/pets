## Journal.gd
## The Libreta de Mochi: a felt notebook with what you've found out about her —
## who she is (her temperament, once you've seen enough of it), what she likes
## (foods and her favorite spot), her day (each part once you've watched it) and
## what you two have built. Layout in Journal.tscn; this script asks Pet for the
## data (EventBus.journal_requested → journal_snapshot) and fills it in.
extends CanvasLayer

const P := preload("res://theme/Palette.gd")
const FeltDraw := preload("res://theme/felt/FeltDraw.gd")
const MochiRig := preload("res://scenes/pet/MochiRig.gd")
const Temperament := preload("res://resources/Temperament.gd")
const Routine := preload("res://systems/Routine.gd")

const FOODS := {"tuna": "Tuna", "chicken": "Chicken", "kibble": "Kibble", "carrot": "Carrot"}
const TASTE_KEYS := {"love": "TASTE_LOVES", "like": "TASTE_LIKES", "dislike": "TASTE_DISLIKES", "": "TASTE_UNTRIED"}
const TASTE_COLORS := {"love": P.AFFECTION_TEXT, "like": P.INK_SOFT, "dislike": P.CRIT_TEXT, "": P.MUTED}
## Her favorite spot on the rig's design canvas, and where a question mark goes
## while you don't know it.
const ZONE_AT := {"cheeks": Vector2(134, 116), "head": Vector2(97, 34), "back": Vector2(196, 108)}
const ZONE_UNKNOWN_AT := Vector2(160, 180)
const DAY_PICTO := {"manana": "hambre", "activa": "jugar", "siesta": "sueno", "atardecer": "mimos", "calma": "patita", "noche": "sueno"}
const PAGES := {"WhoTab": "Who", "TastesTab": "Tastes", "DayTab": "Day", "UsTab": "Us"}
const PORTRAIT_SCALE := 0.39
const ZONE_SCALE := 0.467


func _ready() -> void:
	EventBus.journal_snapshot.connect(_fill)
	for tab in PAGES:
		get_node("%" + tab).toggled.connect(_on_tab.bind(tab))
	%Close.pressed.connect(_close)
	$Dim.gui_input.connect(_on_dim_input)
	%PortraitFabric.draw.connect(_draw_fabric)
	%PortraitFrame.draw.connect(_draw_hoop)
	_add_rig(%PortraitFabric, PORTRAIT_SCALE, Vector2(67, 111))
	_add_rig(%ZoneMochi, ZONE_SCALE, MochiRig.ORIGIN * ZONE_SCALE)
	%Book.modulate.a = 0.0
	%Book.position.y += 24.0
	var tween := create_tween().set_parallel()
	tween.tween_property(%Book, "modulate:a", 1.0, 0.25)
	tween.tween_property(%Book, "position:y", %Book.position.y - 24.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	EventBus.journal_requested.emit()


## A small Mochi, drawn behind whatever else the holder shows.
func _add_rig(holder: Control, k: float, at: Vector2) -> void:
	var rig := MochiRig.new()
	rig.scale = Vector2.ONE * k
	rig.position = at
	holder.add_child(rig)
	holder.move_child(rig, 0)


func _on_tab(pressed: bool, tab: String) -> void:
	get_node("%" + PAGES[tab]).visible = pressed


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()


func _close() -> void:
	var tween := create_tween()
	tween.tween_property(%Book, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)


func _draw_fabric() -> void:
	var box: Control = %PortraitFabric
	box.draw_circle(box.size * 0.5, box.size.x * 0.5 - 4.0, P.HOOP_FABRIC)


## The hoop around her portrait; the page color covers what spills past it.
func _draw_hoop() -> void:
	var box: Control = %PortraitFrame
	var c := box.size * 0.5
	var r := box.size.x * 0.5 - 3.0
	var outer := box.size.length() * 0.5
	box.draw_arc(c, (r + outer) * 0.5, 0.0, TAU, 64, P.CARD, outer - r + 2.0, true)
	box.draw_arc(c, r, 0.0, TAU, 64, P.HOOP_WOOD, 6.0, true)
	box.draw_arc(c, r - 3.5, 0.0, TAU, 64, P.HOOP_INNER, 1.5, true)


# ─── Filling it in ────────────────────────────────────────────────────────────

func _fill(data: Dictionary) -> void:
	var days: int = data.get("days", 1)
	%JName.text = data.get("name", "Mochi")
	%JArrived.text = tr("JOURNAL_ARRIVED_TODAY") if days <= 1 else tr("JOURNAL_ARRIVED") % _date(float(data.get("arrived_at", 0.0)))
	%JDays.text = tr("JOURNAL_DAYS_ONE") if days <= 1 else tr("JOURNAL_DAYS") % days
	_scale(%EnergyScale, %EnergyNote, "ENERGY", data.get("energy", 0.0), data.get("energy_known", false), data.get("energy_signs", 0))
	_scale(%AttachScale, %AttachNote, "ATTACH", data.get("attach", 0.0), data.get("attach_known", false), data.get("attach_signs", 0))

	var foods: Dictionary = data.get("foods", {})
	for food in FOODS:
		var taste: String = foods.get(food, "")
		get_node("%" + FOODS[food] + "Pic").taste = taste
		var mark: Label = get_node("%" + FOODS[food] + "Mark")
		mark.text = tr(TASTE_KEYS[taste])
		mark.add_theme_color_override("font_color", TASTE_COLORS[taste])

	var zone: String = data.get("zone", "")
	var mark_at := ZONE_UNKNOWN_AT
	if zone != "":
		%ZoneMark.kind = "corazon"
		mark_at = ZONE_AT.get(zone, ZONE_UNKNOWN_AT)
		%ZoneName.text = _capitalized(tr("ZONE_" + zone.to_upper()))
		_note(%ZoneNote, tr("JOURNAL_ZONE_NOTE"), true)
	else:
		%ZoneMark.kind = "incognita"
		%ZoneName.text = tr("JOURNAL_ZONE_UNKNOWN")
		_note(%ZoneNote, tr("JOURNAL_ZONE_HINT"), false)
	%ZoneMark.position = MochiRig.ORIGIN * ZONE_SCALE + (mark_at - MochiRig.ORIGIN) * ZONE_SCALE - %ZoneMark.size * 0.5

	var seen: Dictionary = data.get("seen", {})
	for i in Routine.BLOCKS.size():
		var block: String = Routine.BLOCKS[i]
		var known := seen.has(block)
		get_node("%Time" + str(i)).text = Routine.HOURS[block]
		get_node("%Doodle" + str(i)).kind = DAY_PICTO[block] if known else "incognita"
		_note(get_node("%Note" + str(i)), tr("DAY_" + block.to_upper()) if known else tr("DAY_UNSEEN"), known)

	var habit: String = data.get("habit", "")
	%HabitTag.visible = habit != ""
	if habit != "":
		%HabitName.text = "TRAIT_NAME_" + habit
		_note(%HabitNote, tr("HABIT_NOTE_" + habit), true)
	else:
		_note(%HabitNote, tr("JOURNAL_HABIT_NONE"), false)
	%BondValue.text = str(data.get("bond_level", 1))
	%DaysValue.text = str(days)
	%CaresValue.text = str(data.get("cares", 0))


func _scale(bar, note: Label, axis: String, value: float, known: bool, signs: int) -> void:
	bar.value = value
	bar.known = known
	bar.signs = signs
	if known:
		_note(note, tr("JOURNAL_%s_%s" % [axis, Temperament.level(value)]), true)
	else:
		_note(note, tr("JOURNAL_WATCH_MORE"), false)


## What's still unknown reads softer.
func _note(label: Label, text: String, known: bool) -> void:
	label.text = text
	if known:
		label.remove_theme_color_override("font_color")
	else:
		label.add_theme_color_override("font_color", P.MUTED)


## The day she arrived, in the player's local time ("29 de septiembre").
func _date(unix: float) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(int(unix) + bias * 60)
	return tr("JOURNAL_DATE").format({"day": d["day"], "month": tr("MONTH_%02d" % d["month"])})


static func _capitalized(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1) if text != "" else text
