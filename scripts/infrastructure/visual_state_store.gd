class_name VisualStateStore
extends RefCounted

var key: String
var _storage: LocalStorageService
var _library := PieceLibrary.new()
var _fingerprint := ""
var colors: Array[String] = []
var cleared_cells: Array[Dictionary] = []
var last_save_error: Error = OK

func _init(storage: LocalStorageService, mode: String) -> void:
	_storage = storage
	key = "crystal_cells_" + mode + "_v1"
	colors.resize(64)
	colors.fill("")

static func fingerprint(session: ClassicSession) -> String:
	return JSON.stringify(session.snapshot()).sha256_text()

static func fallback(index: int) -> String:
	return CrystalPalette.KEYS[(index%8/2 + index/8/2)%CrystalPalette.KEYS.size()]

func _valid(data: Dictionary, session: ClassicSession, expected: String) -> bool:
	var version: Variant = data.get("schema_version")
	if not (version is int or version is float) or not is_finite(float(version)) or version != 1: return false
	if not data.get("fingerprint") is String or data.fingerprint != expected: return false
	if not data.get("colors") is Array or data.colors.size() != 64: return false
	var rows := session.board().serialize()
	for index in 64:
		var color: Variant = data.colors[index]
		if not color is String: return false
		var occupied: bool = (int(rows[index/8]) & (1 << (index%8))) != 0
		if (occupied and not CrystalPalette.PALETTE.has(color)) or (not occupied and color != ""): return false
	return true

func sync(session: ClassicSession) -> void:
	var expected := fingerprint(session)
	if expected == _fingerprint: return
	var record := _storage.read_record(key)
	if record.status == "ok" and _valid(record.data,session,expected):
		colors.assign(record.data.colors)
	else:
		var rows := session.board().serialize()
		for index in 64:
			colors[index] = fallback(index) if (int(rows[index/8]) & (1 << (index%8))) != 0 else ""
	_fingerprint = expected
	cleared_cells.clear()
	# Loading never rewrites valid game records or rejected visual metadata.

func apply_confirmed(result: Dictionary, session: ClassicSession) -> bool:
	if result.get("status") != "ok" or not result.get("placement_origin") is Vector2i or not result.get("score") is int: return false
	if result.score != session.score(): return false
	var expected := fingerprint(session)
	if expected == _fingerprint: return false # Duplicate confirmation/restore cannot repaint or replay.
	var piece := _library.get_piece(str(result.get("piece_id","")))
	if piece == null or not result.get("cleared_rows") is Array or not result.get("cleared_columns") is Array: return false
	for line: Variant in result.cleared_rows + result.cleared_columns:
		if not line is int or line < 0 or line > 7: return false
	var origin: Vector2i = result.placement_origin
	for cell in piece.cells():
		if not PuzzleBoard.valid_coordinate(origin+cell): return false
	for cell in piece.cells():
		var location := origin+cell
		colors[location.y*8+location.x] = CrystalPalette.piece_key(piece)
	cleared_cells.clear()
	var union := {}
	for row: int in result.cleared_rows:
		for x in 8: union[row*8+x] = true
	for column: int in result.cleared_columns:
		for y in 8: union[y*8+column] = true
	for index: int in union:
		cleared_cells.append({"cell":Vector2i(index%8,index/8),"color":colors[index] if not colors[index].is_empty() else fallback(index)})
		colors[index] = ""
	var rows := session.board().serialize()
	for index in 64:
		if (int(rows[index/8]) & (1 << (index%8))) == 0: colors[index] = ""
		elif colors[index].is_empty(): colors[index] = fallback(index)
	_fingerprint = expected
	last_save_error = _storage.write_record(key,{"schema_version":1,"fingerprint":expected,"colors":colors.duplicate()})
	return true
