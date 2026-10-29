class_name Enemy
extends CharacterBody3D
## 적 3종 공통: 체력, 상태 머신(추적 → 예비 동작 → 공격 → 대기, 사망), 피격 깜빡임, 넉백, 머리 위 체력 바.
## 종류별 차이는 아래 _can_start_attack / _chase_velocity / _perform_attack 등을 덮어써서 만든다.

signal died(enemy: Enemy)

enum State { CHASE, WINDUP, ATTACK, COOLDOWN, DEAD }

const BAR_PIXELS := Vector2i(64, 8)

@export_group("기본")
@export var max_health := 30
@export var move_speed := 3.5
@export var body_radius := 0.35
@export var takes_knockback := true
@export var turn_speed := 10.0

@export_group("공격")
@export var attack_range := 1.2
@export var windup_time := 0.3
@export var attack_damage := 10
@export var attack_interval := 1.0

@export_group("연출")
@export var body_color := Color(0.85, 0.2, 0.2)
@export var windup_color := Color(1.0, 0.9, 0.25)
@export var flash_time := 0.1
@export var knockback_time := 0.12
@export var death_time := 0.3
@export var health_bar_height := 1.8
@export var health_bar_width := 0.8

static var _bar_texture: ImageTexture

var health := 0
var is_dead := false
var state := State.CHASE
var player: Player

var _timer := 0.0
var _flash := 0.0
var _knock := Vector3.ZERO
var _knock_left := 0.0
var _material: StandardMaterial3D
var _bar_back: Sprite3D
var _bar_front: Sprite3D

@onready var _model: Node3D = $Model
@onready var _body_mesh: MeshInstance3D = $Model/Body


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	player = get_tree().get_first_node_in_group("player") as Player
	_material = StandardMaterial3D.new()
	_material.albedo_color = body_color
	_body_mesh.material_override = _material
	_make_health_bar()


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_flash = maxf(_flash - delta, 0.0)
	var desired := Vector3.ZERO
	var player_ok := player != null and not player.is_dead

	if _knock_left > 0.0:
		_knock_left -= delta
		desired = _knock / knockback_time
	elif not player_ok:
		# 플레이어가 쓰러지면 공격을 멈추고 제자리에 선다.
		if state == State.WINDUP:
			_cancel_windup()
		state = State.CHASE
	else:
		match state:
			State.CHASE:
				if _can_start_attack():
					_start_windup()
				else:
					desired = _chase_velocity()
			State.WINDUP:
				_timer -= delta
				_windup_process(clampf(1.0 - _timer / windup_time, 0.0, 1.0))
				if _timer <= 0.0:
					state = State.ATTACK
					_end_windup_visuals()
					_perform_attack()
					state = State.COOLDOWN
					_timer = maxf(attack_interval - windup_time, 0.0)
			State.COOLDOWN:
				_timer -= delta
				desired = _chase_velocity()
				if _timer <= 0.0:
					state = State.CHASE

	Motion.slide(self, desired)
	if player_ok and _knock_left <= 0.0:
		var to := _to_player()
		if to.length() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-turn_speed * delta))
	_update_color()


func take_damage(amount: int, _from_position: Vector3) -> void:
	if is_dead:
		return
	health = maxi(health - amount, 0)
	_flash = flash_time
	_bar_back.visible = true
	_bar_front.visible = true
	_set_bar_ratio(float(health) / max_health)
	_update_color()
	if health <= 0:
		_die()


## 넉백으로 밀려나면 하던 예비 동작이 끊기고 추적으로 돌아간다.
func apply_knockback(offset: Vector3) -> void:
	if not takes_knockback or is_dead:
		return
	_knock = Vector3(offset.x, 0.0, offset.z)
	_knock_left = knockback_time
	if state == State.WINDUP:
		_cancel_windup()


static func bar_texture() -> ImageTexture:
	if _bar_texture == null:
		var img := Image.create(BAR_PIXELS.x, BAR_PIXELS.y, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_bar_texture = ImageTexture.create_from_image(img)
	return _bar_texture


# --- 종류별로 덮어쓰는 부분 ---

func _can_start_attack() -> bool:
	return _dist_to_player() <= attack_range


func _chase_velocity() -> Vector3:
	return _to_player().normalized() * move_speed


func _perform_attack() -> void:
	pass


func _on_windup_start() -> void:
	pass


## progress: 예비 동작 진행도 0 → 1
func _windup_process(_progress: float) -> void:
	pass


func _end_windup_visuals() -> void:
	pass


# --- 공통 도우미 ---

func _start_windup() -> void:
	state = State.WINDUP
	_timer = windup_time
	_on_windup_start()


func _cancel_windup() -> void:
	state = State.CHASE
	_end_windup_visuals()


func _to_player() -> Vector3:
	if player == null:
		return Vector3.ZERO
	var to := player.global_position - global_position
	to.y = 0.0
	return to


func _dist_to_player() -> float:
	return _to_player().length()


func _update_color() -> void:
	if _flash > 0.0:
		_material.albedo_color = Color.WHITE
	elif state == State.WINDUP:
		_material.albedo_color = windup_color
	else:
		_material.albedo_color = body_color


func _die() -> void:
	is_dead = true
	state = State.DEAD
	_end_windup_visuals()
	collision_layer = 0
	collision_mask = 0
	remove_from_group("enemies")
	_bar_back.visible = false
	_bar_front.visible = false
	died.emit(self)
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_model, "scale", _model.scale * 0.01, death_time)
	tween.tween_callback(queue_free)


## 빌보드 Sprite3D 두 장(공유 텍스처). 첫 피해를 입은 뒤부터 보인다.
func _make_health_bar() -> void:
	var pixel := health_bar_width / BAR_PIXELS.x
	_bar_back = _new_bar_sprite(Color(0.1, 0.1, 0.1, 0.85), 0, pixel)
	_bar_front = _new_bar_sprite(Color(0.95, 0.2, 0.2), 1, pixel)
	_bar_front.region_enabled = true
	_set_bar_ratio(1.0)


func _new_bar_sprite(color: Color, priority: int, pixel: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = bar_texture()
	sprite.modulate = color
	sprite.pixel_size = pixel
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.no_depth_test = true
	sprite.render_priority = priority
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.position = Vector3(0.0, health_bar_height, 0.0)
	sprite.visible = false
	add_child(sprite)
	return sprite


func _set_bar_ratio(ratio: float) -> void:
	var width := BAR_PIXELS.x * clampf(ratio, 0.0, 1.0)
	_bar_front.region_rect = Rect2(0, 0, maxf(width, 0.01), BAR_PIXELS.y)
	# 가운데 정렬이라 줄어든 만큼 왼쪽으로 밀어 왼쪽 끝을 맞춘다.
	_bar_front.offset = Vector2(-(BAR_PIXELS.x - width) * 0.5, 0.0)
