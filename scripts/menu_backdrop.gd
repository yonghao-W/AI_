class_name MenuBackdrop
extends Control
## 主菜单独立背景资源层。只负责 E-07 场景图、压暗、暖光、浮尘与鼠标视差。
## 不包含任何菜单文字；替换 TEXTURE_PATH 即可换成未来 Blender CG 输出。

const TEXTURE_PATH := "res://assets/ui/menu/e07_observation_exterior.webp"

var _photo: TextureRect
var _photo_material: ShaderMaterial
var _warm: TextureRect
var _dust: GPUParticles2D
var _scrim_left: TextureRect
var _scrim_bottom: TextureRect
var _vignette: ColorRect
var _contrast_layer: ColorRect
var _parallax := Vector2.ZERO
var _target_parallax := Vector2.ZERO
var _time := 0.0
var _warm_base := 0.72
var _reduced := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_build()
	_reduced = DeadCityUI.reduced_motion()
	_apply_motion_state()


func _build() -> void:
	var base := ColorRect.new()
	base.color = Color("#0a0b0c")
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(base)

	_photo = TextureRect.new()
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_photo.texture = load(TEXTURE_PATH) if ResourceLoader.exists(TEXTURE_PATH) else null
	_photo_material = ShaderMaterial.new()
	_photo_material.shader = _parallax_shader()
	_photo.material = _photo_material
	add_child(_photo)

	if _photo.texture == null:
		var missing := DeadCityUI.make_label("E-07 背景资源缺失", 13, DeadCityUI.MUTED_2)
		missing.position = Vector2(48, 48)
		add_child(missing)

	var beam := GradientTexture2D.new()
	var beam_gradient := Gradient.new()
	beam_gradient.set_color(0, Color(1.0, 0.82, 0.58, 0.20))
	beam_gradient.set_color(1, Color(1.0, 0.82, 0.58, 0.0))
	beam.gradient = beam_gradient
	beam.fill = GradientTexture2D.FILL_RADIAL
	beam.fill_from = Vector2(0.5, 0.5)
	beam.fill_to = Vector2(1.0, 1.0)
	beam.width = 512
	beam.height = 512
	_warm = TextureRect.new()
	_warm.texture = beam
	_warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_warm.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_warm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_warm.anchor_left = 0.36
	_warm.anchor_right = 0.96
	_warm.anchor_top = -0.05
	_warm.anchor_bottom = 0.92
	_warm.modulate = Color(1, 1, 1, _warm_base)
	add_child(_warm)

	_dust = GPUParticles2D.new()
	_dust.amount = 36
	_dust.lifetime = 12.0
	_dust.preprocess = 4.0
	_dust.local_coords = false
	_dust.visibility_rect = Rect2(-720, -480, 1440, 960)
	_dust.texture = _mote_texture()
	var canvas_material := CanvasItemMaterial.new()
	canvas_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_dust.material = canvas_material
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(260, 180, 1)
	process.direction = Vector3(0, -1, 0)
	process.spread = 32.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 7.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.18
	process.scale_max = 0.52
	process.color = Color(1.0, 0.87, 0.68, 0.30)
	_dust.process_material = process
	add_child(_dust)

	_scrim_left = TextureRect.new()
	_scrim_left.texture = _left_scrim()
	_scrim_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim_left.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrim_left.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim_left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scrim_left)

	_scrim_bottom = TextureRect.new()
	_scrim_bottom.texture = _bottom_scrim()
	_scrim_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scrim_bottom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_scrim_bottom.stretch_mode = TextureRect.STRETCH_SCALE
	_scrim_bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scrim_bottom)

	_vignette = ColorRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = _vignette_shader()
	_vignette.material = vignette_material
	add_child(_vignette)

	_contrast_layer = ColorRect.new()
	_contrast_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_contrast_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_contrast_layer.color = Color(0.01, 0.012, 0.013, 0.17)
	_contrast_layer.visible = false
	add_child(_contrast_layer)

	resized.connect(_on_resized)
	_on_resized()
	visibility_changed.connect(_apply_motion_state)


func _left_scrim() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.31, 0.35, 0.40, 0.46, 0.56, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.02, 0.022, 0.024, 0.998),
		Color(0.02, 0.022, 0.024, 0.992),
		Color(0.02, 0.022, 0.024, 0.958),
		Color(0.02, 0.022, 0.024, 0.78),
		Color(0.02, 0.022, 0.024, 0.38),
		Color(0.02, 0.022, 0.024, 0.10),
		Color(0.02, 0.022, 0.024, 0.0),
		Color(0.02, 0.022, 0.024, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	texture.width = 1024
	texture.height = 8
	return texture


func _bottom_scrim() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.14, 0.32, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.02, 0.022, 0.024, 0.82),
		Color(0.02, 0.022, 0.024, 0.38),
		Color(0.02, 0.022, 0.024, 0.0),
		Color(0.02, 0.022, 0.024, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_LINEAR
	texture.fill_from = Vector2(0.5, 1)
	texture.fill_to = Vector2(0.5, 0)
	texture.width = 8
	texture.height = 512
	return texture


func _mote_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 0.93, 0.78, 1))
	gradient.set_color(1, Color(1, 0.93, 0.78, 0))
	gradient.add_point(0.35, Color(1, 0.93, 0.78, 0.55))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	return texture


func _parallax_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec2 parallax = vec2(0.0);
uniform float zoom = 1.045;
void fragment() {
	vec2 uv = (UV - vec2(0.5)) / zoom + vec2(0.5) + parallax;
	COLOR = texture(TEXTURE, clamp(uv, vec2(0.0005), vec2(0.9995))) * COLOR;
}
"""
	return shader


func _vignette_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float strength = 0.52;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.12, 1.0);
	float d = length(p);
	float a = smoothstep(0.34, 0.82, d) * strength;
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
"""
	return shader


func _on_resized() -> void:
	if _dust == null:
		return
	var extent := size * Vector2(0.34, 0.40)
	_dust.position = size * Vector2(0.62, 0.44)
	var process := _dust.process_material as ParticleProcessMaterial
	if process != null:
		process.emission_box_extents = Vector3(maxf(80.0, extent.x), maxf(80.0, extent.y), 1.0)
	_dust.visibility_rect = Rect2(-size.x * 0.6, -size.y * 0.6, size.x * 2.0, size.y * 2.0)


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _reduced:
		return
	var viewport_size := size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		var mouse := get_local_mouse_position() / viewport_size
		_target_parallax = (mouse - Vector2(0.5, 0.5)) * Vector2(-0.010, -0.006)
	_parallax = _parallax.lerp(_target_parallax, minf(1.0, delta * 3.2))
	if _photo_material != null:
		_photo_material.set_shader_parameter("parallax", _parallax * 0.42)
	if _warm != null:
		_warm.modulate.a = _warm_base + sin(_time * 0.42) * 0.06
		_warm.position = _parallax * 220.0


func set_reduced_motion(value: bool) -> void:
	_reduced = value
	_apply_motion_state()


func set_high_contrast(value: bool) -> void:
	if _scrim_left == null:
		return
	_scrim_left.modulate = Color(1.0, 1.0, 1.0, 1.22 if value else 1.0)
	if _contrast_layer != null:
		_contrast_layer.visible = value


func _apply_motion_state() -> void:
	if _dust == null:
		return
	_dust.emitting = visible and not _reduced
	if _reduced:
		_parallax = Vector2.ZERO
		_target_parallax = Vector2.ZERO
		if _photo_material != null:
			_photo_material.set_shader_parameter("parallax", Vector2.ZERO)
		if _warm != null:
			_warm.modulate.a = _warm_base
			_warm.position = Vector2.ZERO
