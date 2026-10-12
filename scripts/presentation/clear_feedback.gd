class_name ClearFeedback
extends Control

const MAX_PARTICLES := 16
var renderer := CrystalBlockRenderer.new()
var active := false
var reduced_motion := false
var event_count := 0
var line_count := 0
var cells: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var _board_rect := Rect2()
var _unit := 1.0
var _elapsed := 0.0
var _duration := 0.20
var _recent: Array[String] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_process(false)

func start(transaction: String, lines: int, cleared: Array[Dictionary], board: Rect2) -> bool:
	if transaction.is_empty() or transaction in _recent or lines < 1 or cleared.is_empty(): return false
	_recent.append(transaction)
	if _recent.size() > 32: _recent.pop_front()
	cancel()
	line_count = lines
	cells = cleared.duplicate(true)
	_board_rect = board
	_unit = board.size.x/8.0
	_elapsed = 0
	_duration = 0.12 if reduced_motion else (0.20 if lines == 1 else 0.22)
	if not reduced_motion:
		var count := mini(MAX_PARTICLES,8 if lines == 1 else (12 if lines == 2 else 16))
		for index in count:
			var cell: Dictionary = cells[index%cells.size()]
			var angle := float((index*137)%360)*PI/180.0
			particles.append({"cell":cell.cell,"direction":Vector2(cos(angle),sin(angle))*1.5,"color":cell.color})
	active = true
	event_count += 1
	modulate.a = 1
	set_process(true)
	queue_redraw()
	return true

func relocate(board: Rect2) -> void:
	_board_rect = board
	_unit = board.size.x/8.0
	if active: queue_redraw()

func cancel() -> void:
	active = false
	cells.clear()
	particles.clear()
	set_process(false)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		cancel()
		return
	modulate.a = 1.0-_elapsed/_duration
	queue_redraw()

func _draw() -> void:
	if not active: return
	for cell in cells:
		var rect := CrystalBlockRenderer.cell_rect(_board_rect.position+Vector2(cell.cell)*_unit,_unit)
		if reduced_motion:
			draw_rect(rect,CrystalPalette.VALID,false,2)
		else:
			renderer.draw_block(self,rect,cell.color)
			draw_rect(rect,CrystalPalette.TEXT,false,2)
	if not reduced_motion:
		for particle in particles:
			var point: Vector2 = _board_rect.position+(Vector2(particle.cell)+Vector2.ONE*0.5)*_unit+particle.direction*_unit*_elapsed
			if not _board_rect.has_point(point): continue
			var color: Color = CrystalPalette.PALETTE[particle.color]
			draw_line(point-Vector2(3,0),point+Vector2(3,0),color,2)
			draw_line(point-Vector2(0,3),point+Vector2(0,3),color,2)

func _exit_tree() -> void:
	cancel()
