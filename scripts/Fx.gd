class_name Fx
## 짧은 이펙트 모음(클릭 원, 부채꼴, 퍼지는 구, 바닥 원).
## 메시·머티리얼은 한 번만 만들어 재사용한다. 이펙트마다 새로 만들면 그 프레임이 멈춰 화면이 흔들려 보이기 때문이다.
## 사라지는 효과는 투명도를 ALPHA_STEPS 단계로 나눈 공유 머티리얼을 갈아 끼워서 준다.
## (GeometryInstance3D.transparency는 이 프로젝트의 Compatibility 렌더러에서 적용되지 않았다.)

const ALPHA_STEPS := 10

static var _materials := {}
static var _fan_meshes := {}
static var _ring_mesh: TorusMesh
static var _disc_mesh: CylinderMesh
static var _ball_mesh: SphereMesh


static func material(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var step := clampi(roundi(alpha * ALPHA_STEPS), 0, ALPHA_STEPS)
	var key := "%s/%d" % [color.to_html(false), step]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(color, float(step) / ALPHA_STEPS)
		_materials[key] = m
	return _materials[key]


static func ring(pos: Vector3, radius: float, color: Color, duration := 0.3) -> void:
	var mi := _spawn(_get_ring_mesh(), color, pos + Vector3.UP * 0.05, Vector3(radius, 0.4, radius), 0.8)
	_fade(mi, color, 0.8, duration, Vector3(radius * 1.3, 0.4, radius * 1.3))


static func fan(pos: Vector3, yaw: float, reach: float, angle_deg: float, color: Color, duration := 0.1) -> void:
	var mi := _spawn(_get_fan_mesh(angle_deg), color, pos + Vector3.UP * 0.1, Vector3(reach, 1.0, reach), 0.5)
	mi.rotation.y = yaw
	_fade(mi, color, 0.5, duration, mi.scale)


static func burst(pos: Vector3, color: Color, duration := 0.2) -> void:
	var mi := _spawn(_get_ball_mesh(), color, pos, Vector3.ONE * 0.12, 0.8)
	_fade(mi, color, 0.8, duration, Vector3.ONE * 0.5)


## 사라지지 않는 바닥 원. 쓰는 쪽이 직접 지운다(덩치의 경고 원).
static func disc(pos: Vector3, radius: float, color: Color, alpha: float) -> MeshInstance3D:
	return _spawn(_get_disc_mesh(), color, pos, Vector3(radius, 1.0, radius), alpha)


## 미사일·화살 같은 투사체를 Main의 Projectiles 노드 아래에 넣는다.
static func add_projectile(node: Node) -> void:
	var root := _root()
	var parent := root.get_node_or_null("Projectiles")
	(parent if parent != null else root).add_child(node)


## 처음 그릴 때의 셰이더 컴파일 멈춤을 없애려고, 시작할 때 바닥 밑 안 보이는 곳에 한 번씩 그린다.
static func prewarm(colors: Array[Color]) -> void:
	var hidden := Vector3(0, -2, 0)
	for color in colors:
		for mesh in [_get_ring_mesh(), _get_fan_mesh(90.0), _get_disc_mesh(), _get_ball_mesh()]:
			_fade(_spawn(mesh, color, hidden, Vector3.ONE, 0.5), color, 0.5, 0.1, Vector3.ONE)


static func _spawn(mesh: Mesh, color: Color, pos: Vector3, scale: Vector3, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material(color, alpha)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mi.position = pos
	mi.scale = scale
	_root().add_child(mi)
	return mi


static func _fade(mi: MeshInstance3D, color: Color, start_alpha: float, duration: float, end_scale: Vector3) -> void:
	var tween := mi.create_tween().set_parallel()
	tween.tween_method(func(a: float) -> void: mi.material_override = material(color, a), start_alpha, 0.0, duration)
	tween.tween_property(mi, "scale", end_scale, duration)
	tween.chain().tween_callback(mi.queue_free)


static func _root() -> Node:
	return (Engine.get_main_loop() as SceneTree).current_scene


static func _get_ring_mesh() -> Mesh:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.82
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 32
		_ring_mesh.ring_segments = 8
	return _ring_mesh


static func _get_disc_mesh() -> Mesh:
	if _disc_mesh == null:
		_disc_mesh = CylinderMesh.new()
		_disc_mesh.top_radius = 1.0
		_disc_mesh.bottom_radius = 1.0
		_disc_mesh.height = 0.02
		_disc_mesh.radial_segments = 48
		_disc_mesh.rings = 1
	return _disc_mesh


static func _get_ball_mesh() -> Mesh:
	if _ball_mesh == null:
		_ball_mesh = SphereMesh.new()
		_ball_mesh.radial_segments = 16
		_ball_mesh.rings = 8
	return _ball_mesh


## 반지름 1, -Z 방향을 가운데로 하는 부채꼴. 각도별로 한 번만 만든다.
static func _get_fan_mesh(angle_deg: float) -> Mesh:
	var key := roundi(angle_deg)
	if not _fan_meshes.has(key):
		var half := deg_to_rad(angle_deg) * 0.5
		var steps := 16
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in steps:
			var a0 := -half + 2.0 * half * i / steps
			var a1 := -half + 2.0 * half * (i + 1) / steps
			st.add_vertex(Vector3.ZERO)
			st.add_vertex(Vector3(sin(a0), 0.0, -cos(a0)))
			st.add_vertex(Vector3(sin(a1), 0.0, -cos(a1)))
		_fan_meshes[key] = st.commit()
	return _fan_meshes[key]
