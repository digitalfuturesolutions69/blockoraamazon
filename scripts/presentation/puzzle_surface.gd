class_name PuzzleSurface
extends Control

signal placement_requested(slot: int, origin: Vector2i)
signal invalid_placement
signal geometry_changed(board: Rect2)
const COLORS = CrystalPalette.PALETTE
# Godot InputEvent::DEVICE_ID_EMULATION (core/input/input_event.h).
# GUI buttons need these events; gameplay consumes the original touch only.
const EMULATED_MOUSE_DEVICE := -1
const IDLE := -2
var _board := PuzzleBoard.new()
var _pieces: Array[GamePiece] = []
var _cells: Array = []
var _active := false
var reduced_motion := false
var _pointer_id := IDLE
var _selected := -1
var _pointer := Vector2.ZERO
var _offset := Vector2.ZERO
var _origin := Vector2i.ZERO
var _valid := false
var _board_rect := Rect2()
var _tray_rects: Array[Rect2] = []
var _cell_size := 1.0
var _background := StyleBoxFlat.new()
var _tray_background := CrystalPalette.panel_style(CrystalPalette.PANEL,14)
var renderer := CrystalBlockRenderer.new()
var _board_colors: Array[String] = []
var _minimum_touch_size := 96.0
var _accumulation_before := true
var _owns_accumulation := false
var _candidate_known := false
var _render_pointer := Vector2.ZERO
var _motion_pending := false
var _diagnostics: DragDiagnostics
var _diagnostics_enabled := false
var _diagnostics_raw := false
var _pickup_unit := 27.0
var _ghost_unit := 27.0
var _return_slot := -1
var _return_elapsed := 0.0
var _return_corner := Vector2.ZERO
var _return_unit := 27.0
const RETURN_SECONDS := 0.12

func _ready() -> void:
	custom_minimum_size = Vector2(0, _minimum_touch_size + 216)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_background.bg_color = CrystalPalette.BOARD
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_background.shadow_size = 5
	_background.shadow_color = Color(0,0,0,0.20)
	_background.shadow_offset = Vector2(0,3)
	_background.set_corner_radius_all(14)
	resized.connect(_layout)
	_layout()
	set_process(false)
	_diagnostics_enabled = OS.is_debug_build() and FileAccess.file_exists("user://enable_drag_diagnostics")
	_diagnostics_raw = _diagnostics_enabled and FileAccess.file_exists("user://enable_drag_raw_input")

func show_session(session: ClassicSession, active: bool) -> void:
	cancel_drag()
	_active = active
	_board = session.board()
	_board_colors.resize(64)
	for index in 64:
		_board_colors[index] = VisualStateStore.fallback(index)
	_pieces.clear()
	_cells.clear()
	for slot in 3:
		var piece := session.piece_at(slot)
		_pieces.append(piece)
		_cells.append(piece.cells() if piece != null else [])
	queue_redraw()

func set_reduced_motion(value: bool) -> void:
	reduced_motion = value
	if value and _return_slot >= 0:
		_return_slot = -1
		set_process(is_dragging())
		queue_redraw()

func set_colors(value: Array[String]) -> void:
	if value.size() == 64:
		_board_colors.assign(value)
	queue_redraw()

func set_minimum_touch_size(value: float) -> void:
	_minimum_touch_size = maxf(48.0, value)
	custom_minimum_size = Vector2(0, _minimum_touch_size + 216)
	if is_node_ready():
		_layout()

func _layout() -> void:
	cancel_drag()
	var tray_height := maxf(110, _minimum_touch_size)
	var side := maxf(8, minf(size.x - 16, size.y - tray_height - 56))
	var extra := maxf(0,size.y-side-tray_height-56)
	_board_rect = Rect2(Vector2((size.x - side) / 2, 8+extra/2.0), Vector2.ONE * side)
	_cell_size = side / 8.0
	_tray_rects.clear()
	var width := (size.x - 16) / 3.0
	for slot in 3:
		_tray_rects.append(Rect2(8 + slot * width, _board_rect.end.y + 40, width - 8, tray_height))
	queue_redraw()
	geometry_changed.emit(_board_rect)

func board_rect() -> Rect2:
	return _board_rect

func tray_rect(slot: int) -> Rect2:
	return _tray_rects[slot]

func is_dragging() -> bool:
	return _selected >= 0

func drag_origin() -> Vector2i:
	return _origin

func preview_valid() -> bool:
	return _valid

func cancel_drag(reason: String = "canceled") -> void:
	if _diagnostics != null:
		_diagnostics.finish(reason)
		_diagnostics = null
	_motion_pending = false
	if _owns_accumulation:
		Input.use_accumulated_input = _accumulation_before
		_owns_accumulation = false
	_return_slot = -1
	set_process(false)
	_candidate_known = false
	_pointer_id = IDLE
	_selected = -1
	_valid = false
	queue_redraw()

func _local_pointer(position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * position

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == EMULATED_MOUSE_DEVICE:
		return
	if not _active or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_begin(_local_pointer(event.position), event.index)
		elif event.index == _pointer_id:
			_finish(_local_pointer(event.position), event.canceled)
	elif event is InputEventScreenDrag and event.index == _pointer_id:
		_move(_local_pointer(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin(_local_pointer(event.position), -1)
		elif _pointer_id == -1:
			_finish(_local_pointer(event.position), event.canceled)
	elif event is InputEventMouseMotion and _pointer_id == -1:
		_move(_local_pointer(event.position))

func _begin(position: Vector2, pointer_id: int) -> void:
	if _selected != -1:
		return
	for slot in _tray_rects.size():
		if _tray_rects[slot].has_point(position) and _pieces[slot] != null:
			_selected = slot
			_pointer_id = pointer_id
			var dimensions := _pieces[slot].dimensions()
			_return_slot = -1
			set_process(true)
			var pickup_scale := 1.0 if reduced_motion else 1.04
			_pickup_unit = _tray_unit(slot) * pickup_scale
			var corner := _tray_corner(slot)
			# Retain the actual grab location; lift only eight logical units at pickup.
			var grab := (position - corner).clamp(Vector2.ZERO, Vector2(dimensions) * _tray_unit(slot))
			_offset = -grab * pickup_scale - Vector2(0, 8)
			_ghost_unit = _pickup_unit
			_candidate_known = false
			_accumulation_before = Input.use_accumulated_input
			# Keep normal engine accumulation. Raw dispatch is a debug-only A/B option.
			_owns_accumulation = _diagnostics_raw
			if _diagnostics_raw:
				Input.use_accumulated_input = false
			if _diagnostics_enabled:
				_diagnostics = DragDiagnostics.new(Input.use_accumulated_input)
			_apply_pointer(position)
			get_viewport().set_input_as_handled()
			return

func _move(position: Vector2) -> void:
	if _selected < 0:
		return
	_pointer = position
	_motion_pending = true
	if _diagnostics != null:
		_diagnostics.event()
	get_viewport().set_input_as_handled()

func _apply_pointer(position: Vector2) -> void:
	_pointer = position
	_render_pointer = position
	_motion_pending = false
	var relative := (position + _offset - _board_rect.position) / _cell_size
	var candidate := Vector2i(floori(relative.x), floori(relative.y))
	if not _candidate_known or candidate != _origin:
		_origin = candidate
		_valid = _board.can_place(_pieces[_selected], _origin)
		_candidate_known = true
	queue_redraw()

func _finish(position: Vector2, canceled: bool) -> void:
	if _selected < 0:
		return
	get_viewport().set_input_as_handled()
	# Release is authoritative immediately, even before the next visual frame.
	_apply_pointer(position)
	var slot := _selected
	var origin := _origin
	# A release outside this control is always cancellation, even if offset fits.
	var commit := not canceled and _valid and Rect2(Vector2.ZERO, size).has_point(position)
	var corner := _pointer + _offset
	var unit := _ghost_unit
	cancel_drag("accepted" if commit else ("canceled" if canceled else "invalid"))
	if commit:
		placement_requested.emit(slot, origin)
	elif not canceled and Rect2(Vector2.ZERO, size).has_point(position):
		# View-only return; pointer ownership and input mode are already released.
		if not reduced_motion:
			_return_slot = slot
			_return_corner = corner
			_return_unit = unit
			_return_elapsed = 0.0
			set_process(true)
		invalid_placement.emit()

func pointer_for_origin(slot: int, origin: Vector2i) -> Vector2:
	# Shared coordinate helper used by real event integration tests.
	var dimensions := _pieces[slot].dimensions()
	var offset := _offset if _selected == slot else -Vector2(dimensions) * _tray_unit(slot) * (0.5 if reduced_motion else 0.52) - Vector2(0, 8)
	return _board_rect.position + Vector2(origin) * _cell_size + Vector2.ONE * (_cell_size * 0.1) - offset

func _tray_unit(slot: int) -> float:
	var rect := _tray_rects[slot]
	var dimensions := _pieces[slot].dimensions()
	return minf(32, minf((rect.size.x - 24) / dimensions.x, (rect.size.y - 24) / dimensions.y))

func _tray_corner(slot: int) -> Vector2:
	return _tray_rects[slot].get_center() - Vector2(_pieces[slot].dimensions()) * _tray_unit(slot) / 2.0

func _process(delta: float) -> void:
	if _selected >= 0:
		if _motion_pending:
			_apply_pointer(_pointer)
		if _diagnostics != null:
			_diagnostics.frame(_pointer, _render_pointer + _offset, _origin)
		return
	_return_elapsed += delta
	if _return_elapsed >= RETURN_SECONDS:
		_return_slot = -1
		set_process(false)
	queue_redraw()

func _exit_tree() -> void:
	cancel_drag()

func _draw_ghost(slot: int, corner: Vector2, unit: float, alpha: float) -> void:
	for cell in _cells[slot]:
		var rect := CrystalBlockRenderer.cell_rect(corner+Vector2(cell)*unit,unit)
		renderer.draw_block(self,rect,CrystalPalette.piece_key(_pieces[slot]),alpha)

func _draw() -> void:
	draw_style_box(_background, _board_rect.grow(6))
	for y in 8:
		for x in 8:
			var rect := CrystalBlockRenderer.cell_rect(_board_rect.position+Vector2(x,y)*_cell_size,_cell_size)
			var occupied := _board.read_cell(Vector2i(x, y)) == PuzzleBoard.CellState.OCCUPIED
			if occupied:
				renderer.draw_block(self,rect,_board_colors[y*8+x] if not _board_colors[y*8+x].is_empty() else VisualStateStore.fallback(y*8+x))
			else:
				renderer.draw_empty(self,rect)

	for slot in _tray_rects.size():
		var rect := _tray_rects[slot]
		draw_style_box(_tray_background,rect)
		if slot == _selected:
			draw_rect(rect.grow(-2), CrystalPalette.TEXT, false, 3)
		if slot >= _pieces.size() or _pieces[slot] == null:
			var center := rect.get_center()
			draw_line(center + Vector2(-8, 0), center + Vector2(-1, 7), Color("5a7287"), 3)
			draw_line(center + Vector2(-1, 7), center + Vector2(13, -8), Color("5a7287"), 3)
			continue
		var piece := _pieces[slot]
		var dimensions := piece.dimensions()
		var unit := minf(32, minf((rect.size.x - 24) / dimensions.x, (rect.size.y - 24) / dimensions.y))
		var corner := rect.get_center() - Vector2(dimensions) * unit / 2.0
		var opacity := 0.35 if slot == _selected or slot == _return_slot else 1.0
		for cell in _cells[slot]:
			renderer.draw_block(self,CrystalBlockRenderer.cell_rect(corner+Vector2(cell)*unit,unit),CrystalPalette.piece_key(piece),opacity)

	var hint := "Drag a piece onto the board"
	if _selected >= 0:
		hint = "✓ Fits — release to place" if _valid else "× Doesn't fit — release to cancel"
		var color := CrystalPalette.VALID if _valid else CrystalPalette.INVALID
		for cell in _cells[_selected]:
			var rect := CrystalBlockRenderer.cell_rect(_board_rect.position+Vector2(_origin+cell)*_cell_size,_cell_size)
			renderer.draw_block(self,rect,CrystalPalette.piece_key(_pieces[_selected]),0.32)
			draw_rect(rect, color, false, 2)
			var center := rect.get_center()
			if _valid:
				draw_line(center + Vector2(-7, 0), center + Vector2(-1, 6), CrystalPalette.BACKGROUND, 3)
				draw_line(center + Vector2(-1, 6), center + Vector2(10, -7), CrystalPalette.BACKGROUND, 3)
			else:
				draw_line(center + Vector2(-6, -6), center + Vector2(6, 6), CrystalPalette.BACKGROUND, 3)
				draw_line(center + Vector2(6, -6), center + Vector2(-6, 6), CrystalPalette.BACKGROUND, 3)
		# The continuous ghost shares its offset with candidate mapping.
		if _diagnostics != null:
			_diagnostics.draw(_render_pointer + _offset)
		_draw_ghost(_selected, _render_pointer + _offset, _ghost_unit, 0.80)
	if _return_slot >= 0:
		var progress := clampf(_return_elapsed / RETURN_SECONDS, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - progress, 3)
		_draw_ghost(_return_slot, _return_corner.lerp(_tray_corner(_return_slot), eased), lerpf(_return_unit, _tray_unit(_return_slot), eased), 0.65)
	var font := ThemeDB.fallback_font
	var font_size := 19
	var text_width := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - text_width) / 2, _board_rect.end.y + 29), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, CrystalPalette.SECONDARY)
