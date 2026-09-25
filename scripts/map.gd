extends Node3D

var material := ShaderMaterial.new()
var camera := Camera3D.new()
var azimuth := 0.0
var elevation := 0.95
var clock := 0.0
var animation_speed := 0.22
var wave_controls: PanelContainer
var paused := false
var geography = preload("res://scripts/geography.gd").new()
var sailing: Node3D
var shake_remaining := 0.0
var focus := Vector3.ZERO
const MAP_PLANE := Plane(Vector3.UP, 0.0)

func _ready() -> void:
	material.shader = load("res://shaders/parchment.gdshader")
	material.set_shader_parameter("geography_map", geography.texture)
	var plane := PlaneMesh.new()
	plane.size = Vector2(18, 12)
	plane.subdivide_width = 360
	plane.subdivide_depth = 240
	var sea := MeshInstance3D.new()
	sea.mesh = plane
	sea.material_override = material
	# Include shader-displaced cliffs in visibility bounds.
	sea.extra_cull_margin = 3.0
	add_child(sea)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 21.0
	add_child(camera)
	camera.make_current()
	update_camera()
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "DRAWN TO SEA  /  CARD SAILING\nDrag to pan · Right-drag to orbit · Scroll / pinch to zoom · Space to pause · R to reset"
	label.position = Vector2(28, 24)
	label.add_theme_color_override("font_color", Color("e3cda1"))
	layer.add_child(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_controls = preload("res://scripts/wave_controls.gd").new()
	layer.add_child(wave_controls)
	wave_controls.setup(set_water_setting)
	var toggle := Button.new()
	toggle.text = "Water controls"
	toggle.toggle_mode = true
	toggle.button_pressed = false
	wave_controls.hide()
	layer.add_child(toggle)
	toggle.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toggle.offset_left = -160
	toggle.offset_right = -20
	toggle.offset_top = 24
	toggle.offset_bottom = 60
	sailing = preload("res://scripts/sailing.gd").new()
	add_child(sailing)
	sailing.setup(self, layer)
	toggle.toggled.connect(func(visible_panel: bool) -> void: wave_controls.visible = visible_panel)

func set_water_setting(parameter: String, value: float) -> void:
	if parameter == "wave_speed":
		# Integrate speed so adjusting the slider never jumps the animation phase.
		animation_speed = value
		material.set_shader_parameter("wave_speed", 1.0)
	else:
		material.set_shader_parameter(parameter, value)

func _process(delta: float) -> void:
	if not paused:
		clock += delta * animation_speed
	material.set_shader_parameter("wave_time", clock)
	shake_remaining = maxf(0.0, shake_remaining - delta)
	camera.h_offset = sin(shake_remaining * 95.0) * shake_remaining * 0.17
	camera.v_offset = cos(shake_remaining * 73.0) * shake_remaining * 0.12

func update_camera() -> void:
	camera.position = focus + Vector3(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)) * 24.0
	camera.look_at(focus)

# Ray/plane intersections keep panning and zoom anchored to the cursor at any angle.
func map_point(screen_position: Vector2) -> Variant:
	return MAP_PLANE.intersects_ray(camera.project_ray_origin(screen_position), camera.project_ray_normal(screen_position))

func zoom_at(screen_position: Vector2, multiplier: float) -> void:
	var before: Variant = map_point(screen_position)
	camera.size = clampf(camera.size * multiplier, 4.0, 32.0)
	var after: Variant = map_point(screen_position)
	if before != null and after != null:
		focus += before - after
	update_camera()

func _unhandled_input(event: InputEvent) -> void:
	# macOS trackpads deliver continuous pan gestures, not only wheel buttons.
	if event is InputEventPanGesture:
		zoom_at(event.position, exp(clampf(event.delta.y * 0.08, -0.4, 0.4)))
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMagnifyGesture:
		if event.factor > 0.0:
			zoom_at(event.position, 1.0 / event.factor)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			azimuth -= event.relative.x * 0.005
			elevation = clampf(elevation + event.relative.y * 0.005, 0.35, 1.5)
			update_camera()
		elif event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE):
			var previous: Variant = map_point(event.position - event.relative)
			var current: Variant = map_point(event.position)
			if previous != null and current != null:
				focus += previous - current
				update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_at(event.position, pow(0.9, event.factor))
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_at(event.position, pow(1.0 / 0.9, event.factor))
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			paused = not paused
		if event.keycode == KEY_R:
			focus = Vector3.ZERO
			azimuth = 0.0
			elevation = 0.95
			camera.size = 21.0
			clock = 0.0
			update_camera()
