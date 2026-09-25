extends Control

var card: Dictionary = {}
var locked := false
var highlighted := false
const INK := Color("382e21")
const GOLD := Color("b49355")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(164, 226)

func text_center(value: String, y: float, font_size: int, color: Color = INK) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2((164 - font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) / 2, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func draw_sea_lines() -> void:
	for row in 4:
		var points := PackedVector2Array()
		for x in range(24, 144, 3):
			points.append(Vector2(x, 126 + row * 5 + sin(x * 0.1 + row) * 1.5))
		draw_polyline(points, Color("657e70"), 1, true)

func draw_maneuver_vignette() -> void:
	draw_sea_lines()
	draw_colored_polygon(PackedVector2Array([Vector2(50, 113), Vector2(114, 113), Vector2(101, 125), Vector2(65, 125)]), INK)
	draw_line(Vector2(81, 57), Vector2(81, 115), INK, 2, true)
	draw_colored_polygon(PackedVector2Array([Vector2(77, 63), Vector2(77, 105), Vector2(51, 103)]), Color("f1e4bd"))
	draw_colored_polygon(PackedVector2Array([Vector2(86, 66), Vector2(111, 105), Vector2(86, 105)]), Color("e4d2a5"))
	draw_polyline(PackedVector2Array([Vector2(77, 63), Vector2(77, 105), Vector2(51, 103), Vector2(77, 63)]), INK, 1, true)
	var turn: float = card.get("turn", 0.0)
	var symbol := "↑"
	if turn > 0: symbol = "↶"
	elif turn < 0: symbol = "↷"
	elif float(card.get("distance", 1.0)) < 0: symbol = "↓"
	text_center(symbol, 95, 35, Color("403922"))

func draw_cannon_vignette() -> void:
	# A compact engraved deck gun, with a distinct ammunition mark above it.
	draw_line(Vector2(43, 122), Vector2(119, 122), Color("657e70"), 1, true)
	draw_colored_polygon(PackedVector2Array([Vector2(51, 108), Vector2(61, 117), Vector2(111, 88), Vector2(104, 79)]), INK)
	draw_circle(Vector2(63, 119), 9, Color("54432e"), false, 3, true)
	draw_circle(Vector2(97, 119), 9, Color("54432e"), false, 3, true)
	for puff in [Vector2(118, 83), Vector2(126, 76), Vector2(119, 68)]:
		draw_circle(puff, 6, Color(0.92, 0.87, 0.72, 0.65))
	var shot: String = card.get("shot", "ball")
	match shot:
		"chain":
			draw_circle(Vector2(60, 67), 8, INK)
			draw_circle(Vector2(96, 67), 8, INK)
			draw_dashed_line(Vector2(68, 67), Vector2(88, 67), INK, 2, 3, true)
		"ball":
			draw_circle(Vector2(79, 68), 13, INK)
			draw_arc(Vector2(75, 64), 4, 3.4, 5.8, 10, Color("9f8e68"), 2, true)
		"canister":
			draw_rect(Rect2(64, 54, 30, 29), Color("67543a"), true)
			draw_rect(Rect2(62, 52, 34, 4), INK, true)
			draw_rect(Rect2(62, 81, 34, 4), INK, true)
			for pellet in [Vector2(70, 62), Vector2(79, 62), Vector2(88, 62), Vector2(74, 73), Vector2(84, 73)]:
				draw_circle(pellet, 2.5, Color("c4b182"))
		"grape":
			for pellet in [Vector2(79, 55), Vector2(72, 64), Vector2(86, 64), Vector2(65, 73), Vector2(79, 73), Vector2(93, 73), Vector2(72, 82), Vector2(86, 82)]:
				draw_circle(pellet, 5.5, INK)
		"bar":
			draw_line(Vector2(61, 78), Vector2(97, 57), INK, 5, true)
			draw_line(Vector2(55, 70), Vector2(66, 88), INK, 7, true)
			draw_line(Vector2(92, 48), Vector2(103, 66), INK, 7, true)
		"bomb":
			draw_circle(Vector2(78, 70), 15, INK)
			draw_line(Vector2(87, 58), Vector2(98, 49), Color("6f4e2e"), 3, true)
			draw_circle(Vector2(101, 47), 4, Color("c3833e"))

func _draw() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("d9c69a") if not locked else Color("b4a789")
	frame.border_color = Color("f5dea0") if highlighted else Color("655035")
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(9)
	frame.shadow_color = Color(0, 0, 0, 0.6)
	frame.shadow_size = 9 if highlighted else 5
	frame.shadow_offset = Vector2(0, 5)
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(8, 8, 148, 210), GOLD, false, 1)
	draw_rect(Rect2(12, 42, 140, 108), Color("a6b7a1"))
	# Tiny deterministic flecks give the stock a printed-paper texture.
	for i in 90:
		var at := Vector2(12 + fposmod(i * 37.17, 139), 10 + fposmod(i * 61.13, 201))
		draw_circle(at, 0.6, Color(0.3, 0.24, 0.14, 0.12))
	var title: String = card.get("title", "SAILING")
	text_center(title, 29, 13 if title.length() > 12 else 15)
	var cannon_card: bool = String(card.get("kind", "maneuver")) == "cannon"
	if cannon_card:
		draw_cannon_vignette()
	else:
		draw_maneuver_vignette()
	text_center(("CANNON" if cannon_card else "MANEUVER") + "  ·  %d ENERGY" % card.get("energy", 1), 165, 10, Color("725e3a"))
	var detail: String = "Range %.1f · Damage %d" % [card.get("range", 0), card.get("damage", 0)] if cannon_card else card.get("detail", "")
	var lines := detail.split(" · ")
	text_center(lines[0], 187, 15)
	if lines.size() > 1:
		text_center(lines[1], 205, 13)
	else:
		text_center("Fire broadside" if cannon_card else "Move your ship", 205, 11, Color("725e3a"))
