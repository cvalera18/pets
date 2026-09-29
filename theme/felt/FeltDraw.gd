## FeltDraw.gd
## Shared geometry for the felt look: rounded outlines, ellipses, stitched
## (dashed) seams, SVG rasterizing and the noise behind the fabric texture.
extends RefCounted

static var _svg_cache := {}


static func rounded_rect(rect: Rect2, radius: float, segments: int = 6) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var corners := [
		[rect.position + Vector2(rect.size.x - r, r), -PI * 0.5],
		[rect.position + Vector2(rect.size.x - r, rect.size.y - r), 0.0],
		[rect.position + Vector2(r, rect.size.y - r), PI * 0.5],
		[rect.position + Vector2(r, r), PI],
	]
	var pts := PackedVector2Array()
	for c in corners:
		for i in segments + 1:
			var a: float = c[1] + (PI * 0.5) * i / segments
			pts.append(c[0] + Vector2(cos(a), sin(a)) * r)
	return pts


## Rounded top corners only; the path runs open along the sides and bottom.
static func top_rounded_path(rect: Rect2, radius: float, segments: int = 8) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array([rect.position + Vector2(0, rect.size.y)])
	for i in segments + 1:
		var a := PI + (PI * 0.5) * i / segments
		pts.append(rect.position + Vector2(r, r) + Vector2(cos(a), sin(a)) * r)
	for i in segments + 1:
		var a := -PI * 0.5 + (PI * 0.5) * i / segments
		pts.append(rect.position + Vector2(rect.size.x - r, r) + Vector2(cos(a), sin(a)) * r)
	pts.append(rect.position + rect.size)
	return pts


static func ellipse(center: Vector2, radii: Vector2, segments: int = 64) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	return pts


## Splits an outline into stitch segments (dash) separated by gaps.
static func dashes(points: PackedVector2Array, closed: bool, dash: float, gap: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if points.size() < 2 or dash <= 0.0:
		return out
	var path := points.duplicate()
	if closed:
		path.append(path[0])
	var on := true
	var left := dash
	var cur := PackedVector2Array([path[0]])
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var seg := a.distance_to(b)
		var t := 0.0
		while seg - t > left:
			t += left
			var p := a.lerp(b, t / seg)
			if on:
				cur.append(p)
				out.append(cur)
			else:
				cur = PackedVector2Array([p])
			on = not on
			left = dash if on else gap
		left -= seg - t
		if on:
			cur.append(b)
	if on and cur.size() > 1:
		out.append(cur)
	return out


static func draw_dashes(ci: CanvasItem, points: PackedVector2Array, closed: bool,
		color: Color, width: float, dash: float, gap: float) -> void:
	for d in dashes(points, closed, dash, gap):
		ci.draw_polyline(d, color, width, true)


## Filled polygon with a smoothed edge (draw_colored_polygon has no antialiasing).
## Translucent fills skip the smoothing line: it would stack into a darker rim.
static func fill(ci: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	ci.draw_colored_polygon(points, color)
	if color.a < 0.99:
		return
	var loop := points.duplicate()
	loop.append(points[0])
	ci.draw_polyline(loop, color, 1.0, true)


## RID-based twin of fill(), for StyleBoxes.
static func fill_rid(ci: RID, points: PackedVector2Array, color: Color) -> void:
	if points.size() < 3:
		return
	RenderingServer.canvas_item_add_polygon(ci, points, PackedColorArray([color]))
	if color.a < 0.99:
		return
	var loop := points.duplicate()
	loop.append(points[0])
	RenderingServer.canvas_item_add_polyline(ci, loop, PackedColorArray([color]), 1.0, true)


## Rasterizes an SVG file once per (path, scale) with mipmaps. Reads the raw file
## so new icons work without the editor import step.
static func svg_texture(path: String, scale: float = 4.0) -> Texture2D:
	var key := "%s@%s" % [path, scale]
	if _svg_cache.has(key):
		return _svg_cache[key]
	var tex := svg_string_texture(FileAccess.get_file_as_string(path), scale)
	_svg_cache[key] = tex
	return tex


static func svg_string_texture(svg: String, scale: float = 4.0) -> Texture2D:
	if svg.is_empty():
		return null
	var img := Image.new()
	if img.load_svg_from_string(svg, scale) != OK:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func make_noise(frequency: float, seed_value: int) -> NoiseTexture2D:
	var fnl := FastNoiseLite.new()
	fnl.noise_type = FastNoiseLite.TYPE_PERLIN
	fnl.frequency = frequency
	fnl.fractal_octaves = 2
	fnl.seed = seed_value
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = fnl
	return tex
