extends Enemy
## 근거리(졸개): 플레이어에게 곧장 달려들고, 가까워지면 잠깐 노랗게 변했다가 때린다.

## 예비 동작이 끝나는 순간 이 거리 밖이면 빗나간다.
@export var hit_range := 1.6


func _perform_attack() -> void:
	if _dist_to_player() <= hit_range:
		player.take_damage(attack_damage, global_position)
