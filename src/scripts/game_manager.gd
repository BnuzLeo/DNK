extends Node

enum GameState { MAIN_MENU, PLAYING, PAUSED, GAME_OVER }

signal state_changed(old_state: GameState, new_state: GameState)

var _state: GameState = GameState.MAIN_MENU
var state: GameState:
	get: return _state

var total_kills: int = 0


func change_state(new_state: GameState) -> void:
	if new_state == _state:
		return
	var old := _state
	_state = new_state
	match new_state:
		GameState.PLAYING:
			Engine.time_scale = 1.0
			get_tree().paused = false
		GameState.PAUSED:
			get_tree().paused = true
		GameState.GAME_OVER:
			get_tree().paused = true
	state_changed.emit(old, new_state)


func restart_game() -> void:
	total_kills = 0
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
	change_state(GameState.PLAYING)


func add_kill() -> void:
	total_kills += 1
