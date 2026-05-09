extends Node2D

## 坤坤地下城 — 开始游戏界面

const VS := preload("res://scripts/visual_spec.gd")

var _anim_timer := 0.0
var _btn_hover := false
var _btn_rect := Rect2((VS.VIEWPORT_SIZE.x - 200.0) / 2.0, 380.0, 200.0, 50.0)


func _ready() -> void:
	GameManager.change_state(GameManager.GameState.MAIN_MENU)


func _process(delta: float) -> void:
	_anim_timer += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_start_game()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _btn_rect.has_point(event.position):
			_start_game()

	# 鼠标悬停检测
	if event is InputEventMouseMotion:
		_btn_hover = _btn_rect.has_point(event.position)


func _start_game() -> void:
	GameManager.change_state(GameManager.GameState.LOBBY)
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")


func _draw() -> void:
	var screen := VS.VIEWPORT_SIZE

	# 背景渐变（深色）
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.06, 0.05, 0.08))

	# 装饰粒子（漂浮的子弹壳）
	for i in 20:
		var t := _anim_timer * 0.3 + i * 1.7
		var px := fmod(t * 40.0 + i * 97.0, screen.x)
		var py := fmod(t * 25.0 + i * 63.0, screen.y)
		var alpha := sin(t * 2.0) * 0.15 + 0.2
		var size := 2.0 + sin(t * 1.5) * 1.0
		draw_circle(Vector2(px, py), size, Color(0.3, 0.5, 0.8, alpha))

	# 标题 — 坤坤地下城
	var title := "坤坤地下城"
	var title_size := ThemeDB.fallback_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 48)
	var title_x := (screen.x - title_size.x) / 2.0
	var title_y := 200.0

	# 标题发光效果
	var glow_alpha := sin(_anim_timer * 2.0) * 0.15 + 0.35
	draw_string(ThemeDB.fallback_font, Vector2(title_x + 2, title_y + 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(0.0, 0.5, 1.0, glow_alpha))
	draw_string(ThemeDB.fallback_font, Vector2(title_x, title_y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(0.9, 0.95, 1.0))

	# 副标题
	var subtitle := "一个真正的man"
	var sub_size := ThemeDB.fallback_font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	draw_string(ThemeDB.fallback_font, Vector2((screen.x - sub_size.x) / 2.0, title_y + 35), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.4, 0.5, 0.7))

	# 装饰线
	draw_line(Vector2(280, title_y + 55), Vector2(680, title_y + 55), Color(0.2, 0.3, 0.5, 0.5), 1.0)

	# 开始游戏按钮
	var btn_color := Color(0.15, 0.25, 0.15) if not _btn_hover else Color(0.2, 0.35, 0.2)
	var border_color := Color(0.3, 0.8, 0.4) if not _btn_hover else Color(0.4, 1.0, 0.5)
	draw_rect(_btn_rect, btn_color)
	draw_rect(_btn_rect, border_color, false, 2.0)

	var btn_text := "开始游戏"
	var bt_size := ThemeDB.fallback_font.get_string_size(btn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_string(ThemeDB.fallback_font, Vector2(_btn_rect.position.x + (_btn_rect.size.x - bt_size.x) / 2, _btn_rect.position.y + 33), btn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.8, 1.0, 0.8))

	# 提示
	var hint := "按 Enter 或点击开始"
	var hint_size := ThemeDB.fallback_font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	draw_string(ThemeDB.fallback_font, Vector2((screen.x - hint_size.x) / 2.0, 470), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.4, 0.4, 0.4))

	# 版本号
	draw_string(ThemeDB.fallback_font, Vector2(screen.x - 80, screen.y - 20), "v0.1.0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.3, 0.3))
