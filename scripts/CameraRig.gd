extends Node3D
## 쿼터뷰 카메라 받침대. 플레이어 위치를 부드럽게 따라간다.
## 각도(X −45°, Y 45°)와 직교 설정은 자식 Camera3D에 있다.

@export var target_path: NodePath
@export var follow_speed := 6.0

@onready var _target: Node3D = get_node(target_path)


func _ready() -> void:
	global_position = _flat(_target.global_position)
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	global_position = global_position.lerp(_flat(_target.global_position), 1.0 - exp(-follow_speed * delta))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
