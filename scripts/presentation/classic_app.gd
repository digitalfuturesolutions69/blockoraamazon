class_name ClassicApp
extends Control

const State = SessionStateMachine.State
var controller: ClassicController
var relax_controller: RelaxController
var _relax_mode := false
var surface: PuzzleSurface
var _margin: MarginContainer
var _scroll: ScrollContainer
var _content: VBoxContainer
var _settings_open := false
var _visual_storage: LocalStorageService
var _classic_colors: VisualStateStore
var _relax_colors: VisualStateStore
var clear_feedback: ClearFeedback
var _reduced_motion := false
var _dialog: ConfirmationDialog
var audio: GameplayAudio
var _last_move_message := ""
var _message_label: Label
var _feedback_label: Label
var _usable_rect := Rect2()
var _touch_size := 96.0
var _font_scale := 1.0
var _safe_poll := 0.0
var _last_screen_safe := Rect2i()
# Optional explicit metrics also support platform adapters and headless fixtures.
var _layout_override := false
var _screen_safe_override := Rect2()
var _dpi_override := 160.0

func configure(storage: LocalStorageService) -> void:
	_visual_storage = storage
	_classic_colors = VisualStateStore.new(storage,"classic")
	_relax_colors = VisualStateStore.new(storage,"relax")
	_reduced_motion = CrystalPalette.reduced_motion(storage)
	controller = ClassicController.new(storage)
	relax_controller = RelaxController.new(storage)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = CrystalPalette.BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var theme_value := Theme.new()
	theme_value.default_font_size = 28
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = CrystalPalette.PANEL if style_name != "pressed" else CrystalPalette.BOARD
		style.set_corner_radius_all(12)
		style.content_margin_left = 22
		style.content_margin_right = 22
		style.content_margin_top = 15
		style.content_margin_bottom = 15
		if style_name == "focus":
			style.draw_center = false
			style.set_border_width_all(2)
			style.border_color = CrystalPalette.VALID
		theme_value.set_stylebox(style_name, "Button", style)
	theme_value.set_color("font_color","Button",CrystalPalette.TEXT)
	theme_value.set_color("font_hover_color","Button",CrystalPalette.TEXT)
	theme_value.set_color("font_pressed_color","Button",CrystalPalette.TEXT)
	theme_value.set_stylebox("panel","Window",CrystalPalette.panel_style(CrystalPalette.PANEL,18))
	theme = theme_value
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_margin.add_child(_scroll)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_dialog = ConfirmationDialog.new()
	_dialog.title = "Start a new game?"
	_dialog.dialog_text = "Your current board will be replaced.\nYour best score will be kept."
	_dialog.ok_button_text = "Restart"
	_dialog.confirmed.connect(_start_new)
	add_child(_dialog)
	audio = GameplayAudio.new()
	add_child(audio)
	clear_feedback = ClearFeedback.new()
	clear_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clear_feedback.reduced_motion = _reduced_motion
	add_child(clear_feedback)
	controller.preferences_changed.connect(_sync_audio)
	controller.changed.connect(_sync_audio)
	relax_controller.changed.connect(_sync_audio)
	# A synthesized GUI click is dispatched before its original touch event.
	# Keep controls attached until this input dispatch has finished.
	controller.changed.connect(_refresh, CONNECT_DEFERRED)
	controller.move_completed.connect(_move_feedback.bind(controller))
	relax_controller.changed.connect(_refresh, CONNECT_DEFERRED)
	relax_controller.move_completed.connect(_move_feedback.bind(relax_controller))
	resized.connect(_safe_margins)
	get_window().size_changed.connect(_safe_margins)
	get_tree().quit_on_go_back = false
	_safe_margins()
	_sync_audio()
	_refresh()

func set_layout_metrics(screen_safe: Rect2, dpi: float, font_scale: float = 1.0) -> void:
	_layout_override = true
	_screen_safe_override = screen_safe
	_dpi_override = dpi
	_font_scale = clampf(font_scale, 1.0, 2.0)
	if is_node_ready():
		_safe_margins()
		_refresh.call_deferred()

func _process(delta: float) -> void:
	if not OS.has_feature("android") or _layout_override:
		return
	_safe_poll += delta
	if _safe_poll >= 0.25:
		_safe_poll = 0.0
		var safe := DisplayServer.get_display_safe_area()
		if safe != _last_screen_safe:
			_safe_margins()

func _safe_margins() -> void:
	if _margin == null:
		return
	if clear_feedback != null:
		clear_feedback.cancel()
	if surface != null:
		surface.cancel_drag()
	theme.default_font_size = roundi(28 * _font_scale)
	var window := get_window()
	var canvas := Rect2(Vector2.ZERO, size)
	var safe := Rect2()
	var dpi := 160.0
	if _layout_override:
		safe = _screen_safe_override
		dpi = _dpi_override
	elif OS.has_feature("android"):
		_last_screen_safe = DisplayServer.get_display_safe_area()
		safe = Rect2(_last_screen_safe)
		dpi = float(DisplayServer.screen_get_dpi())
	_usable_rect = UsableLayout.safe_canvas_rect(safe, Rect2(Vector2(window.position), Vector2(window.size)), get_viewport().get_final_transform(), canvas)
	_touch_size = UsableLayout.touch_target(dpi, get_viewport().get_final_transform())
	var content := UsableLayout.content_rect(_usable_rect)
	for pair in [["margin_left", content.position.x], ["margin_top", content.position.y], ["margin_right", size.x-content.end.x], ["margin_bottom", size.y-content.end.y]]:
		_margin.add_theme_constant_override(pair[0], ceili(pair[1]))
	for button: Button in _content.find_children("*", "Button", true, false):
		button.custom_minimum_size.y = _touch_size
	if surface != null:
		surface.set_minimum_touch_size(_touch_size)
	if _dialog != null and _dialog.visible:
		_position_dialog()

func _position_dialog() -> void:
	var bounds := UsableLayout.content_rect(_usable_rect)
	var requested := Vector2(minf(560.0, bounds.size.x), minf(320.0, bounds.size.y))
	_dialog.size = Vector2i(requested)
	_dialog.position = Vector2i(bounds.position + (bounds.size - Vector2(_dialog.size))/2.0)

func _label(text: String, font_size: int = 24, color: Color = CrystalPalette.TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", roundi(font_size * _font_scale))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	_content.add_child(label)
	return label

func _button(text: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = _touch_size
	button.add_theme_font_size_override("font_size", roundi(28 * _font_scale))
	button.clip_text = true
	button.pressed.connect(action)
	if primary:
		var style := StyleBoxFlat.new()
		style.bg_color = CrystalPalette.PALETTE.mint
		style.set_corner_radius_all(12)
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_color_override("font_color", CrystalPalette.BACKGROUND)
	_content.add_child(button)
	return button

func _space() -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)

func _refresh() -> void:
	if not is_node_ready():
		return
	if clear_feedback != null and (_settings_open or _active_controller().state() != State.PLAYING):
		clear_feedback.cancel()
	if surface != null:
		surface.cancel_drag()
		surface = null
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if not _settings_open and _active_controller().state() == State.PLAYING else ScrollContainer.SCROLL_MODE_AUTO
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _settings_open:
		_show_settings()
	else:
		match _active_controller().state():
			State.HOME: _show_home()
			State.PLAYING: _show_game()
			State.PAUSED: _show_pause()
			State.GAME_OVER: _show_game_over()
	if not _active_controller().save_message().is_empty():
		_message_label = _label(_active_controller().save_message(), 18, CrystalPalette.PALETTE.gold)
		_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _show_home() -> void:
	_space()
	var logo := TextureRect.new()
	logo.texture = preload("res://assets/icon.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size.y = 112
	_content.add_child(logo)
	_label("BLOCKORA", 52)
	_label("A little space. A fresh possibility.", 23, CrystalPalette.SECONDARY)
	_label("CLASSIC  ·  OFFLINE", 19, CrystalPalette.PALETTE.mint)
	_space()
	_label("BEST  " + str(controller.best_score()), 24, CrystalPalette.PALETTE.gold)
	_button("Play Classic", _request_new, true)
	if controller.can_resume():
		_button("Resume Game", func() -> void: controller.resume())
	_button("Settings", func() -> void: _settings_open = true; _refresh.call_deferred())
	_button("Relax Mode", _open_relax)
	if relax_controller.can_resume():
		_button("Resume Relax", func() -> void: _relax_mode = true; relax_controller.resume())
	_button("Daily Challenge  ·  Coming Soon", func() -> void: pass).disabled = true
	_space()
	_label("No timer. Make room for your next move.", 19, CrystalPalette.SECONDARY)

func _show_game() -> void:
	var session := _active_controller().session()
	_label("RELAX" if _relax_mode else "CLASSIC", 20, CrystalPalette.PALETTE.mint)
	_label("%s" % session.score(), 48)
	if _relax_mode:
		_label("No timer. Take your time.", 20, CrystalPalette.SECONDARY)
	else:
		_label("BEST  %s  ·  COMBO  %s" % [controller.best_score(), session.combo()], 20, CrystalPalette.PALETTE.gold)
	surface = PuzzleSurface.new()
	surface.set_minimum_touch_size(_touch_size)
	_content.add_child(surface)
	surface.set_reduced_motion(_reduced_motion)
	surface.show_session(session, true)
	var colors := _active_colors()
	colors.sync(session)
	surface.set_colors(colors.colors)
	surface.placement_requested.connect(_request_placement)
	surface.invalid_placement.connect(_invalid_feedback)
	surface.geometry_changed.connect(_align_feedback)
	_feedback_label = _label(_last_move_message, 20, CrystalPalette.PALETTE.mint)
	_feedback_label.custom_minimum_size.y = roundi(28 * _font_scale)
	var pause := _button("Pause", func() -> void: _active_controller().pause())
	pause.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pause.custom_minimum_size.x = minf(260,_usable_rect.size.x-48)

func _show_pause() -> void:
	_space()
	_label("Take a breath", 44)
	_label("Your board can wait.", 24, CrystalPalette.SECONDARY)
	_label("SCORE  " + str(_active_controller().session().score()), 30, CrystalPalette.PALETTE.gold)
	_space()
	_button("Resume", func() -> void: _active_controller().resume(), true)
	_button("Restart", _confirm_restart)
	_button("Home", _go_home)
	_space()

func _show_game_over() -> void:
	_space()
	_label("No moves left", 44)
	_label("A new board is a new beginning.", 23, CrystalPalette.SECONDARY)
	_label("FINAL SCORE", 20, CrystalPalette.PALETTE.mint)
	var final_text := str(_active_controller().session().score())
	_label(final_text, 44 if final_text.length() > 12 else 64)
	if not _relax_mode:
		_label("BEST  " + str(controller.best_score()), 24, CrystalPalette.PALETTE.gold)
	_space()
	_button("Restart" if _relax_mode else "Play Again", _start_new, true)
	_button("Home", _go_home)
	_space()

func _show_settings() -> void:
	_space()
	_label("Settings", 44)
	_label("Make yourself comfortable.", 24, CrystalPalette.SECONDARY)
	_space()
	var preferences := controller.preferences()
	_button("Sound  ·  " + ("On" if preferences.sound else "Off"), func() -> void: controller.set_preferences(not controller.preferences().sound, controller.preferences().vibration))
	var volume_label := _label("SFX Volume  ·  %d%%" % preferences.sound_volume, 24)
	var volume := HSlider.new()
	volume.name = "SfxVolume"
	volume.min_value = 0
	volume.max_value = 100
	volume.step = 1
	volume.value = preferences.sound_volume
	volume.custom_minimum_size.y = _touch_size
	_content.add_child(volume)
	volume.value_changed.connect(func(value: float) -> void:
		controller.set_sound_volume(int(value))
		volume_label.text = "SFX Volume  ·  %d%%" % int(value))
	_button("Vibration  ·  " + ("On" if preferences.vibration else "Off"), func() -> void: controller.set_preferences(controller.preferences().sound, not controller.preferences().vibration))
	_button("Reduce Motion  ·  " + ("On" if _reduced_motion else "Off"), func() -> void: set_reduced_motion(not _reduced_motion); _refresh.call_deferred())
	_button("Back", func() -> void: _settings_open = false; _refresh.call_deferred(), true)
	_space()

func set_reduced_motion(value: bool) -> void:
	_reduced_motion = value
	clear_feedback.reduced_motion = value
	clear_feedback.cancel()
	if surface != null:
		surface.set_reduced_motion(value)
	_visual_storage.write_record(CrystalPalette.MOTION_KEY,{"schema_version":1,"reduced_motion":value})

func _active_colors() -> VisualStateStore:
	return _relax_colors if _relax_mode else _classic_colors

func _active_controller() -> ClassicController:
	return relax_controller if _relax_mode else controller

func _open_relax() -> void:
	_last_move_message = ""
	_relax_mode = true
	if relax_controller.can_resume():
		relax_controller.resume()
	else:
		_start_new()

func _go_home() -> void:
	_last_move_message = ""
	_active_controller().home()
	_relax_mode = false
	_refresh.call_deferred()

func _request_new() -> void:
	_relax_mode = false
	if controller.can_resume():
		_confirm_restart()
	else:
		_start_new()

func _confirm_restart() -> void:
	_dialog.dialog_text = "Your current Relax board will be replaced." if _relax_mode else "Your current board will be replaced.\nYour best score will be kept."
	_dialog.dialog_autowrap = true
	_dialog.get_ok_button().custom_minimum_size.y = _touch_size
	_dialog.get_cancel_button().custom_minimum_size.y = _touch_size
	_dialog.popup()
	_position_dialog()

func _start_new() -> void:
	_last_move_message = ""
	clear_feedback.cancel()
	_active_controller().new_game(int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec())

func _sync_audio() -> void:
	if audio == null:
		return
	var preferences := controller.preferences()
	audio.set_preferences(preferences.sound, preferences.sound_volume)
	audio.set_paused(_active_controller().state() in [State.HOME, State.PAUSED])
	if clear_feedback != null and _active_controller().state() != State.PLAYING:
		clear_feedback.cancel()

func _align_feedback(_board: Rect2) -> void:
	if surface == null or clear_feedback == null: return
	var transform := get_global_transform_with_canvas().affine_inverse()*surface.get_global_transform_with_canvas()
	clear_feedback.relocate(transform*surface.board_rect())

func _request_placement(slot: int, origin: Vector2i) -> void:
	var result := _active_controller().place(slot, origin)
	if result.status == "invalid":
		_invalid_feedback()

func _invalid_feedback() -> void:
	audio.invalid_placement()

func _move_feedback(result: Dictionary, source: ClassicController) -> void:
	if source != _active_controller():
		return
	var lines: int = result.cleared_rows.size() + result.cleared_columns.size()
	_last_move_message = "%d lines cleared!" % lines if lines > 0 else ""
	if lines == 2: _last_move_message = "DOUBLE CLEAR!  ·  " + _last_move_message
	elif lines >= 3: _last_move_message = "AMAZING!  ·  " + _last_move_message
	if int(result.combo) > 1:
		_last_move_message += "  Combo ×%d" % int(result.combo)
	audio.handle_move(result, "%d:%s" % [source.session().get_instance_id(), result.score])
	if controller.preferences().vibration and OS.has_feature("android"):
		Input.vibrate_handheld(18)
	var colors := _active_colors()
	if colors.apply_confirmed(result,source.session()):
		clear_feedback.cancel() # A fresh move replaces old feedback even without another clear.
		if lines > 0 and surface != null and source.state() == State.PLAYING:
			var transform := get_global_transform_with_canvas().affine_inverse()*surface.get_global_transform_with_canvas()
			var board := transform*surface.board_rect()
			clear_feedback.start("%d:%s" % [source.session().get_instance_id(),VisualStateStore.fingerprint(source.session())],lines,colors.cleared_cells,board)

func interrupt() -> void:
	if clear_feedback != null:
		clear_feedback.cancel()
	if surface != null:
		surface.cancel_drag()
	if controller != null and _active_controller().state() == State.PLAYING:
		_active_controller().pause()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		if audio != null:
			audio.set_backgrounded(true)
		interrupt()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		if audio != null:
			audio.set_backgrounded(false)
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if controller == null:
			return
		if _dialog.visible:
			_dialog.hide()
		elif _settings_open:
			_settings_open = false
			_refresh()
		elif _active_controller().state() == State.PLAYING:
			interrupt()
		elif _active_controller().state() in [State.PAUSED, State.GAME_OVER]:
			_go_home()
		elif _active_controller().state() == State.HOME:
			get_tree().quit()
