extends Node3D

const CARDS := [
	{"energy": 1, "title": "SHORT SAIL", "detail": "Ahead 1.2", "distance": 1.2, "turn": 0.0, "kind": "maneuver"},
	{"energy": 2, "title": "FULL SAIL", "detail": "Ahead 2.4", "distance": 2.4, "turn": 0.0, "kind": "maneuver"},
	{"energy": 1, "title": "PORT", "detail": "Left 45° · Ahead 0.8", "distance": 0.8, "turn": 45.0, "kind": "maneuver"},
	{"energy": 1, "title": "STARBOARD", "detail": "Right 45° · Ahead 0.8", "distance": 0.8, "turn": -45.0, "kind": "maneuver"},
	{"energy": 1, "title": "BACK WATER", "detail": "Reverse 0.8", "distance": -0.8, "turn": 0.0, "kind": "maneuver"},
	{"energy": 2, "title": "CHAIN SHOT", "detail": "Tear rigging · Short range", "range": 3.5, "damage": 20, "shot": "chain", "kind": "cannon"},
	{"energy": 3, "title": "BALL SHOT", "detail": "Crack hulls · Long range", "range": 6.0, "damage": 30, "shot": "ball", "kind": "cannon"},
	{"energy": 2, "title": "CANISTER SHOT", "detail": "Sweep decks · Close range", "range": 2.0, "damage": 45, "shot": "canister", "kind": "cannon"},
	{"energy": 2, "title": "GRAPE SHOT", "detail": "Scatter iron · Short range", "range": 3.0, "damage": 35, "shot": "grape", "kind": "cannon"},
	{"energy": 2, "title": "BAR SHOT", "detail": "Break spars · Medium range", "range": 4.5, "damage": 25, "shot": "bar", "kind": "cannon"},
	{"energy": 3, "title": "BOMB SHOT", "detail": "Burst on deck · Short fuse", "range": 4.0, "damage": 40, "shot": "bomb", "kind": "cannon"},
]
var targets: Array[Node3D] = []
var shot_effect: Node3D
var shot_target: Node3D
var shot_damage := 0

var map: Node3D
var ship: Node3D
var wake: MeshInstance3D
const TURN_ENERGY := 5
var energy := TURN_ENERGY
var turn_number := 1
var draw_used := false
var draw_blocked := false
var discard_mode := false
var draw_button: Button
var discard_button: Button
var end_turn_button: Button
var hull := 3
var draw_pile: Array[int] = []
var discard_pile: Array[int] = []
var hand: Array[int] = []
var busy := false
var heading := 0.0
var movement_left := 0.0
var movement_sign := 1.0
var turn_left := 0.0
var knockback_left := 0.0
var knockback_direction := Vector3.ZERO
var status: Label
var counters: Label
var energy_value: Label
var energy_pips: Label
var hand_row: Control
var discard_label: Label
var message := "Cannons auto-aim at the nearest clear raft in range. Sail closer for short-range shots."
var last_card := "Empty"
var rng := RandomNumberGenerator.new()

func setup(map_node: Node3D, layer: CanvasLayer) -> void:
	map = map_node
	rng.randomize()
	ship = preload("res://scripts/player_ship.gd").new()
	add_child(ship)
	wake = preload("res://scripts/ship_wake.gd").new()
	wake.geography_texture = map.geography.texture
	add_child(wake)
	build_ui(layer)
	restart()

func shuffle_pile() -> void:
	for i in range(draw_pile.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp := draw_pile[i]
		draw_pile[i] = draw_pile[j]
		draw_pile[j] = temp

func restart() -> void:
	if is_instance_valid(shot_effect):
		shot_effect.free()
	shot_effect = null
	shot_target = null
	for target in targets:
		target.free()
	targets.clear()
	for at in [Vector3(-0.7, 0.04, 3.6), Vector3(1.8, 0.04, 1.5), Vector3(0.8, 0.04, -2.6), Vector3(5.8, 0.04, -2.2)]:
		var target = preload("res://scripts/target_raft.gd").new()
		target.position = at
		target.number = targets.size() + 1
		add_child(target)
		targets.append(target)
	energy = TURN_ENERGY
	turn_number = 1
	draw_used = false
	draw_blocked = false
	discard_mode = false
	hull = 3
	busy = false
	movement_left = 0.0
	turn_left = 0.0
	knockback_left = 0.0
	heading = 0.0
	ship.position = Vector3(0.9, 0.04, 3.5)
	ship.rotation = Vector3.ZERO
	wake.ship_position = ship.position
	wake.ship_heading = heading
	wake.ripple_clock = 0.0
	wake.samples.clear()
	wake.advance(0.0)
	# Maneuvers are the deck's backbone; each specialist ammunition card is unique.
	draw_pile.assign([0, 1, 2, 3, 4, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	discard_pile.clear()
	hand.clear()
	shuffle_pile()
	last_card = "Empty"
	message = "Cannons auto-aim at the nearest clear raft in range. Sail closer for short-range shots."
	map.shake_remaining = 0.0
	deal_hand()
	refresh_ui()

func deal_hand() -> void:
	while hand.size() < 5:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile.assign(discard_pile)
			discard_pile.clear()
			shuffle_pile()
			last_card = "Empty"
			message = "Discard reshuffled into the draw pile. New hand ready."
		hand.append(draw_pile.pop_back())

func play_card(index: int) -> void:
	if busy or hull <= 0 or index < 0 or index >= hand.size():
		return
	if discard_mode:
		discard_for_energy(index)
		return
	var card: Dictionary = CARDS[hand[index]]
	if energy < int(card.energy):
		message = "Need %d energy. Discard a card for +1 or end your turn." % card.energy
		refresh_ui()
		return
	if card.kind == "cannon":
		shot_target = find_target(float(card.range))
		if shot_target == null:
			message = "No clear target within %.1f units. Sail closer; card kept." % card.range
			refresh_ui()
			return
	energy -= int(card.energy)
	hand_row.animate_discard(index)
	var id := hand[index]
	hand.remove_at(index)
	discard_pile.append(id)
	last_card = CARDS[id].title
	if CARDS[id].kind == "cannon":
		busy = true
		shot_damage = int(card.damage)
		shot_effect = preload("res://scripts/cannon_effect.gd").new()
		var direction: Vector3 = (shot_target.position - ship.position).normalized()
		shot_effect.origin = ship.position + direction * 0.22 + Vector3.UP * 0.25
		shot_effect.destination = shot_target.position + Vector3.UP * 0.28
		shot_effect.shot = card.shot
		add_child(shot_effect)
		map.shake_remaining = 0.15
		message = "%s → Raft %d · %d damage" % [last_card, shot_target.number, shot_damage]
		refresh_ui()
		return
	movement_left = absf(CARDS[id].distance)
	movement_sign = signf(CARDS[id].distance)
	turn_left = deg_to_rad(CARDS[id].turn)
	busy = true
	message = "Playing %s…" % last_card
	refresh_ui()

func _physics_process(delta: float) -> void:
	if map == null:
		return
	for target in targets:
		target.advance(delta)
	if is_instance_valid(shot_effect):
		if shot_effect.advance(delta):
			shot_target.hit(shot_damage)
			message = "%s hit Raft %d for %d · %s" % [last_card, shot_target.number, shot_damage, "SUNK!" if shot_target.health <= 0 else "%d hull left" % shot_target.health]
		if shot_effect.age >= shot_effect.duration + 0.45:
			shot_effect.free()
			shot_effect = null
			busy = false
			refresh_ui()
		return
	wake.ship_position = ship.position
	wake.ship_heading = heading
	wake.advance(delta, 0.0 if map.paused else delta)
	if knockback_left > 0.0:
		var amount := minf(knockback_left, delta * 1.7)
		var next := ship.position + knockback_direction * amount
		if map.geography.navigable(Vector2(next.x, next.z)):
			ship.position = next
		knockback_left = maxf(0, knockback_left - amount)
		if knockback_left <= 0.0:
			finish_card()
		return
	if not busy:
		return
	if absf(turn_left) > 0.001:
		var step := signf(turn_left) * minf(absf(turn_left), delta * 2.0)
		heading += step
		turn_left -= step
		ship.rotation.y = heading
		return
	var direction := Vector3(-sin(heading), 0, -cos(heading)) * movement_sign
	var advance := minf(movement_left, delta * 1.25)
	# Sweep in small increments so even a long frame cannot tunnel through rocks.
	while advance > 0.00001:
		var amount := minf(advance, 0.035)
		var candidate := ship.position + direction * amount
		if absf(candidate.x) > 8.55 or absf(candidate.z) > 5.55:
			movement_left = 0.0
			message = "Chart edge reached. Turn or reverse to stay on the map."
			finish_card()
			return
		if not map.geography.navigable(Vector2(candidate.x, candidate.z)):
			collide(direction)
			return
		ship.position = candidate
		advance -= amount
		movement_left -= amount
		wake.leave(ship.position, direction)
	if movement_left <= 0.0001:
		finish_card()

func collide(direction: Vector3) -> void:
	hull = maxi(0, hull - 1)
	movement_left = 0.0
	turn_left = 0.0
	knockback_left = 0.38
	knockback_direction = -direction
	map.shake_remaining = 0.38
	message = "Grounded! Knocked back · −1 hull" if hull > 0 else "Ship lost — hull 0/3. Restart voyage to try again."
	refresh_ui()

func finish_card() -> void:
	busy = false
	if hull > 0:
		if not message.begins_with("Grounded") and not message.begins_with("Chart edge"):
			message = "Choose a card, discard for energy, or end your turn."
	refresh_ui()

func build_ui(layer: CanvasLayer) -> void:
	var header := HBoxContainer.new()
	layer.add_child(header)
	header.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	header.offset_left = 32
	header.offset_right = -32
	header.offset_top = -329
	header.offset_bottom = -285
	header.add_theme_constant_override("separation", 10)
	counters = Label.new()
	counters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	counters.add_theme_color_override("font_color", Color("e4cea0"))
	header.add_child(counters)
	var energy_panel := PanelContainer.new()
	energy_panel.custom_minimum_size = Vector2(154, 44)
	var energy_style := StyleBoxFlat.new()
	energy_style.bg_color = Color("263e3a")
	energy_style.border_color = Color("d7b866")
	energy_style.set_border_width_all(2)
	energy_style.set_corner_radius_all(6)
	energy_style.set_content_margin_all(6)
	energy_panel.add_theme_stylebox_override("panel", energy_style)
	header.add_child(energy_panel)
	var energy_row := HBoxContainer.new()
	energy_row.add_theme_constant_override("separation", 8)
	energy_panel.add_child(energy_row)
	energy_value = Label.new()
	energy_value.custom_minimum_size.x = 32
	energy_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	energy_value.add_theme_color_override("font_color", Color("f5dea0"))
	energy_value.add_theme_font_size_override("font_size", 26)
	energy_row.add_child(energy_value)
	var energy_details := VBoxContainer.new()
	energy_details.add_theme_constant_override("separation", -2)
	energy_row.add_child(energy_details)
	var energy_title := Label.new()
	energy_title.text = "ENERGY / ROUND"
	energy_title.add_theme_color_override("font_color", Color("e4cea0"))
	energy_title.add_theme_font_size_override("font_size", 10)
	energy_details.add_child(energy_title)
	energy_pips = Label.new()
	energy_pips.add_theme_color_override("font_color", Color("d7b866"))
	energy_pips.add_theme_font_size_override("font_size", 14)
	energy_details.add_child(energy_pips)
	draw_button = Button.new()
	draw_button.pressed.connect(draw_turn_card)
	header.add_child(draw_button)
	discard_button = Button.new()
	discard_button.toggle_mode = true
	discard_button.text = "Discard → +1 energy"
	discard_button.toggled.connect(func(active: bool) -> void:
		discard_mode = active
		message = "Choose a card to discard for +1 energy. No more draws this turn." if active else "Choose a card to play."
		refresh_ui())
	header.add_child(discard_button)
	end_turn_button = Button.new()
	end_turn_button.text = "End turn"
	end_turn_button.pressed.connect(end_turn)
	header.add_child(end_turn_button)
	var restart_button := Button.new()
	restart_button.text = "Restart voyage"
	restart_button.pressed.connect(restart)
	header.add_child(restart_button)
	status = Label.new()
	layer.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_top = -354
	status.offset_bottom = -332
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 13)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_row = preload("res://scripts/card_hand.gd").new()
	layer.add_child(hand_row)
	hand_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hand_row.offset_top = -280
	hand_row.offset_bottom = 0
	hand_row.card_played.connect(play_card)

func refresh_ui() -> void:
	if counters == null:
		return
	counters.text = "HULL %d/3  ·  TURN %d" % [hull, turn_number]
	energy_value.text = str(energy)
	var filled := mini(energy, TURN_ENERGY)
	energy_pips.text = "●".repeat(filled) + "○".repeat(TURN_ENERGY - filled)
	if energy > TURN_ENERGY:
		energy_pips.text += " +%d" % (energy - TURN_ENERGY)
	var locked := busy or hull <= 0
	draw_button.text = "Draw blocked" if draw_blocked else "Draw used" if draw_used else "Draw 1 card"
	draw_button.disabled = locked or draw_used or draw_blocked
	discard_button.disabled = locked or hand.is_empty()
	discard_button.set_pressed_no_signal(discard_mode)
	end_turn_button.disabled = locked
	status.text = message
	var cards: Array = []
	for id in hand:
		cards.append(CARDS[id])
	hand_row.update_hand(cards, busy or hull <= 0, draw_pile.size(), discard_pile.size(), last_card, energy, discard_mode)

func find_target(reach: float) -> Node3D:
	var nearest: Node3D = null
	var best := reach
	for target in targets:
		if target.health <= 0: continue
		var start := Vector2(ship.position.x, ship.position.z)
		var end := Vector2(target.position.x, target.position.z)
		var distance := start.distance_to(end)
		if distance > best: continue
		var clear := true
		var steps := maxi(1, ceili(distance / 0.06))
		for i in range(1, steps):
			if map.geography.distance_at(start.lerp(end, float(i) / steps)) < 0.04:
				clear = false
				break
		if clear:
			nearest = target
			best = distance
	return nearest

func end_turn() -> void:
	if busy or hull <= 0: return
	turn_number += 1
	energy = TURN_ENERGY
	draw_used = false
	draw_blocked = false
	discard_mode = false
	deal_hand()
	message = "Turn %d · 5 energy. Hand refilled to five; one optional draw available." % turn_number
	refresh_ui()

func draw_turn_card() -> void:
	if busy or hull <= 0 or draw_used or draw_blocked: return
	if draw_pile.is_empty():
		if discard_pile.is_empty(): return
		draw_pile.assign(discard_pile)
		discard_pile.clear()
		shuffle_pile()
		last_card = "Empty"
	hand.append(draw_pile.pop_back())
	draw_used = true
	discard_mode = false
	message = "Drew one card. Next draw available next turn."
	refresh_ui()

func discard_for_energy(index: int) -> void:
	if busy or hull <= 0 or index < 0 or index >= hand.size(): return
	hand_row.animate_discard(index)
	var id := hand[index]
	hand.remove_at(index)
	discard_pile.append(id)
	last_card = CARDS[id].title
	energy += 1
	draw_blocked = true
	discard_mode = false
	message = "Discarded %s · +1 energy. No more draws this turn." % last_card
	refresh_ui()
