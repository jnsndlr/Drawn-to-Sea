extends PanelContainer

const SETTINGS := [
	["wave_speed", "Motion speed", 0.0, 1.0, 0.01, 0.22],
	["wave_height", "Wave height", 0.0, 0.25, 0.005, 0.035],
	["cell_size", "Cell size", 0.5, 2.5, 0.05, 1.0],
	["line_visibility", "Visible ink fragments", 0.0, 1.0, 0.01, 0.48],
	["crest_width", "Line thickness", 0.005, 0.06, 0.001, 0.012],
	["shore_motion", "Shore ripple travel", 0.0, 0.1, 0.001, 0.045],
	["wave_ink_strength", "Wave ink darkness", 0.0, 1.0, 0.01, 0.65],
	["shore_ink_strength", "Shore ink darkness", 0.0, 1.0, 0.01, 0.65],
]
var sliders: Dictionary = {}
var apply_setting: Callable

func setup(callback: Callable) -> void:
	apply_setting = callback
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -302
	offset_right = -20
	offset_top = 88
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("29271fee")
	style.border_color = Color("766b50")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", style)
	add_theme_color_override("font_color", Color("e3cda1"))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	add_child(column)
	var title := Label.new()
	title.text = "WATER CONDITIONS"
	column.add_child(title)
	for setting in SETTINGS:
		add_slider(column, setting)
	var reset := Button.new()
	reset.text = "Reset water defaults"
	reset.pressed.connect(reset_defaults)
	column.add_child(reset)
	var hint := Label.new()
	hint.text = "Changes apply live · Space pauses water"
	hint.add_theme_font_size_override("font_size", 12)
	column.add_child(hint)

func add_slider(column: VBoxContainer, setting: Array) -> void:
	var group := VBoxContainer.new()
	column.add_child(group)
	var row := HBoxContainer.new()
	group.add_child(row)
	var label := Label.new()
	label.text = setting[1]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var readout := Label.new()
	row.add_child(readout)
	var slider := HSlider.new()
	slider.min_value = setting[2]
	slider.max_value = setting[3]
	slider.step = setting[4]
	slider.value = setting[5]
	slider.custom_minimum_size.y = 22
	slider.tooltip_text = setting[1]
	# Scrolling this panel must not accidentally zoom the map or change a value.
	slider.scrollable = false
	group.add_child(slider)
	sliders[setting[0]] = slider
	var update := func(value: float) -> void:
		readout.text = ("%.3f" if float(setting[4]) < 0.01 else "%.2f") % value
		apply_setting.call(setting[0], value)
	slider.value_changed.connect(update)
	update.call(slider.value)

func reset_defaults() -> void:
	for setting in SETTINGS:
		sliders[setting[0]].value = setting[5]

func _gui_input(event: InputEvent) -> void:
	if event is InputEventGesture or event is InputEventMouse:
		accept_event()
