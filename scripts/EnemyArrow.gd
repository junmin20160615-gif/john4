class_name EnemyArrow
extends Area3D
## 궁수의 화살: 쏜 순간의 방향으로 곧게 날아가 플레이어에게 피해를 준다. 나무·벽에 막히고 최대 거리를 넘으면 사라진다.

@export var speed := 7.0
@export var damage := 8
@export var max_distance := 20.0
@export var color := Color(1.0, 0.75, 0.3)

var _dir := Vector3.FORWARD
var _travelled := 0.0
var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Mesh.material_override = Fx.material(color)


func launch(from: Vector3, dir: Vector3) -> void:
	_dir = Vector3(dir.x, 0.0, dir.z).normalized()
	global_position = from
	look_at(from + _dir, Vector3.UP)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	var step := speed * delta
	global_position += _dir * step
	_travelled += step
	if _travelled >= max_distance:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if _done:
		return
	var target := body as Player
	if target != null:
		target.take_damage(damage, global_position)
	_done = true
	Fx.burst(global_position, color)
	queue_free()
