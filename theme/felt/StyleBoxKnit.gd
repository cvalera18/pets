## StyleBoxKnit.gd
## Knitted strip for bars and slider tracks: a fully rounded fill with optional
## diagonal knit stripes and a sunken top shade. Its height comes from the rect,
## so for sliders set content_margin_top/bottom to half the track thickness.
@tool
extends StyleBox

const FeltDraw := preload("res://theme/felt/FeltDraw.gd")

@export var bg_color := Color("e9dac4"):
	set(v):
		bg_color = v
		emit_changed()
## Darkens a thin band under the top edge so the strip reads as sunken.
@export var inset_shade := Color(0, 0, 0, 0):
	set(v):
		inset_shade = v
		emit_changed()
@export_group("Stripes")
@export var stripe_color := Color(1, 1, 1, 0):
	set(v):
		stripe_color = v
		emit_changed()
@export var stripe_width := 5.7:
	set(v):
		stripe_width = v
		emit_changed()
@export var stripe_period := 11.3:
	set(v):
		stripe_period = v
		emit_changed()


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var draw_rect := rect
	draw_rect.size.x = maxf(rect.size.x, rect.size.y)
	var r := draw_rect.size.y * 0.5
	var body := FeltDraw.rounded_rect(draw_rect, r)
	FeltDraw.fill_rid(to_canvas_item, body, bg_color)

	if inset_shade.a > 0.0:
		var lowered := FeltDraw.rounded_rect(Rect2(draw_rect.position + Vector2(0, 2.5), draw_rect.size), r)
		for poly in Geometry2D.clip_polygons(body, lowered):
			RenderingServer.canvas_item_add_polygon(to_canvas_item, poly, PackedColorArray([inset_shade]))

	if stripe_color.a <= 0.0 or stripe_period <= 0.0:
		return
	var h := draw_rect.size.y
	var x := draw_rect.position.x - h
	var end := draw_rect.end.x
	var y0 := draw_rect.position.y
	while x < end:
		var stripe := PackedVector2Array([
			Vector2(x, y0 + h), Vector2(x + h, y0),
			Vector2(x + h + stripe_width, y0), Vector2(x + stripe_width, y0 + h),
		])
		for poly in Geometry2D.intersect_polygons(stripe, body):
			RenderingServer.canvas_item_add_polygon(to_canvas_item, poly, PackedColorArray([stripe_color]))
		x += stripe_period
