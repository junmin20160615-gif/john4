class_name WaveManager
extends Node
## 웨이브 진행: 구성표대로 스폰 지점에서 적을 하나씩 내보내고, 전멸하면 쉬었다가 다음 웨이브를 연다.

signal wave_started(number: int, total: int)
signal remaining_changed(remaining: int)
signal all_waves_cleared

## 웨이브마다 (근거리, 원거리, 덩치) 마릿수
@export var waves: Array[Vector3i] = [Vector3i(6, 0, 0), Vector3i(6, 3, 0), Vector3i(6, 4, 2)]
@export var melee_scene: PackedScene
@export var ranged_scene: PackedScene
@export var brute_scene: PackedScene
@export var spawn_points_path: NodePath
@export var enemies_path: NodePath
@export var player_path: NodePath
@export var start_delay := 1.0
@export var spawn_interval := 0.5
@export var rest_time := 3.0
@export var min_spawn_distance := 10.0
@export var spawn_jitter := 0.6

signal _enemy_killed

var kills := 0
var elapsed := 0.0
var current_wave := 0
var remaining := 0

var _running := true

@onready var _spawn_points: Node3D = get_node(spawn_points_path)
@onready var _enemies: Node3D = get_node(enemies_path)
@onready var _player: Player = get_node(player_path)


func _ready() -> void:
	_player.died.connect(_on_player_died)
	_run()


func _physics_process(delta: float) -> void:
	if _running:
		elapsed += delta


func _run() -> void:
	await _wait(start_delay)
	for i in waves.size():
		if not _running:
			return
		current_wave = i + 1
		var queue := _build_queue(waves[i])
		remaining = queue.size()
		wave_started.emit(current_wave, waves.size())
		remaining_changed.emit(remaining)
		for scene in queue:
			if not _running:
				return
			_spawn(scene)
			await _wait(spawn_interval)
		while remaining > 0:
			await _enemy_killed
			if not _running:
				return
		if i < waves.size() - 1:
			await _wait(rest_time)
	_running = false
	all_waves_cleared.emit()


## 종류를 섞어서 내보낸다.
func _build_queue(counts: Vector3i) -> Array[PackedScene]:
	var queue: Array[PackedScene] = []
	for n in counts.x:
		queue.append(melee_scene)
	for n in counts.y:
		queue.append(ranged_scene)
	for n in counts.z:
		queue.append(brute_scene)
	queue.shuffle()
	return queue


func _spawn(scene: PackedScene) -> void:
	var enemy := scene.instantiate() as Enemy
	var jitter := Vector3(randf_range(-spawn_jitter, spawn_jitter), 0.0, randf_range(-spawn_jitter, spawn_jitter))
	enemy.position = _pick_spawn_point() + jitter
	enemy.died.connect(_on_enemy_died)
	_enemies.add_child(enemy)


## 플레이어와 min_spawn_distance 이상 떨어진 지점 중 무작위. 없으면 가장 먼 곳.
func _pick_spawn_point() -> Vector3:
	var candidates: Array[Vector3] = []
	var farthest := Vector3.ZERO
	var farthest_dist := -1.0
	for marker in _spawn_points.get_children():
		var pos: Vector3 = (marker as Node3D).global_position
		var dist := Vector2(pos.x - _player.global_position.x, pos.z - _player.global_position.z).length()
		if dist >= min_spawn_distance:
			candidates.append(pos)
		if dist > farthest_dist:
			farthest_dist = dist
			farthest = pos
	if candidates.is_empty():
		return farthest
	return candidates.pick_random()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false, true).timeout


func _on_enemy_died(_enemy: Enemy) -> void:
	kills += 1
	remaining -= 1
	remaining_changed.emit(remaining)
	_enemy_killed.emit()


func _on_player_died() -> void:
	_running = false
	_enemy_killed.emit()
