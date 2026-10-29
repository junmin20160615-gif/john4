class_name Motion
## 플레이어와 적이 함께 쓰는 이동 도우미.
## 미끄러지듯 움직이고, 나무에 정면으로 막혀 거의 못 움직이면 옆으로 살짝 틀어 비켜간다.

const STUCK_RATIO := 0.35


static func slide(body: CharacterBody3D, desired: Vector3) -> void:
	desired.y = 0.0
	body.velocity = desired
	body.move_and_slide()
	var speed := desired.length()
	if speed > 0.1 and body.get_slide_collision_count() > 0 \
			and body.get_real_velocity().length() < speed * STUCK_RATIO:
		var normal := body.get_slide_collision(0).get_normal()
		normal.y = 0.0
		if normal.length() > 0.01:
			var side := normal.normalized().cross(Vector3.UP)
			# 정면 충돌이면 dot이 0 근처라 방향이 흔들리므로 그때는 한쪽으로 고정한다.
			if side.dot(desired) < -0.1 * speed:
				side = -side
			body.velocity = (side * 0.85 + desired.normalized() * 0.15).normalized() * speed
			body.move_and_slide()
	body.position.y = 0.0
