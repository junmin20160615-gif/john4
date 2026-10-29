class_name MagicMissile
extends Area3D
## 매직 미사일: 곧게 날아가 처음 맞은 적 하나에 피해를 주고 사라진다. 나무·벽에 막히고, 최대 거리를 넘으면 사라진다.

@export var speed := 12.0
@export var damage := 15
@export var max_distance := 12.0
@export var color := Color(0.55, 0.9, 1.0)

var _dir := Vector3.FORWARD
var _travelled := 0.0
var _done := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$Mesh.material_override = Fx.material(color)


func launch(from: Vector3, dir: Vector3) -> void:
	_dir = Vector3(dir.x, 0.0, dir.z).normalized()
	global_position = from
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
	var enemy := body as Enemy
	if enemy != null:
		if enemy.is_dead:
			return
		enemy.take_damage(damage, global_position)
	_done = true
	Fx.burst(global_position, color)
	queue_free()
