class_name ClassicController
extends RefCounted

signal changed
signal preferences_changed
signal move_completed(result: Dictionary)

const SAVE_KEY := "classic_session_v1"
const BEST_KEY := "classic_best_v1"
const SETTINGS_KEY := "preferences_v1"
var _storage: LocalStorageService
var _machine := SessionStateMachine.new()
var _session: ClassicSession
var _best := 0
var _sound := true
var _sound_volume := 70
var _vibration := true
var _save_message := ""

func _init(storage: LocalStorageService) -> void:
	_storage = storage
	_machine.transition(SessionStateMachine.State.HOME)
	_load()

func state() -> int:
	return _machine.state()

func session() -> ClassicSession:
	return _session

func best_score() -> int:
	return _best

func preferences() -> Dictionary:
	return {"sound": _sound, "vibration": _vibration, "sound_volume": _sound_volume}

func save_message() -> String:
	return _save_message

func can_resume() -> bool:
	return _session != null and not _session.finished()

func _load() -> void:
	var best := _storage.read_record(BEST_KEY)
	if best.status == "ok" and best.data.get("schema_version") == 1:
		_best = maxi(0, ClassicSession.parse_score(best.data.get("best")))
	var settings := _storage.read_record(SETTINGS_KEY)
	if settings.status == "ok" and settings.data.get("schema_version") == 1:
		if settings.data.get("sound") is bool and settings.data.get("vibration") is bool:
			_sound = settings.data.sound
			_vibration = settings.data.vibration
		var volume: Variant = settings.data.get("sound_volume", 70)
		if (volume is int or volume is float) and is_finite(float(volume)) and volume >= 0 and volume <= 100 and int(volume) == volume:
			_sound_volume = int(volume)
	var saved := _storage.read_record(SAVE_KEY)
	if saved.status == "ok":
		_session = ClassicSession.restore(saved.data)
		if _session == null:
			_save_message = "Saved game could not be read. Start a new game."
		elif _session.score() > _best:
			_best = _session.score()
			_write_best()
	elif saved.status != "missing":
		_save_message = "Saved game could not be read. Start a new game."

func new_game(seed_value: int) -> bool:
	if not state() in [SessionStateMachine.State.HOME, SessionStateMachine.State.PAUSED, SessionStateMachine.State.GAME_OVER]:
		return false
	_session = ClassicSession.new(FairPieceProvider.new(seed_value))
	_machine.transition(SessionStateMachine.State.PLAYING)
	_persist()
	changed.emit()
	return true

func resume() -> bool:
	if not can_resume() or not _machine.transition(SessionStateMachine.State.PLAYING):
		return false
	_persist()
	changed.emit()
	return true

func pause() -> bool:
	if not _machine.transition(SessionStateMachine.State.PAUSED):
		return false
	_persist()
	changed.emit()
	return true

func home() -> bool:
	if not _machine.transition(SessionStateMachine.State.HOME):
		return false
	_persist()
	changed.emit()
	return true

func place(slot: int, origin: Vector2i) -> Dictionary:
	if state() != SessionStateMachine.State.PLAYING or _session == null:
		return {"status": "inactive"}
	var result := _session.place(slot, origin)
	if result.status != "ok":
		return result
	_best = maxi(_best, _session.score())
	if _session.finished():
		_machine.transition(SessionStateMachine.State.GAME_OVER)
	_persist()
	result["placement_origin"] = origin # Confirmed presentation event; not persisted game state.
	move_completed.emit(result)
	changed.emit()
	return result

func set_preferences(sound_enabled: bool, vibration_enabled: bool) -> void:
	_sound = sound_enabled
	_vibration = vibration_enabled
	_save_message = ""
	_write_preferences()
	changed.emit()

func set_sound_volume(percent: int) -> void:
	_sound_volume = clampi(percent, 0, 100)
	_save_message = ""
	_write_preferences()
	# Do not rebuild the GUI while its slider owns the touch gesture.

func _write_preferences() -> void:
	_check_write(_storage.write_record(SETTINGS_KEY, {"schema_version": 1, "sound": _sound, "vibration": _vibration, "sound_volume": _sound_volume}))
	preferences_changed.emit()

func _write_best() -> void:
	_check_write(_storage.write_record(BEST_KEY, {"schema_version": 1, "best": str(_best)}))

func _persist() -> void:
	_save_message = ""
	# Independent best record survives corrupt session data. No half-drag is saved.
	_write_best()
	if _session != null:
		_check_write(_storage.write_record(SAVE_KEY, _session.snapshot()))

func _check_write(error: Error) -> void:
	if error != OK:
		_save_message = "Unable to save progress. Keep the app open and check available storage."
