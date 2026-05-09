extends Node

enum GameState { MAIN_MENU, LOBBY, PLAYING, PAUSED, DEAD, REVIVING, GAME_OVER }

signal state_changed(old_state: GameState, new_state: GameState)

var _state: GameState = GameState.MAIN_MENU
var state: GameState:
	get: return _state

var total_kills: int = 0
var revive_coins: int = 1

# ── 经济系统 ──
var practice_time: int = 1000
var kun_coins: int = 100

# ── 持久化玩家数据（跨场景保持）──
var player_data: Dictionary = {
	"owned_weapons": ["pistol"],
	"equipped_weapons": ["pistol"],
	"weapon_index": 0,
	"max_weapon_slots": 3,
	"_lobby_equipped": ["pistol"],
	"upgrade_hp_level": 0,
	"upgrade_speed_level": 0,
	"upgrade_mana_level": 0,
	"upgrade_regen_level": 0,
}

# ── 升级费用（练习时长）──
const UPGRADE_COSTS := {
	"hp":    [10, 25, 50, 100, 200],
	"speed": [10, 25, 50, 100, 200],
	"mana":  [10, 25, 50, 100, 200],
	"regen": [15, 30, 60, 120, 250],
}

# ── 武器价格（坤币）──
const WEAPON_COSTS := {
	"shotgun": 1,
	"gatling": 2,
	"freeze":  2,
	"dart":    1,
}

# ── 装备槽位解锁费用（坤币）──
const SLOT_UNLOCK_COSTS := {4: 2, 5: 5}


func change_state(new_state: GameState) -> void:
	if new_state == _state:
		return
	var old := _state
	_state = new_state
	match new_state:
		GameState.MAIN_MENU:
			get_tree().paused = false
			Engine.time_scale = 1.0
		GameState.LOBBY:
			get_tree().paused = false
			Engine.time_scale = 1.0
		GameState.PLAYING:
			Engine.time_scale = 1.0
			get_tree().paused = false
		GameState.PAUSED:
			get_tree().paused = true
		GameState.DEAD:
			get_tree().paused = true
		GameState.REVIVING:
			get_tree().paused = true
		GameState.GAME_OVER:
			get_tree().paused = true
	state_changed.emit(old, new_state)


func restart_game() -> void:
	total_kills = 0
	revive_coins = 1
	practice_time = 0
	kun_coins = 0
	player_data = {
		"owned_weapons": ["pistol"],
		"equipped_weapons": ["pistol"],
		"weapon_index": 0,
		"max_weapon_slots": 3,
		"_lobby_equipped": ["pistol"],
		"upgrade_hp_level": 0,
		"upgrade_speed_level": 0,
		"upgrade_mana_level": 0,
		"upgrade_regen_level": 0,
	}
	return_to_lobby()


func return_to_lobby() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	change_state(GameState.LOBBY)
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")


func add_kill() -> void:
	total_kills += 1
	practice_time += 1


func add_dungeon_clear() -> void:
	kun_coins += 1


# ── 升级系统 ──

func get_upgrade_cost(stat: String) -> int:
	var level: int = player_data.get("upgrade_%s_level" % stat, 0)
	var costs: Array = UPGRADE_COSTS[stat]
	if level >= costs.size():
		return -1
	return costs[level]


func can_afford_upgrade(stat: String) -> bool:
	var cost := get_upgrade_cost(stat)
	return cost > 0 and practice_time >= cost


func purchase_upgrade(stat: String) -> bool:
	if not can_afford_upgrade(stat):
		return false
	practice_time -= get_upgrade_cost(stat)
	player_data["upgrade_%s_level" % stat] += 1
	return true


# ── 武器商店 ──

func purchase_weapon(key: String) -> bool:
	if key not in WEAPON_COSTS:
		return false
	if key in player_data.owned_weapons:
		return false
	if kun_coins < WEAPON_COSTS[key]:
		return false
	kun_coins -= WEAPON_COSTS[key]
	player_data.owned_weapons.append(key)
	return true


func unlock_weapon_slot() -> bool:
	var current: int = player_data.max_weapon_slots
	if current >= 5:
		return false
	var next_slot: int = current + 1
	if next_slot not in SLOT_UNLOCK_COSTS:
		return false
	var cost: int = SLOT_UNLOCK_COSTS[next_slot]
	if kun_coins < cost:
		return false
	kun_coins -= cost
	player_data.max_weapon_slots = next_slot
	return true


func save_lobby_weapons() -> void:
	if player_data.equipped_weapons.is_empty():
		player_data.equipped_weapons = ["pistol"]
	player_data._lobby_equipped = player_data.equipped_weapons.duplicate()


func restore_lobby_weapons() -> void:
	var lobby_equipped: Array = player_data.get("_lobby_equipped", ["pistol"])
	player_data.equipped_weapons = lobby_equipped.duplicate() if not lobby_equipped.is_empty() else ["pistol"]
	player_data.weapon_index = 0
