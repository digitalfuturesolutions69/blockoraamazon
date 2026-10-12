class_name CrystalBlockRenderer
extends RefCounted

const RESOLUTION := 64
const CORNER_RATIO := 0.14
static var _textures: Dictionary = {}
static var _images: Dictionary = {}
static var generation_count := 0
var _empty_style := CrystalPalette.panel_style(CrystalPalette.EMPTY, 6)

func _init() -> void:
	# Five tiny original procedural tiles, shared by every surface/overlay in process.
	if _textures.is_empty():
		for key: String in CrystalPalette.KEYS:
			var image := _make_tile(CrystalPalette.PALETTE[key])
			_images[key] = image
			_textures[key] = ImageTexture.create_from_image(image)
			generation_count += 1

static func _distance(point: Vector2, center: Vector2, half: Vector2, radius: float) -> float:
	var q := (point-center).abs() - (half-Vector2.ONE*radius)
	return q.max(Vector2.ZERO).length() + minf(maxf(q.x,q.y),0.0) - radius

static func _make_tile(base: Color) -> Image:
	var image := Image.create(RESOLUTION,RESOLUTION,false,Image.FORMAT_RGBA8)
	for y in RESOLUTION:
		for x in RESOLUTION:
			var point := Vector2(x+0.5,y+0.5)
			var distance := _distance(point,Vector2(32,31),Vector2(29,29),58*CORNER_RATIO)
			var coverage := clampf(0.5-distance,0.0,1.0)
			var shadow_distance := _distance(point,Vector2(32,33),Vector2(29,29),58*CORNER_RATIO)
			var shadow := clampf(1.5-shadow_distance,0.0,1.0)*0.22
			var gradient := clampf(float(y-2)/58.0,0.0,1.0)
			var color := base.lightened(0.28).lerp(base.darkened(0.12),gradient)
			if distance < 0 and distance > -1.1:
				color = color.lerp(CrystalPalette.TEXT,0.20)
			var shine := exp(-pow((float(y)-10.0)/3.0,2))*clampf(1.0-absf(float(x)-25.0)/22.0,0.0,1.0)*0.23
			color = color.lerp(CrystalPalette.TEXT,shine)
			color.a = coverage + shadow*(1.0-coverage)
			if coverage == 0: color = Color(0,0,0,shadow)
			image.set_pixel(x,y,color)
	return image

static func cell_rect(corner: Vector2, unit: float) -> Rect2:
	var gap := maxf(1.0,unit*0.035)
	return Rect2(corner+Vector2.ONE*gap,Vector2.ONE*(unit-gap*2))

func draw_block(canvas: CanvasItem, rect: Rect2, key: String, opacity: float = 1.0) -> void:
	if rect.size.x <= 0 or rect.size.y <= 0: return
	canvas.draw_texture_rect(_textures.get(key,_textures.mint),rect,false,Color(1,1,1,opacity))

func draw_empty(canvas: CanvasItem, rect: Rect2) -> void:
	if rect.size.x > 0 and rect.size.y > 0:
		canvas.draw_style_box(_empty_style,rect)

func texture_for(key: String) -> Texture2D:
	return _textures.get(key,_textures.mint)

static func image_for(key: String) -> Image:
	return _images[key]

static func texture_bytes() -> int:
	return RESOLUTION*RESOLUTION*4*CrystalPalette.KEYS.size()
