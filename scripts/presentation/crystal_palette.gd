class_name CrystalPalette
extends RefCounted

const BACKGROUND := Color("101c38")
const PANEL := Color("1a2b49")
const BOARD := Color("233655")
# Slightly darker than the suggested empty token to retain gradient edge contrast.
const EMPTY := Color("283b5b")
const TEXT := Color("ffffff")
const SECONDARY := Color("a9bad7")
const VALID := Color("b8f6d7")
const INVALID := Color("ffb1c5")
const PALETTE := {"mint":Color("38d6a0"),"gold":Color("ffb64c"),"blue":Color("3b9cff"),"rose":Color("e777b8"),"lavender":Color("42b9f3")}
const KEYS := ["mint","gold","blue","rose","lavender"]
const MOTION_KEY := "crystal_motion_v1"

static func piece_key(piece: GamePiece) -> String:
	return piece.render_key() if piece != null and PALETTE.has(piece.render_key()) else "mint"

static func panel_style(color: Color, radius: int = 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

static func reduced_motion(storage: LocalStorageService) -> bool:
	var record := storage.read_record(MOTION_KEY)
	if record.status != "ok": return false
	var data: Dictionary = record.data
	var version: Variant = data.get("schema_version")
	if not (version is int or version is float) or not is_finite(float(version)) or version != 1:
		return false
	return data.reduced_motion if data.get("reduced_motion") is bool else false
