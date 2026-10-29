extends Enemy
## 덩치: 느리게 쫓아오다 가까워지면 바닥에 빨간 원을 0.8초 보여준 뒤 범위를 내려찍는다. 넉백을 받지 않는다.

@export var slam_radius := 2.5
@export var warning_color := Color(0.95, 0.1, 0.1)
@export var warning_outer_alpha := 0.25
@export var warning_inner_alpha := 0.55

var _warn_outer: MeshInstance3D
var _warn_inner: MeshInstance3D


## 경고 원: 반경 전체를 옅게 깔고, 안쪽 원이 차올라 떨어지는 때를 보여준다.
func _on_windup_start() -> void:
	_warn_outer = Fx.disc(global_position + Vector3.UP * 0.02, slam_radius, warning_color, warning_outer_alpha)
	_warn_inner = Fx.disc(global_position + Vector3.UP * 0.04, 0.01, warning_color, warning_inner_alpha)


func _windup_process(progress: float) -> void:
	if _warn_inner != null:
		var r := maxf(slam_radius * progress, 0.01)
		_warn_inner.scale = Vector3(r, 1.0, r)


func _perform_attack() -> void:
	Fx.ring(global_position, slam_radius, warning_color, 0.25)
	if _dist_to_player() <= slam_radius:
		player.take_damage(attack_damage, global_position)


func _end_windup_visuals() -> void:
	if _warn_outer != null:
		_warn_outer.queue_free()
		_warn_outer = null
	if _warn_inner != null:
		_warn_inner.queue_free()
		_warn_inner = null
