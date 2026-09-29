## StyleBoxFelt.gd
## Felt StyleBox: rounded fill with a bottom lip, soft shadow, an optional sunken
## top shade and an inset stitched seam. Used by the felt Theme for panels,
## buttons and fields; tweak any of it from the Inspector.
@tool
extends StyleBox

const FeltDraw := preload("res://theme/felt/FeltDraw.gd")

@export var bg_color := Color("f7eddd"):
	set(v):
		bg_color = v
		emit_changed()
@export var corner_radius := 22.0:
	set(v):
		corner_radius = v
		emit_changed()
## Rounds only the top corners and leaves the bottom seam open (bottom sheets).
@export var bottom_open := false:
	set(v):
		bottom_open = v
		emit_changed()
@export_group("Depth")
@export var lip_color := Color(0.47, 0.35, 0.24, 0.25):
	set(v):
		lip_color = v
		emit_changed()
@export var lip_offset := 2.0:
	set(v):
		lip_offset = v
		emit_changed()
@export var shadow_color := Color(0.43, 0.31, 0.2, 0.16):
	set(v):
		shadow_color = v
		emit_changed()
@export var shadow_size := 10:
	set(v):
		shadow_size = v
		emit_changed()
@export var shadow_offset := Vector2(0, 5):
	set(v):
		shadow_offset = v
		emit_changed()
## Darkens a thin band under the top edge so the fill reads as sunken.
@export var inset_shade := Color(0, 0, 0, 0):
	set(v):
		inset_shade = v
		emit_changed()
@export_group("Stitch")
@export var stitch_color := Color("bda27e"):
	set(v):
		stitch_color = v
		emit_changed()
@export var stitch_inset := 6.0:
	set(v):
		stitch_inset = v
		emit_changed()
@export var stitch_width := 2.0:
	set(v):
		stitch_width = v
		emit_changed()
@export var stitch_dash := 6.0:
	set(v):
		stitch_dash = v
		emit_changed()
@export var stitch_gap := 5.0:
	set(v):
		stitch_gap = v
		emit_changed()


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if lip_offset > 0.0 and lip_color.a > 0.0:
		var lip_rect := Rect2(rect.position + Vector2(0, lip_offset), rect.size)
		FeltDraw.fill_rid(to_canvas_item, _outline(lip_rect), lip_color)

	var flat := StyleBoxFlat.new()
	flat.bg_color = bg_color
	flat.corner_detail = 10
	flat.anti_aliasing = true
	var r := int(corner_radius)
	flat.corner_radius_top_left = r
	flat.corner_radius_top_right = r
	flat.corner_radius_bottom_left = 0 if bottom_open else r
	flat.corner_radius_bottom_right = 0 if bottom_open else r
	flat.shadow_color = shadow_color
	flat.shadow_size = shadow_size
	flat.shadow_offset = shadow_offset
	flat.draw(to_canvas_item, rect)

	if inset_shade.a > 0.0:
		var body := _outline(rect)
		var lowered := _outline(Rect2(rect.position + Vector2(0, 2.5), rect.size))
		for poly in Geometry2D.clip_polygons(body, lowered):
			RenderingServer.canvas_item_add_polygon(to_canvas_item, poly, PackedColorArray([inset_shade]))

	if stitch_width <= 0.0 or stitch_color.a <= 0.0:
		return
	var inner := rect.grow(-(stitch_inset + stitch_width * 0.5))
	var inner_r := maxf(corner_radius - stitch_inset, 0.0)
	var path: PackedVector2Array
	var closed := true
	if bottom_open:
		inner.size.y += stitch_inset + 40.0
		path = FeltDraw.top_rounded_path(inner, inner_r)
		closed = false
	else:
		path = FeltDraw.rounded_rect(inner, inner_r, 8)
	for d in FeltDraw.dashes(path, closed, stitch_dash, stitch_gap):
		RenderingServer.canvas_item_add_polyline(to_canvas_item, d, PackedColorArray([stitch_color]), stitch_width, true)


func _outline(rect: Rect2) -> PackedVector2Array:
	if bottom_open:
		var tall := Rect2(rect.position, rect.size + Vector2(0, corner_radius))
		var pts := FeltDraw.rounded_rect(tall, corner_radius, 8)
		return pts
	return FeltDraw.rounded_rect(rect, corner_radius, 8)
