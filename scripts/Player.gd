class_name Player
extends CharacterBody3D
## 마법사. 좌클릭/WASD 이동, 우클릭 근접 공격, Q 매직 미사일, Space 순간이동.
## 공격은 모두 마우스 커서가 가리키는 바닥 지점 방향으로 나간다.

signal died
signal health_changed(current: int, maximum: int)
## slot: 0 근접 공격, 1 매직 미사일, 2 순간이동
signal cooldown_started(slot: int, duration: float)

@export_group("이동")
@export var move_speed := 5.0
@export var stop_distance := 0.2
@export var turn_speed := 14.0
@export var map_half_size := 20.0
@export var click_marker_color := Color(1.0, 1.0, 1.0)

@export_group("체력")
@export var max_health := 100
@export var hurt_invuln_time := 0.5

@export_group("근접 공격")
@export var melee_damage := 20
@export var melee_range := 1.8
@export var melee_angle := 90.0
@export var melee_knockback := 1.0
@export var melee_cooldown := 0.4
@export var melee_color := Color(0.75, 0.9, 1.0)

@export_group("매직 미사일")
@export var missile_scene: PackedScene
@export var missile_cooldown := 0.6
@export var missile_forward := 0.5
@export var missile_height := 1.0

@export_group("순간이동")
@export var teleport_distance := 4.0
@export var teleport_invuln_time := 0.3
@export var teleport_cooldown := 3.0
@export var teleport_color := Color(0.3, 0.55, 1.0)

@export_group("공격 경직")
@export var attack_pause := 0.15

@export_group("사망 연출")
@export var dead_color := Color(0.45, 0.45, 0.45)

var health := 0
var is_dead := false

var _target := Vector3.ZERO
var _has_target := false
var _ignore_held_click := false
var _pause := 0.0
var _invuln := 0.0
var _blink := 0.0
var _melee_cd := 0.0
var _missile_cd := 0.0
var _teleport_cd := 0.0
var _material: StandardMaterial3D

@onready var _model: Node3D = $Model
@onready var _body_mesh: MeshInstance3D = $Model/Body
@onready var _shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group("player")
	health = max_health
	_material = ((_body_mesh.mesh as PrimitiveMesh).material as StandardMaterial3D).duplicate()
	_body_mesh.material_override = _material
	health_changed.emit.call_deferred(health, max_health)


func _physics_process(delta: float) -> void:
	_melee_cd = maxf(_melee_cd - delta, 0.0)
	_missile_cd = maxf(_missile_cd - delta, 0.0)
	_teleport_cd = maxf(_teleport_cd - delta, 0.0)
	_invuln = maxf(_invuln - delta, 0.0)
	_pause = maxf(_pause - delta, 0.0)
	if _blink > 0.0:
		_blink -= delta
		_body_mesh.visible = _blink <= 0.0 or int(_blink * 20.0) % 2 == 0
	if is_dead:
		return
	_handle_actions()
	_handle_movement(delta)


func take_damage(amount: int, _from_position: Vector3) -> void:
	if is_dead or _invuln > 0.0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	if health <= 0:
		_die()
		return
	_invuln = hurt_invuln_time
	_blink = hurt_invuln_time


# --- 입력 ---

func _handle_actions() -> void:
	if Input.is_action_pressed("attack_melee") and _melee_cd <= 0.0:
		_melee(_aim_dir())
	if Input.is_action_pressed("cast_missile") and _missile_cd <= 0.0:
		_cast_missile(_aim_dir())
	if Input.is_action_just_pressed("teleport") and _teleport_cd <= 0.0:
		_teleport()


func _handle_movement(delta: float) -> void:
	var clicked := Input.is_action_just_pressed("move")
	if clicked or not Input.is_action_pressed("move"):
		_ignore_held_click = false
	if Input.is_action_pressed("move") and not _ignore_held_click:
		var point: Variant = _cursor_point()
		if point != null:
			_target = _clamp_to_map(point)
			_has_target = true
			if clicked:
				Fx.ring(_target, 0.35, click_marker_color, 0.3)

	var desired := Vector3.ZERO
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		_has_target = false
		desired = _screen_to_world(input_dir) * move_speed
	elif _has_target:
		var to := _target - global_position
		to.y = 0.0
		if to.length() <= stop_distance:
			_has_target = false
		else:
			desired = to.normalized() * move_speed

	if _pause > 0.0:
		desired = Vector3.ZERO
	Motion.slide(self, desired)
	if desired.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, _yaw_of(desired), 1.0 - exp(-turn_speed * delta))


# --- 동작 ---

func _melee(dir: Vector3) -> void:
	_melee_cd = melee_cooldown
	cooldown_started.emit(0, melee_cooldown)
	_begin_attack(dir)
	var half := deg_to_rad(melee_angle * 0.5)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead:
			continue
		var to := enemy.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist > melee_range + enemy.body_radius:
			continue
		if dist > 0.3 and dir.angle_to(to) > half:
			continue
		enemy.take_damage(melee_damage, global_position)
		enemy.apply_knockback((to / dist if dist > 0.01 else dir) * melee_knockback)
	Fx.fan(global_position, rotation.y, melee_range, melee_angle, melee_color)


func _cast_missile(dir: Vector3) -> void:
	if missile_scene == null:
		return
	_missile_cd = missile_cooldown
	cooldown_started.emit(1, missile_cooldown)
	_begin_attack(dir)
	var missile := missile_scene.instantiate() as MagicMissile
	Fx.add_projectile(missile)
	missile.launch(global_position + dir * missile_forward + Vector3.UP * missile_height, dir)


func _teleport() -> void:
	var point: Variant = _cursor_point()
	if point == null:
		return
	var offset: Vector3 = point - global_position
	offset.y = 0.0
	if offset.length() < 0.1:
		return
	if offset.length() > teleport_distance:
		offset = offset.normalized() * teleport_distance
	var dest := global_position + offset
	# 도착점이 나무나 맵 밖이면 발동하지 않고 쿨다운도 쓰지 않는다.
	if not _is_free_spot(dest):
		return
	var start := global_position
	global_position = dest
	reset_physics_interpolation()
	rotation.y = _yaw_of(offset)
	_has_target = false
	_invuln = maxf(_invuln, teleport_invuln_time)
	_teleport_cd = teleport_cooldown
	cooldown_started.emit(2, teleport_cooldown)
	Fx.ring(start, 0.7, teleport_color, 0.35)
	Fx.ring(dest, 0.7, teleport_color, 0.35)


## 근접·미사일 공통: 커서 쪽으로 몸을 돌리고 잠깐 제자리에 선다.
func _begin_attack(dir: Vector3) -> void:
	rotation.y = _yaw_of(dir)
	_pause = attack_pause
	_has_target = false
	# 누르고 있던 좌클릭은 무시하고, 다음 좌클릭부터 다시 걷는다.
	_ignore_held_click = Input.is_action_pressed("move")


func _die() -> void:
	is_dead = true
	_blink = 0.0
	_body_mesh.visible = true
	_material.albedo_color = dead_color
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(_model, "rotation:z", PI * 0.5, 0.4)
	tween.tween_property(_model, "position:y", 0.45, 0.4)
	died.emit()


# --- 계산 도우미 ---

## 카메라에서 마우스 위치로 광선을 쏴 바닥 평면(y = 0)과 만나는 점. 없으면 null.
func _cursor_point() -> Variant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	return Plane(Vector3.UP, 0.0).intersects_ray(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))


func _aim_dir() -> Vector3:
	var point: Variant = _cursor_point()
	if point != null:
		var to: Vector3 = point - global_position
		to.y = 0.0
		if to.length() > 0.05:
			return to.normalized()
	return -global_basis.z


## WASD는 화면 기준(W = 화면 위, D = 화면 오른쪽)이라 카메라 방향으로 바꾼다.
func _screen_to_world(input_dir: Vector2) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var right := Vector3.RIGHT
	var up := Vector3.FORWARD
	if cam != null:
		right = Vector3(cam.global_basis.x.x, 0.0, cam.global_basis.x.z).normalized()
		up = Vector3(-cam.global_basis.z.x, 0.0, -cam.global_basis.z.z).normalized()
	return right * input_dir.x - up * input_dir.y


func _clamp_to_map(point: Vector3) -> Vector3:
	var limit := map_half_size - _radius() - stop_distance
	return Vector3(clampf(point.x, -limit, limit), 0.0, clampf(point.z, -limit, limit))


## 플레이어 몸(캡슐) 모양을 도착점에 놓아 나무·벽과 겹치는지 본다.
func _is_free_spot(dest: Vector3) -> bool:
	var limit := map_half_size - _radius()
	if absf(dest.x) > limit or absf(dest.z) > limit:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _shape.shape
	query.transform = Transform3D(Basis.IDENTITY, dest + _shape.position)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _radius() -> float:
	return (_shape.shape as CapsuleShape3D).radius


static func _yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)
