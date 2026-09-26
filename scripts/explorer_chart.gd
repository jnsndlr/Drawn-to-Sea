extends Node3D

const MENU_SCENE := "res://scenes/main_menu.tscn"
const CHART_SIZE := Vector2(20.0, 13.5)
const PITCH_DEGREES := 52.0
const MIN_PITCH := 20.0
const MAX_PITCH := 89.0
const ORBIT_SENSITIVITY := 0.3
const CAMERA_DISTANCE := 30.0
const DEFAULT_ZOOM := 12.6
const MIN_ZOOM := 2.5
const MAX_ZOOM := 16.0
const GROUND := Plane(Vector3.UP, 0.0)
# Static layers are rendered once at startup (see explorer_static_bake.gdshader).
const LAND_BAKE_SIZE := Vector2i(512, 346)
const GEOMETRY_BAKE_SIZE := Vector2i(2048, 1382)
const COAST_BAKE_SIZE := Vector2i(1024, 692)
const PAINT_BAKE_SIZE := Vector2i(3072, 2074)
const NOISE_BAKE_SIZE := Vector2i(512, 512)
# 8 x 4 plant variants, 256 px each (see flora_atlas_bake.gdshader).
const PLANT_ATLAS_SIZE := Vector2i(2048, 1024)
# Typical plant width in chart units, for keeping atlas ink at on-screen weight.
const TYPICAL_PLANT_SIZE := 0.5

# name, shader parameter, min, max, step, default
const CONDITIONS := [
	["Wave height", "wave_height", 0.0, 6.0, 0.05, 1.0],
	["Wave length", "wave_length", 0.3, 3.0, 0.05, 0.6],
	["Wave speed", "wave_speed", 0.0, 4.0, 0.05, 1.0],
	["Chop", "chop", 0.0, 3.0, 0.05, 0.25],
	["Noise", "noise_amount", 0.0, 3.0, 0.05, 0.8],
	["Wind direction", "wind_angle", -180.0, 180.0, 1.0, 0.0],
]

var material := ShaderMaterial.new()
var camera := Camera3D.new()
var focus := Vector3.ZERO
var wave_clock := 0.0
var wave_speed := 1.0
var dragging := false
var orbiting := false
var yaw := 0.0
var pitch := PITCH_DEGREES
var sliders := {}

func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = CHART_SIZE
	plane.subdivide_width = 480
	plane.subdivide_depth = 324
	material.shader = load("res://shaders/explorer_chart.gdshader")
	material.set_shader_parameter("chart_size", CHART_SIZE)
	var chart := MeshInstance3D.new()
	chart.mesh = plane
	chart.material_override = material
	# The shader raises cliffs and swells well above the flat plane's bounds.
	chart.extra_cull_margin = 2.0
	# Hidden until its baked textures exist.
	chart.visible = false
	add_child(chart)

	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(camera)
	camera.make_current()
	reset_view()

	var layer := CanvasLayer.new()
	add_child(layer)
	var hint := Label.new()
	hint.text = "Drag to pan · Right-drag to rotate · Scroll / pinch to zoom · R to reset view · Esc for menu"
	hint.add_theme_color_override("font_color", Color("b49355"))
	hint.position = Vector2(20, 16)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hint)
	build_controls(layer)

	var images := await bake_static_layers()
	material.set_shader_parameter("geometry_tex", ImageTexture.create_from_image(images.geometry))
	material.set_shader_parameter("coast_tex", ImageTexture.create_from_image(images.coast))
	images.paint.generate_mipmaps()
	material.set_shader_parameter("paint_tex", ImageTexture.create_from_image(images.paint))
	material.set_shader_parameter("stroke_noise", ImageTexture.create_from_image(images.stroke_noise))
	material.set_shader_parameter("keep_noise", ImageTexture.create_from_image(images.keep_noise))
	chart.visible = true
	var flora := preload("res://scripts/chart_flora.gd").new()
	add_child(flora)
	images.plant_atlas.generate_mipmaps()
	flora.build(images.land, CHART_SIZE, ImageTexture.create_from_image(images.plant_atlas))

func _process(delta: float) -> void:
	wave_clock += delta * wave_speed
	material.set_shader_parameter("wave_clock", wave_clock)

# Renders everything static on the chart once, all in the same frame, and
# returns the images by name. The chart shader then only animates the sea.
func bake_static_layers() -> Dictionary:
	var chart_params := {"chart_size": CHART_SIZE}
	var static_bake := "res://shaders/explorer_static_bake.gdshader"
	var noise_bake := "res://shaders/explorer_noise_bake.gdshader"
	# Baked ink keeps its on-screen weight at the default zoom.
	var screen_px_per_unit := get_viewport().get_visible_rect().size.y / DEFAULT_ZOOM
	var paint_line_scale := (PAINT_BAKE_SIZE.x / CHART_SIZE.x) / screen_px_per_unit
	var viewports := {
		"land": start_bake("res://shaders/explorer_land_bake.gdshader", LAND_BAKE_SIZE, false, chart_params),
		"geometry": start_bake(static_bake, GEOMETRY_BAKE_SIZE, true, {"chart_size": CHART_SIZE, "layer": 0}),
		"coast": start_bake(static_bake, COAST_BAKE_SIZE, false, {"chart_size": CHART_SIZE, "layer": 1}),
		"paint": start_bake(static_bake, PAINT_BAKE_SIZE, false,
			{"chart_size": CHART_SIZE, "layer": 2, "line_scale": paint_line_scale}),
		"stroke_noise": start_bake(noise_bake, NOISE_BAKE_SIZE, true, {"layer": 0}),
		"keep_noise": start_bake(noise_bake, NOISE_BAKE_SIZE, true, {"layer": 1}),
		"plant_atlas": start_bake("res://shaders/flora_atlas_bake.gdshader", PLANT_ATLAS_SIZE, false,
			{"line_scale": (PLANT_ATLAS_SIZE.x / 8.0) / (TYPICAL_PLANT_SIZE * screen_px_per_unit)}),
	}
	await RenderingServer.frame_post_draw
	var images := {}
	for key in viewports:
		images[key] = viewports[key].get_texture().get_image()
		viewports[key].queue_free()
	return images

# Draws one full-screen shader pass into an offscreen viewport. hdr keeps raw
# half-float values (distances can be negative); otherwise it is 8-bit.
func start_bake(shader_path: String, size: Vector2i, hdr: bool, params: Dictionary) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.use_hdr_2d = hdr
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var bake := ShaderMaterial.new()
	bake.shader = load(shader_path)
	for key in params:
		bake.set_shader_parameter(key, params[key])
	var canvas := ColorRect.new()
	canvas.size = Vector2(size)
	canvas.material = bake
	viewport.add_child(canvas)
	add_child(viewport)
	return viewport

# ------------------------------------------------------------------ camera --

func reset_view() -> void:
	focus = Vector3.ZERO
	camera.size = DEFAULT_ZOOM
	yaw = 0.0
	pitch = PITCH_DEGREES
	update_camera()

func update_camera() -> void:
	var half := Vector3(CHART_SIZE.x, 0.0, CHART_SIZE.y) * 0.5
	focus = focus.clamp(-half, half)
	var tilt := deg_to_rad(pitch)
	var offset := Vector3(0.0, sin(tilt), cos(tilt)).rotated(Vector3.UP, deg_to_rad(yaw))
	camera.look_at_from_position(focus + offset * CAMERA_DISTANCE, focus, Vector3.UP)

func ground_point(screen: Vector2) -> Variant:
	return GROUND.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))

# Zoom while keeping the chart point under the cursor fixed.
func zoom_at(screen: Vector2, factor: float) -> void:
	var before = ground_point(screen)
	camera.size = clampf(camera.size * factor, MIN_ZOOM, MAX_ZOOM)
	var after = ground_point(screen)
	if before != null and after != null:
		focus += before - after
	update_camera()

func pan_by(from: Vector2, to: Vector2) -> void:
	var a = ground_point(from)
	var b = ground_point(to)
	if a != null and b != null:
		focus += a - b
		update_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file(MENU_SCENE)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_R:
		reset_view()
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
				dragging = event.pressed
			MOUSE_BUTTON_RIGHT:
				orbiting = event.pressed
			MOUSE_BUTTON_WHEEL_UP:
				# factor carries the precise delta from smooth-scrolling devices.
				zoom_at(event.position, pow(0.9, maxf(event.factor, 0.1)))
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_at(event.position, pow(1.0 / 0.9, maxf(event.factor, 0.1)))
	elif event is InputEventMouseMotion and orbiting and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		# Orbit around the focus point: horizontal spins, vertical tilts.
		yaw -= event.relative.x * ORBIT_SENSITIVITY
		pitch = clampf(pitch + event.relative.y * ORBIT_SENSITIVITY, MIN_PITCH, MAX_PITCH)
		update_camera()
	elif event is InputEventMouseMotion and dragging and event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MIDDLE):
		pan_by(event.position - event.relative, event.position)
	elif event is InputEventPanGesture:
		# macOS trackpad two-finger scroll arrives as a pan gesture, not a wheel.
		zoom_at(get_viewport().get_mouse_position(), exp(event.delta.y * 0.04))
	elif event is InputEventMagnifyGesture:
		zoom_at(event.position, 1.0 / event.factor)

# ---------------------------------------------------------------- controls --

func build_controls(layer: CanvasLayer) -> void:
	var toggle := Button.new()
	toggle.text = "Sea conditions"
	toggle.toggle_mode = true
	toggle.button_pressed = true
	toggle.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	toggle.offset_left = -196
	toggle.offset_right = -20
	toggle.offset_top = 16
	toggle.offset_bottom = 48
	layer.add_child(toggle)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.12, 0.085, 0.88)
	style.border_color = Color("655035")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -276
	panel.offset_right = -20
	panel.offset_top = 56
	layer.add_child(panel)
	toggle.toggled.connect(func(on: bool) -> void: panel.visible = on)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	for spec in CONDITIONS:
		add_slider(column, spec)

	var reset := Button.new()
	reset.text = "Reset conditions"
	reset.pressed.connect(func() -> void:
		for spec in CONDITIONS:
			sliders[spec[1]].value = spec[5])
	column.add_child(reset)

func add_slider(column: VBoxContainer, spec: Array) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = spec[0]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color("e3cda1"))
	var readout := Label.new()
	readout.add_theme_color_override("font_color", Color("b49355"))
	row.add_child(label)
	row.add_child(readout)
	column.add_child(row)

	var slider := HSlider.new()
	slider.min_value = spec[2]
	slider.max_value = spec[3]
	slider.step = spec[4]
	slider.custom_minimum_size = Vector2(228, 18)
	column.add_child(slider)
	sliders[spec[1]] = slider
	slider.value_changed.connect(func(value: float) -> void:
		readout.text = ("%d°" % value) if spec[1] == "wind_angle" else ("%.2f" % value)
		set_condition(spec[1], value))
	slider.value = spec[5]
	set_condition(spec[1], spec[5])
	readout.text = ("%d°" % spec[5]) if spec[1] == "wind_angle" else ("%.2f" % spec[5])

func set_condition(parameter: String, value: float) -> void:
	match parameter:
		"wave_speed":
			wave_speed = value
		"wind_angle":
			material.set_shader_parameter(parameter, deg_to_rad(value))
		_:
			material.set_shader_parameter(parameter, value)
