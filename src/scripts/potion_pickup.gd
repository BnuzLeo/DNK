extends Area2D

const DISPLAY_SIZE := 34.0
const SPARK_DISPLAY_SIZE := 62.0
const PICKUP_RADIUS := 18.0
const SPARK_FRAME_TIME := 0.08
const BOB_SPEED := 3.4
const BOB_AMOUNT := 4.0
const STATUS_DISPLAY_DURATION := 6.0
const SPEED_BUFF_DURATION := 10.0

const POTION_INFO := {
	"hp": {
		"name": "生命药水",
		"texture": "res://assets/export/projectiles/potion_hp_regen.png.png",
		"message_color": Color(1.0, 0.28, 0.25),
	},
	"mana": {
		"name": "蓝量药水",
		"texture": "res://assets/export/projectiles/potion_mana_regen.png.png",
		"message_color": Color(0.20, 0.65, 1.0),
	},
	"speed": {
		"name": "移速药水",
		"texture": "res://assets/export/projectiles/potion_speed_regen.png.png",
		"message_color": Color(0.20, 1.0, 0.45),
	},
}

const SPARK_FRAME_PATHS := [
	"res://assets/export/projectiles/potion_pickup_spark/01.png",
	"res://assets/export/projectiles/potion_pickup_spark/02.png",
	"res://assets/export/projectiles/potion_pickup_spark/03.png",
	"res://assets/export/projectiles/potion_pickup_spark/04.png",
]

var potion_type := "hp"
var _texture: Texture2D
var _spark_frames: Array[Texture2D] = []
var _spark_frame_index := 0
var _spark_timer := 0.0
var _bob_timer := 0.0
var _picked := false


func setup(type: String) -> void:
	potion_type = type if POTION_INFO.has(type) else "hp"


func _ready() -> void:
	collision_layer = 32
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_load_assets()
	_add_collision_shape()
	z_index = 30
	_bob_timer = randf() * TAU


func _process(delta: float) -> void:
	_bob_timer += delta * BOB_SPEED
	if not _spark_frames.is_empty():
		_spark_timer += delta
		if _spark_timer >= SPARK_FRAME_TIME:
			_spark_timer = fmod(_spark_timer, SPARK_FRAME_TIME)
			_spark_frame_index = (_spark_frame_index + 1) % _spark_frames.size()
	queue_redraw()


func _load_assets() -> void:
	var info: Dictionary = POTION_INFO[potion_type]
	_texture = load(String(info.texture)) as Texture2D
	_spark_frames.clear()
	for path in SPARK_FRAME_PATHS:
		var frame := load(path) as Texture2D
		if frame != null:
			_spark_frames.append(frame)


func _add_collision_shape() -> void:
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = PICKUP_RADIUS
	shape.shape = circle
	add_child(shape)


func _on_body_entered(body: Node2D) -> void:
	if _picked or not body.is_in_group("player"):
		return
	_picked = true
	_apply_potion(body)
	_play_pickup_disappear()


func _apply_potion(player: Node) -> void:
	GameAudio.play_energy()
	var info: Dictionary = POTION_INFO[potion_type]
	match potion_type:
		"hp":
			var amount := maxi(25, int(player.MAX_HP * 0.35))
			var before: int = player.hp
			player.hp = mini(player.MAX_HP, player.hp + amount)
			player.hp_changed.emit(player.hp, player.MAX_HP)
			GameManager.post_message("获得药水：生命 +%d" % (player.hp - before), info.message_color)
			if player.has_method("show_potion_status"):
				player.show_potion_status("hp", STATUS_DISPLAY_DURATION)
		"mana":
			var amount := maxf(30.0, player.MAX_MANA * 0.45)
			var before: float = player.mana
			player.mana = minf(player.MAX_MANA, player.mana + amount)
			GameManager.post_message("获得药水：蓝量 +%d" % int(player.mana - before), info.message_color)
			if player.has_method("show_potion_status"):
				player.show_potion_status("mana", STATUS_DISPLAY_DURATION)
		"speed":
			GameManager.post_message("获得药水：移速 +%d秒" % int(SPEED_BUFF_DURATION), info.message_color)
			if player.has_method("show_potion_status"):
				player.show_potion_status("speed", SPEED_BUFF_DURATION)
			else:
				player.add_buff(1, SPEED_BUFF_DURATION)

	if _texture != null and player.has_method("queue_head_banner"):
		player.queue_head_banner(_texture)


func _play_pickup_disappear() -> void:
	monitoring = false
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE * 1.25, 0.12)
	tween.tween_property(self, "modulate:a", 0.0, 0.12)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	var y_off := sin(_bob_timer) * BOB_AMOUNT
	var base := Vector2(0.0, y_off)
	if not _spark_frames.is_empty():
		var spark := _spark_frames[_spark_frame_index]
		var spark_size := Vector2(SPARK_DISPLAY_SIZE, SPARK_DISPLAY_SIZE)
		draw_texture_rect(spark, Rect2(base - spark_size * 0.5, spark_size), false)
	if _texture != null:
		var potion_size := Vector2(DISPLAY_SIZE, DISPLAY_SIZE)
		draw_texture_rect(_texture, Rect2(base - potion_size * 0.5, potion_size), false)
