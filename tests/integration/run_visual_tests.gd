extends SceneTree

var checks := 0
var failures := 0
class MemoryStorage extends LocalStorageService:
	var records := {}
	var writes := 0
	var fail_writes := false
	func read_record(key: String) -> Dictionary:
		return {"status":"ok","data":records[key].duplicate(true)} if records.has(key) else {"status":"missing","data":{}}
	func write_record(key: String, value: Dictionary) -> Error:
		if fail_writes: return ERR_CANT_CREATE
		writes += 1
		records[key] = value.duplicate(true)
		return OK

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void: push_error("Visual suite timeout"); quit(1))
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("VISUAL FAIL: "+label)

func settle() -> void:
	await process_frame
	await process_frame

func contrast(a: Color, b: Color) -> float:
	var x := a.srgb_to_linear().get_luminance()
	var y := b.srgb_to_linear().get_luminance()
	return (maxf(x,y)+0.05)/(minf(x,y)+0.05)

func confirmed(session: ClassicSession, slot: int, origin: Vector2i) -> Dictionary:
	var result := session.place(slot,origin)
	result.placement_origin = origin
	return result

func _run() -> void:
	root.size = Vector2i(720,1280)
	var renderer := CrystalBlockRenderer.new()
	check(CrystalBlockRenderer.generation_count == 5 and CrystalBlockRenderer.texture_bytes() == 81920,"five bounded 64px tiles generated once")
	check(CrystalBlockRenderer.CORNER_RATIO >= 0.12 and CrystalBlockRenderer.CORNER_RATIO <= 0.16,"rounded corner budget")
	for key: String in CrystalPalette.KEYS:
		var image := CrystalBlockRenderer.image_for(key)
		check(image.get_size() == Vector2i(64,64) and image.get_pixel(0,0).a == 0,"original tile transparent rounded silhouette")
		check(image.get_pixel(32,12).get_luminance() > image.get_pixel(32,52).get_luminance(),"actual pixel gradient descends softly")
		check(contrast(image.get_pixel(32,55),CrystalPalette.EMPTY) >= 3.0,"occupied core contrast on empty cells")
		check(renderer.texture_for(key) == CrystalBlockRenderer.new().texture_for(key),"resources shared without per-frame recoloring")
	check(contrast(CrystalPalette.SECONDARY,CrystalPalette.PANEL)>=4.5 and contrast(CrystalPalette.TEXT,CrystalPalette.BACKGROUND)>=4.5,"text contrast")
	var library := PieceLibrary.new()
	for id: String in library.ids():
		var piece := library.get_piece(id)
		check(CrystalPalette.piece_key(piece) == piece.render_key(),"stable catalog key in every drawing path")
		check(piece.cells() == library.get_piece(id).cells(),"visual palette cannot alter piece geometry")

	var storage := MemoryStorage.new()
	storage.records[ClassicController.SETTINGS_KEY] = {"schema_version":1,"sound":false,"vibration":false,"sound_volume":25}
	var session := ClassicSession.new(FairPieceProvider.new(222))
	var colors := VisualStateStore.new(storage,"classic")
	colors.sync(session)
	check(storage.writes == 0,"loading initializes view without rewriting any record")
	var first_piece := session.piece_at(0)
	var result := confirmed(session,0,Vector2i(2,2))
	check(result.status == "ok" and colors.apply_confirmed(result,session),"confirmed placement paints after authoritative acceptance")
	check(colors.colors[18] == CrystalPalette.piece_key(first_piece),"placed block matches tray ghost and preview key")
	var after := session.snapshot()
	var writes := storage.writes
	check(not colors.apply_confirmed(result,session) and storage.writes == writes,"duplicate cannot repaint/save/replay")
	var restored := ClassicSession.restore(after)
	var reader := VisualStateStore.new(storage,"classic")
	reader.sync(restored)
	check(reader.colors == colors.colors and restored.snapshot() == after,"exact color and RNG continuation after resume")
	var valid_record: Dictionary = storage.records[colors.key].duplicate(true)
	var invalid_records: Array[Dictionary] = [{},{"schema_version":"1"},{"schema_version":true},{"schema_version":null},{"schema_version":2},{"schema_version":1.5},{"schema_version":1,"fingerprint":VisualStateStore.fingerprint(session),"colors":[]},{"schema_version":1,"fingerprint":"wrong","colors":colors.colors}]
	for version: Variant in [false,"",null,42,{}]:
		var invalid := valid_record.duplicate(true)
		# Persisted JSON arrays are untyped; do not retain the live String array type.
		var malformed_colors: Array = []
		for entry in valid_record.colors: malformed_colors.append(entry)
		malformed_colors[18] = version
		invalid.colors = malformed_colors
		invalid_records.append(invalid)
	for invalid: Dictionary in invalid_records:
		storage.records[colors.key] = invalid
		writes = storage.writes
		var fallback := VisualStateStore.new(storage,"classic")
		fallback.sync(session)
		check(fallback.colors[18] == VisualStateStore.fallback(18) and storage.writes == writes and storage.records[colors.key] == invalid,"malformed/incompatible metadata rejected without overwrite")
	storage.records[colors.key] = valid_record
	check(storage.records[ClassicController.SETTINGS_KEY].sound_volume == 25,"color sidecar preserves audio settings")
	var failure_storage := MemoryStorage.new()
	failure_storage.fail_writes = true
	var failure_colors := VisualStateStore.new(failure_storage,"classic")
	check(failure_colors.apply_confirmed(result,session) and failure_colors.last_save_error != OK and session.snapshot() == after,"visual persistence failure cannot mutate authoritative game")
	var relax := RelaxPolicy.new_session(42)
	var relaxed_colors := VisualStateStore.new(storage,"relax")
	relaxed_colors.sync(relax)
	var relax_piece := relax.piece_at(0)
	var relax_result := confirmed(relax,0,Vector2i.ZERO)
	check(relaxed_colors.apply_confirmed(relax_result,relax) and relaxed_colors.colors[0] == CrystalPalette.piece_key(relax_piece),"Relax shares visual contract")
	check(storage.records[colors.key] == valid_record and relaxed_colors.key != colors.key,"separate Classic and Relax sidecars")
	var relax_reader := VisualStateStore.new(storage,"relax")
	relax_reader.sync(RelaxPolicy.restore(RelaxPolicy.snapshot(relax)))
	check(relax_reader.colors == relaxed_colors.colors,"Relax resume retains color identity")

	# Real application events in both modes: row/column union and capped effects.
	for relaxed in [false,true]:
		for fixture in [{"board":[254,0,0,0,0,0,0,0],"piece":"single","lines":1,"cells":8},{"board":[254,254,0,0,0,0,0,0],"piece":"domino_v","lines":2,"cells":16},{"board":[254,254,254,0,0,0,0,0],"piece":"line3_v","lines":3,"cells":24},{"board":[254,1,1,1,1,1,1,1],"piece":"single","lines":2,"cells":15}]:
			var disk := MemoryStorage.new()
			var source := RelaxPolicy.new_session(42) if relaxed else ClassicSession.new(FairPieceProvider.new(42))
			var snapshot := source.snapshot()
			snapshot.board = fixture.board
			snapshot.tray = [fixture.piece,"single","single"]
			if relaxed:
				var envelope := RelaxPolicy.snapshot(source)
				envelope.session = snapshot
				check(RelaxSessionStore.new(disk).save_session(RelaxPolicy.restore(envelope)) == OK,"Relax clear fixture saved")
			else:
				disk.write_record(ClassicController.SAVE_KEY,snapshot)
			var app := ClassicApp.new()
			app.configure(disk)
			root.add_child(app)
			app._relax_mode = relaxed
			var controller := app._active_controller()
			check(controller.resume(),"real clear fixture resumed")
			await settle()
			var sfx := [0]
			app.audio.cue_played.connect(func(_event: String,_pitch: float,_volume: int) -> void: sfx[0] += 1)
			var before_invalid := controller.session().snapshot()
			check(controller.place(0,Vector2i(-1,0)).status == "invalid" and not app.clear_feedback.active and controller.session().snapshot() == before_invalid,"invalid placement creates no visual transaction")
			var move := controller.place(0,Vector2i.ZERO)
			var layer := app.clear_feedback
			check(move.status == "ok" and move.placement_origin == Vector2i.ZERO,"confirmed application metadata uses exact origin")
			check(layer.active and layer.line_count == fixture.lines and layer.cells.size() == fixture.cells,"clear intensity and unique row-column union")
			check(layer.event_count == 1 and sfx[0] == 1 and layer.particles.size() <= 16,"one visual event and unchanged primary audio with bounded particles")
			var current := controller.session().snapshot()
			controller.move_completed.emit(move)
			check(layer.event_count == 1 and sfx[0] == 1,"duplicate confirmation cannot repeat effects/audio")
			await settle()
			check(app.clear_feedback == layer,"effect host survives deferred surface replacement")
			check(layer.mouse_filter == Control.MOUSE_FILTER_IGNORE,"overlay cannot intercept touches")
			check(app.surface._board_colors == app._active_colors().colors,"rendered board uses same stable color state")
			var follow_up := controller.place(1,Vector2i(4,4))
			check(follow_up.status == "ok" and not layer.active and layer.particles.is_empty(),"fresh non-clear placement replaces old effect immediately")
			current = controller.session().snapshot()
			await settle()
			var generations := CrystalBlockRenderer.generation_count
			for frame in 20: layer._process(0.016)
			check(not layer.active and layer.particles.is_empty() and not layer.is_processing() and controller.session().snapshot() == current,"animation ends without state mutation or retained particles")
			check(CrystalBlockRenderer.generation_count == generations,"no image/resource regeneration during animation")
			layer.start("pause",1,[{"cell":Vector2i.ZERO,"color":"mint"}],app.surface.board_rect())
			controller.pause()
			check(not layer.active,"pause cancels effect synchronously")
			controller.resume()
			await settle()
			check(not layer.active,"save/resume never replays effect")
			app.set_reduced_motion(true)
			check(CrystalPalette.reduced_motion(disk) and not layer.active,"Reduced Motion persisted independently")
			layer.start("reduced",2,[{"cell":Vector2i.ZERO,"color":"mint"}],app.surface.board_rect())
			check(layer.particles.is_empty() and layer._duration == 0.12 and layer.reduced_motion,"reduced motion has static outline/fade only")
			var reduced_surface := app.surface
			reduced_surface._begin(reduced_surface.tray_rect(2).get_center(),0)
			check(reduced_surface._ghost_unit == reduced_surface._tray_unit(2),"reduced motion omits pickup scaling")
			reduced_surface._finish(reduced_surface.size-Vector2(2,2),false)
			check(reduced_surface._return_slot == -1 and not reduced_surface.is_processing() and controller.session().snapshot() == current,"reduced invalid drop returns immediately without state mutation")
			app.interrupt()
			check(not layer.active and not layer.is_processing(),"background/interruption cleans reduced effect")
			app.queue_free()
			await settle()
			check(not is_instance_valid(layer),"renderer/effect host frees safely")

	var effect := ClearFeedback.new()
	root.add_child(effect)
	var child_count := root.get_child_count()
	for index in 1000:
		check(effect.start(str(index),3,[{"cell":Vector2i.ZERO,"color":"mint"}],Rect2(0,0,640,640)),"replacement event starts once")
		check(effect.particles.size() == 16 and effect._recent.size() <= 32,"replacement particles/dedup bounded")
		effect._process(1.0)
		check(not effect.active and effect.cells.is_empty() and effect.particles.is_empty() and not effect.is_processing(),"1000-cycle cleanup")
	check(root.get_child_count() == child_count and CrystalBlockRenderer.generation_count == 5,"no extra nodes/resources across cycles")
	effect.queue_free()
	await settle()
	# Actual JSON persistence, legacy preferences and core-save byte isolation.
	var path := "user://crystal_visual_"+str(Time.get_ticks_usec())
	var json: LocalStorageService = preload("res://scripts/infrastructure/json_local_storage.gd").new(path)
	var classic := ClassicController.new(json)
	check(classic.new_game(222),"disk Classic initialized")
	classic.set_preferences(false,false)
	classic.set_sound_volume(25)
	var core_before: Dictionary = json.read_record(ClassicController.SAVE_KEY)
	var prefs_before: Dictionary = json.read_record(ClassicController.SETTINGS_KEY)
	var colored := VisualStateStore.new(json,"classic")
	colored.sync(classic.session())
	var accepted := classic.place(0,Vector2i(2,2))
	check(colored.apply_confirmed(accepted,classic.session()),"disk event sidecar saved")
	var game_after: Dictionary = json.read_record(ClassicController.SAVE_KEY)
	var fresh := ClassicController.new(json)
	var color_after := VisualStateStore.new(json,"classic")
	color_after.sync(fresh.session())
	check(color_after.colors == colored.colors and fresh.session().snapshot() == classic.session().snapshot(),"actual JSON game/color resume")
	check(json.read_record(ClassicController.SETTINGS_KEY) == prefs_before and json.read_record(ClassicController.SAVE_KEY) == game_after and core_before != game_after,"visual operations never overwrite valid game/audio records")
	var source_file := path.path_join(colored.key+".json")
	for malformed in ["", "{", "[]", "{bad json}"]:
		var file := FileAccess.open(source_file,FileAccess.WRITE)
		file.store_string(malformed)
		file.close()
		var corrupt_reader := VisualStateStore.new(json,"classic")
		corrupt_reader.sync(fresh.session())
		check(corrupt_reader.colors[18] == VisualStateStore.fallback(18) and json.read_record(ClassicController.SAVE_KEY) == game_after,"corrupted sidecar rejects safely while valid game remains loadable")
		check(FileAccess.get_file_as_string(source_file) == malformed,"corruption detection never overwrites evidence or game record")
	for key in [ClassicController.SAVE_KEY,ClassicController.SETTINGS_KEY,ClassicController.BEST_KEY,colored.key]:
		DirAccess.remove_absolute(path.path_join(key+".json"))
	DirAccess.remove_absolute(path)
	await create_timer(0.1).timeout
	print("VISUAL RESULT: %d checks, %d failures; 1000 effect cycles; 5 cached tiles; device validation deferred" % [checks,failures])
	quit(0 if failures == 0 else 1)
