extends Enemy
## 원거리(궁수): 플레이어와 7~9 m 거리를 유지하며, 0.5초 조준 후 화살을 한 발 쏜다.

@export var min_distance := 7.0
@export var max_distance := 9.0
@export var arrow_scene: PackedScene
@export var arrow_forward := 0.5
@export var arrow_height := 0.8


## min_distance − 1 m보다 가까우면 쏘지 않고 먼저 물러난다.
func _can_start_attack() -> bool:
	var dist := _dist_to_player()
	return dist >= min_distance - 1.0 and dist <= max_distance + 1.0


func _chase_velocity() -> Vector3:
	var to := _to_player()
	var dist := to.length()
	if dist < 0.01:
		return Vector3.ZERO
	if dist < min_distance:
		return -to / dist * move_speed
	if dist > max_distance:
		return to / dist * move_speed
	return Vector3.ZERO


## 화살은 조준이 끝나는 순간의 플레이어 방향으로 곧게 날아간다.
func _perform_attack() -> void:
	if arrow_scene == null:
		return
	var dir := _to_player().normalized()
	if dir == Vector3.ZERO:
		dir = -global_basis.z
	var arrow := arrow_scene.instantiate() as EnemyArrow
	arrow.damage = attack_damage
	Fx.add_projectile(arrow)
	arrow.launch(global_position + dir * arrow_forward + Vector3.UP * arrow_height, dir)
