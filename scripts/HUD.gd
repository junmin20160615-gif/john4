extends CanvasLayer
## 화면 UI 전부를 코드로 만든다: 체력 바, 스킬 쿨다운 3칸, 웨이브 표시, 웨이브 안내, 피격 비네트, 결과 화면.
## 게임 상태는 신호로만 받는다. R 키 재시작도 여기서 처리한다.

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float intensity = 0.0;
void fragment() {
	float edge = smoothstep(0.3, 0.85, length(UV - vec2(0.5)) * 1.2);
	COLOR = vec4(0.9, 0.05, 0.05, edge * intensity);
}
"""
const SKILL_NAMES := ["근접", "미사일", "순간이동"]
const SKILL_KEYS := ["우클릭", "Q", "Space"]

@export var player_path: NodePath
@export var wave_manager_path: NodePath
@export var font_size := 20
@export var health_bar_size := Vector2(300, 30)
@export var skill_slot_size := 72.0
@export var banner_time := 1.5
@export var vignette_time := 0.2
@export var vignette_strength := 0.8
@export var victory_delay := 0.6
@export var defeat_delay := 1.0

var _root: Control
var _hp_fill: ColorRect
var _hp_label: Label
var _cd_overlays: Array[ColorRect] = []
var _cd_labels: Array[Label] = []
var _cd_left: Array[float] = [0.0, 0.0, 0.0]
var _wave_label: Label
var _banner: Label
var _banner_tween: Tween
var _vignette: ShaderMaterial
var _result: Control
var _result_title: Label
var _result_stats: Label
var _last_health := -1
var _finished := false

@onready var _player: Player = get_node(player_path)
@onready var _waves: WaveManager = get_node(wave_manager_path)


func _ready() -> void:
	_build_ui()
	_player.health_changed.connect(_on_health_changed)
	_player.cooldown_started.connect(_on_cooldown_started)
	_player.died.connect(_on_player_died)
	_waves.wave_started.connect(_on_wave_started)
	_waves.remaining_changed.connect(_on_remaining_changed)
	_waves.all_waves_cleared.connect(_on_all_waves_cleared)


func _process(delta: float) -> void:
	for i in _cd_left.size():
		_cd_left[i] = maxf(_cd_left[i] - delta, 0.0)
		_cd_overlays[i].visible = _cd_left[i] > 0.0
		_cd_labels[i].text = "%.1f" % _cd_left[i] if _cd_left[i] > 0.0 else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


# --- 신호 처리 ---

func _on_health_changed(current: int, maximum: int) -> void:
	_hp_fill.anchor_right = float(current) / maximum
	_hp_label.text = "%d / %d" % [current, maximum]
	if _last_health >= 0 and current < _last_health:
		_vignette.set_shader_parameter("intensity", vignette_strength)
		create_tween().tween_method(_set_vignette, vignette_strength, 0.0, vignette_time)
	_last_health = current


func _on_cooldown_started(slot: int, duration: float) -> void:
	_cd_left[slot] = duration


func _on_wave_started(number: int, total: int) -> void:
	_wave_label.text = "웨이브 %d / %d · 남은 적 %d" % [number, total, _waves.remaining]
	_banner.text = "웨이브 %d" % number
	_banner.visible = true
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_interval(banner_time)
	_banner_tween.tween_callback(_banner.hide)


func _on_remaining_changed(remaining: int) -> void:
	_wave_label.text = "웨이브 %d / %d · 남은 적 %d" % [_waves.current_wave, _waves.waves.size(), remaining]


func _on_all_waves_cleared() -> void:
	await get_tree().create_timer(victory_delay).timeout
	_show_result("승리!")


func _on_player_died() -> void:
	await get_tree().create_timer(defeat_delay).timeout
	_show_result("쓰러졌다…")


func _show_result(title: String) -> void:
	if _finished:
		return
	_finished = true
	_banner.hide()
	var seconds := int(_waves.elapsed)
	_result_title.text = title
	_result_stats.text = "처치 %d · 걸린 시간 %d:%02d" % [_waves.kills, seconds / 60, seconds % 60]
	_result.visible = true


func _set_vignette(value: float) -> void:
	_vignette.set_shader_parameter("intensity", value)


# --- UI 만들기 ---

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)

	# 피격 비네트(맨 아래에 깔아 다른 UI를 가리지 않게 한다)
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette = ShaderMaterial.new()
	_vignette.shader = shader
	vignette.material = _vignette
	_root.add_child(vignette)

	# 체력 바: 왼쪽 아래
	var hp_back := _rect(Color(0.1, 0.1, 0.1, 0.8))
	_root.add_child(hp_back)
	_place(hp_back, Vector2(0, 1), Rect2(24, -24 - health_bar_size.y, health_bar_size.x, health_bar_size.y))
	_hp_fill = _rect(Color(0.85, 0.15, 0.15))
	_hp_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_back.add_child(_hp_fill)
	_hp_label = _label("100 / 100", HORIZONTAL_ALIGNMENT_CENTER)
	_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_back.add_child(_hp_label)

	# 스킬 슬롯 3칸: 아래 가운데
	var gap := 12.0
	var total := skill_slot_size * 3 + gap * 2
	for i in 3:
		var slot := _rect(Color(0.15, 0.2, 0.35, 0.9))
		var x := -total * 0.5 + i * (skill_slot_size + gap)
		_root.add_child(slot)
		_place(slot, Vector2(0.5, 1), Rect2(x, -24 - skill_slot_size, skill_slot_size, skill_slot_size))
		var name_label := _label(SKILL_NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, 16)
		_place(name_label, Vector2(0, 0), Rect2(0, 8, skill_slot_size, 24))
		slot.add_child(name_label)
		var key_label := _label(SKILL_KEYS[i], HORIZONTAL_ALIGNMENT_CENTER, 14)
		key_label.modulate = Color(0.8, 0.85, 1.0)
		_place(key_label, Vector2(0, 0), Rect2(0, skill_slot_size - 28, skill_slot_size, 22))
		slot.add_child(key_label)
		var overlay := _rect(Color(0, 0, 0, 0.6))
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.visible = false
		slot.add_child(overlay)
		var cd_label := _label("", HORIZONTAL_ALIGNMENT_CENTER, 24)
		cd_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(cd_label)
		_cd_overlays.append(overlay)
		_cd_labels.append(cd_label)

	# 웨이브 표시: 위 가운데
	_wave_label = _label("준비…", HORIZONTAL_ALIGNMENT_CENTER, 22)
	_root.add_child(_wave_label)
	_place(_wave_label, Vector2(0.5, 0), Rect2(-300, 16, 600, 36))

	# 웨이브 안내: 화면 가운데
	_banner = _label("", HORIZONTAL_ALIGNMENT_CENTER, 48)
	_root.add_child(_banner)
	_place(_banner, Vector2(0.5, 0.5), Rect2(-300, -150, 600, 80))
	_banner.visible = false

	# 결과 화면
	_result = _rect(Color(0, 0, 0, 0.65))
	_root.add_child(_result)
	_place(_result, Vector2(0.5, 0.5), Rect2(-260, -130, 520, 260))
	_result.visible = false
	_result_title = _label("", HORIZONTAL_ALIGNMENT_CENTER, 52)
	_place(_result_title, Vector2(0, 0), Rect2(0, 28, 520, 70))
	_result.add_child(_result_title)
	_result_stats = _label("", HORIZONTAL_ALIGNMENT_CENTER, 22)
	_place(_result_stats, Vector2(0, 0), Rect2(0, 118, 520, 36))
	_result.add_child(_result_stats)
	var hint := _label("R 키로 다시 시작", HORIZONTAL_ALIGNMENT_CENTER, 20)
	hint.modulate = Color(0.85, 0.85, 0.85)
	_place(hint, Vector2(0, 0), Rect2(0, 190, 520, 32))
	_result.add_child(hint)


func _make_theme() -> Theme:
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans CJK KR", "Noto Sans KR", "sans-serif"])
	theme.default_font = font
	theme.default_font_size = font_size
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.9))
	theme.set_constant("outline_size", "Label", 4)
	return theme


func _rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _label(text: String, align: HorizontalAlignment, size := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if size > 0:
		label.add_theme_font_size_override("font_size", size)
	return label


## anchor 한 점을 기준으로 rect(왼쪽 위 위치, 크기)만큼 놓는다.
func _place(control: Control, anchor: Vector2, rect: Rect2) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y
