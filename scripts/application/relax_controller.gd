class_name RelaxController
extends ClassicController

var _relax_store: RelaxSessionStore

func _load() -> void:
	_relax_store = RelaxSessionStore.new(_storage)
	_session = _relax_store.load_session()
	_save_message = _relax_store.warning

func _persist() -> void:
	_save_message = ""
	if _session != null:
		_check_write(_relax_store.save_session(_session))

func _write_best() -> void:
	pass # Relax has no best-score pressure and never writes Classic records.

func new_game(seed_value: int) -> bool:
	if not state() in [SessionStateMachine.State.HOME, SessionStateMachine.State.PAUSED, SessionStateMachine.State.GAME_OVER]:
		return false
	var candidate := RelaxPolicy.new_session(seed_value)
	var error := _relax_store.save_session(candidate)
	if error != OK:
		_check_write(error)
		changed.emit()
		return false
	_session = candidate
	_machine.transition(SessionStateMachine.State.PLAYING)
	_save_message = ""
	changed.emit()
	return true

func place(slot: int, origin: Vector2i) -> Dictionary:
	if state() != SessionStateMachine.State.PLAYING or _session == null:
		return {"status":"inactive"}
	# Persist a staged copy before changing the live board or emitting feedback.
	var candidate := RelaxPolicy.restore(RelaxPolicy.snapshot(_session))
	var result := candidate.place(slot,origin)
	if result.status != "ok":
		return result
	var error := _relax_store.save_session(candidate)
	if error != OK:
		_check_write(error)
		changed.emit()
		return {"status":"save_error"}
	_session = candidate
	_save_message = ""
	if _session.finished():
		_machine.transition(SessionStateMachine.State.GAME_OVER)
	result["placement_origin"] = origin # Confirmed presentation event; not persisted game state.
	move_completed.emit(result)
	changed.emit()
	return result
