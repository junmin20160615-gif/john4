extends Node3D
## 게임 시작 때 한 번: 처음 그릴 때 생기는 셰이더 컴파일 멈춤을 바닥 밑 안 보이는 곳에서 미리 치른다.

@export var prewarm_colors: Array[Color] = [Color(1, 1, 1), Color(0.95, 0.1, 0.1)]


func _ready() -> void:
	Fx.prewarm(prewarm_colors)
	var sprite := Sprite3D.new()
	sprite.texture = Enemy.bar_texture()
	sprite.modulate = Color(1, 1, 1, 0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.position = Vector3(0, -2, 0)
	add_child(sprite)
	get_tree().create_timer(0.1).timeout.connect(sprite.queue_free)
