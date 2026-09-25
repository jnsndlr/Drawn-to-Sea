extends Control

signal card_played(index: int)
var faces: Array[Control] = []
var homes: Array[Vector2] = []
var angles: Array[float] = []
var hovered := -1
var locked := false
var draw_count := 0
var discard_count := 0
var last_discard := "Empty"
var tweens: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(layout_cards)

func update_hand(cards: Array, unavailable: bool, draw_total: int, discard_total: int, last: String, energy: int = 5, discarding: bool = false) -> void:
	for tween in tweens.values():
		if tween.is_valid(): tween.kill()
	tweens.clear()
	for face in faces:
		remove_child(face)
		face.queue_free()
	faces.clear()
	hovered = -1
	locked = unavailable
	draw_count = draw_total
	discard_count = discard_total
	last_discard = last
	for data in cards:
		var face = preload("res://scripts/card_face.gd").new()
		face.card = data
		face.locked = locked or (not discarding and int(data.get("energy", 0)) > energy)
		add_child(face)
		face.pivot_offset = Vector2(82, 210)
		faces.append(face)
	layout_cards()
	queue_redraw()

func layout_cards() -> void:
	homes.clear()
	angles.clear()
	var spacing := minf(115, maxf(60, (size.x - 430) / maxf(1, faces.size())))
	for i in faces.size():
		var offset := float(i) - float(faces.size() - 1) * 0.5
		var home := Vector2(size.x * 0.5 - 82 + offset * spacing, 62 + absf(offset) * 8)
		homes.append(home)
		angles.append(deg_to_rad(offset * 5.0))
		faces[i].position = home
		faces[i].rotation = angles[i]
		faces[i].z_index = i

func _process(_delta: float) -> void:
	if locked: return
	var mouse := get_local_mouse_position()
	var hit := -1
	for i in faces.size():
		var transform := Transform2D(angles[i], homes[i] + Vector2(82, 210))
		var local := transform.affine_inverse() * mouse + Vector2(82, 210)
		if Rect2(Vector2.ZERO, Vector2(164, 226)).has_point(local): hit = i
	if hit == -1 and hovered >= 0:
		if Rect2(Vector2.ZERO, faces[hovered].size).has_point(faces[hovered].get_local_mouse_position()): hit = hovered
	if hit != hovered:
		hovered = hit
		for i in faces.size():
			if tweens.has(i) and tweens[i].is_valid(): tweens[i].kill()
			var face = faces[i]
			face.highlighted = i == hit
			face.z_index = 20 if i == hit else i
			face.queue_redraw()
			var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tweens[i] = tween
			tween.tween_property(face, "position", homes[i] + (Vector2(0, -46) if i == hit else Vector2.ZERO), 0.16)
			tween.tween_property(face, "rotation", 0.0 if i == hit else angles[i], 0.16)
			tween.tween_property(face, "scale", Vector2.ONE * (1.1 if i == hit else 1.0), 0.16)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if hovered >= 0 and not locked:
			card_played.emit(hovered)
		accept_event()
	elif event is InputEventGesture or event is InputEventMouse:
		accept_event()

func animate_discard(index: int) -> void:
	if index < 0 or index >= faces.size(): return
	var source = faces[index]
	var flying = preload("res://scripts/card_face.gd").new()
	flying.card = source.card
	add_child(flying)
	flying.position = source.position
	flying.rotation = source.rotation
	flying.scale = source.scale
	flying.z_index = 40
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(flying, "position", Vector2(size.x - 161, 114), 0.38)
	tween.tween_property(flying, "scale", Vector2(0.48, 0.48), 0.38)
	tween.tween_property(flying, "rotation", 0.15, 0.38)
	tween.chain().tween_callback(flying.queue_free)

func _draw() -> void:
	stack(Vector2(77, 128), "DRAW", draw_count, true)
	stack(Vector2(size.x - 164, 128), "DISCARD", discard_count, false)

func stack(at: Vector2, title: String, count: int, back: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("354d48") if back else Color("bcaa7e")
	style.border_color = Color("a58d58")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.shadow_size = 4
	for i in range(2, -1, -1):
		draw_style_box(style, Rect2(at + Vector2(i * 4, -i * 3), Vector2(86, 112)))
	var font := ThemeDB.fallback_font
	draw_string(font, at + Vector2(14, 27), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f2e2b5") if back else Color("44351f"))
	draw_circle(at + Vector2(43, 64), 23, Color("80704b"), false, 1, true)
	draw_string(font, at + Vector2(34, 72), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("f2e2b5"))
	if not back:
		draw_string(font, at + Vector2(-20, 134), last_discard, HORIZONTAL_ALIGNMENT_CENTER, 128, 11, Color("dcc79a"))
