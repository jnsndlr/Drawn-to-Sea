extends Control

var card: Dictionary = {}
var locked := false
var highlighted := false

const CARD_SIZE := Vector2(164, 226)
const INK := Color("382e21")
const MUTED_INK := Color("725e3a")
const GOLD := Color("b49355")
const PAPER := Color("d9c69a")
const PAPER_DARK := Color("b4a789")
const SEA_WASH := Color("a6b7a1")
const SAIL := Color("eee0ba")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = CARD_SIZE


func text_center(value: String, y: float, font_size: int, color: Color = INK, left := 0.0, width := 164.0) -> void:
	var font := ThemeDB.fallback_font
	var text_width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(left + (width - text_width) * 0.5, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func fitted_title_size(value: String) -> int:
	var font := ThemeDB.fallback_font
	for font_size in range(15, 9, -1):
		if font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= 108:
			return font_size
	return 9


func draw_panel() -> void:
	draw_rect(Rect2(10, 47, 144, 98), SEA_WASH)
	draw_rect(Rect2(10, 47, 144, 98), INK, false, 2)
	# Sparse flecks keep the wash related to the map without competing with the icon.
	for i in 17:
		var at := Vector2(14 + fposmod(i * 31.7, 136), 51 + fposmod(i * 47.3, 90))
		draw_circle(at, 0.55, Color(0.22, 0.18, 0.12, 0.11))


func draw_energy_medallion() -> void:
	var center := Vector2(25, 25)
	draw_circle(center, 18, Color("c3a66b"))
	draw_circle(center, 18, INK, false, 2, true)
	draw_circle(center, 14, Color("e0c78d"), false, 1, true)
	text_center(str(card.get("energy", 1)), 32, 20, INK, 7, 36)


func draw_wave_lines() -> void:
	for row in 3:
		var points := PackedVector2Array()
		for x in range(19, 148, 4):
			points.append(Vector2(x, 126 + row * 6 + sin(x * 0.09 + row * 1.7) * 1.4))
		draw_polyline(points, Color("657e70"), 1.4, true)


func draw_movement_arrow() -> void:
	var turn: float = card.get("turn", 0.0)
	var backwards := float(card.get("distance", 1.0)) < 0.0
	var center := Vector2(124, 75)
	if turn > 0.0:
		draw_arc(Vector2(119, 82), 13, -1.15, 3.5, 18, GOLD, 3, true)
		draw_colored_polygon(PackedVector2Array([Vector2(107, 68), Vector2(117, 68), Vector2(112, 77)]), GOLD)
	elif turn < 0.0:
		draw_arc(Vector2(119, 82), 13, -0.35, 4.3, 18, GOLD, 3, true)
		draw_colored_polygon(PackedVector2Array([Vector2(131, 68), Vector2(121, 68), Vector2(126, 77)]), GOLD)
	else:
		var direction := -1.0 if backwards else 1.0
		var stem_start := center + Vector2(0, 9 * direction)
		var stem_end := center - Vector2(0, 9 * direction)
		draw_line(stem_start, stem_end, GOLD, 4, true)
		var tip := center - Vector2(0, 16 * direction)
		draw_colored_polygon(PackedVector2Array([
			tip,
			center + Vector2(-7, -5 * direction),
			center + Vector2(7, -5 * direction)
		]), GOLD)


func draw_maneuver_vignette() -> void:
	draw_wave_lines()
	# A deliberately simple side-view sloop, built from the same primitives as the map art.
	draw_colored_polygon(PackedVector2Array([
		Vector2(36, 118), Vector2(102, 118), Vector2(92, 130), Vector2(48, 130)
	]), INK)
	draw_line(Vector2(69, 67), Vector2(69, 120), INK, 2.2, true)
	draw_colored_polygon(PackedVector2Array([Vector2(66, 72), Vector2(66, 113), Vector2(40, 111)]), SAIL)
	draw_colored_polygon(PackedVector2Array([Vector2(73, 76), Vector2(98, 113), Vector2(73, 113)]), SAIL)
	draw_polyline(PackedVector2Array([Vector2(66, 72), Vector2(66, 113), Vector2(40, 111), Vector2(66, 72)]), INK, 1.2, true)
	draw_polyline(PackedVector2Array([Vector2(73, 76), Vector2(98, 113), Vector2(73, 113)]), INK, 1.2, true)
	draw_line(Vector2(69, 67), Vector2(77, 70), INK, 1.5, true)
	draw_movement_arrow()


func draw_ammunition_mark(shot: String) -> void:
	match shot:
		"chain":
			draw_circle(Vector2(62, 73), 7, INK)
			draw_circle(Vector2(91, 73), 7, INK)
			draw_dashed_line(Vector2(69, 73), Vector2(84, 73), INK, 2, 3, true)
		"ball":
			draw_circle(Vector2(77, 73), 11, INK)
			draw_arc(Vector2(74, 70), 3, 3.4, 5.8, 8, Color("a89468"), 1.5, true)
		"canister":
			draw_rect(Rect2(64, 62, 27, 23), Color("67543a"))
			draw_rect(Rect2(62, 60, 31, 3), INK)
			draw_rect(Rect2(62, 84, 31, 3), INK)
			for pellet in [Vector2(70, 68), Vector2(78, 68), Vector2(86, 68), Vector2(74, 77), Vector2(83, 77)]:
				draw_circle(pellet, 2.0, SAIL)
		"grape":
			for pellet in [Vector2(77, 61), Vector2(70, 69), Vector2(84, 69), Vector2(64, 78), Vector2(77, 78), Vector2(90, 78), Vector2(71, 86), Vector2(84, 86)]:
				draw_circle(pellet, 4.2, INK)
		"bar":
			draw_line(Vector2(61, 82), Vector2(93, 63), INK, 4, true)
			draw_line(Vector2(57, 75), Vector2(65, 88), INK, 6, true)
			draw_line(Vector2(89, 57), Vector2(97, 70), INK, 6, true)
		"bomb":
			draw_circle(Vector2(76, 75), 12, INK)
			draw_line(Vector2(84, 66), Vector2(93, 58), Color("6f4e2e"), 2.5, true)
			draw_circle(Vector2(96, 55), 3.5, Color("c3833e"))


func draw_cannon_vignette() -> void:
	# Compact deck gun below a large ammunition silhouette.
	draw_ammunition_mark(String(card.get("shot", "ball")))
	draw_line(Vector2(31, 132), Vector2(135, 132), Color("657e70"), 1.4, true)
	draw_colored_polygon(PackedVector2Array([Vector2(48, 113), Vector2(58, 122), Vector2(120, 91), Vector2(113, 82)]), INK)
	draw_circle(Vector2(62, 128), 8, MUTED_INK, false, 3, true)
	draw_circle(Vector2(99, 128), 8, MUTED_INK, false, 3, true)
	for puff in [Vector2(126, 86), Vector2(135, 79), Vector2(128, 72)]:
		draw_circle(puff, 5, Color(0.93, 0.88, 0.74, 0.62))


func draw_card_frame() -> void:
	var frame := StyleBoxFlat.new()
	frame.bg_color = PAPER_DARK if locked else PAPER
	frame.border_color = Color("f5dea0") if highlighted else INK
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(9)
	frame.shadow_color = Color(0, 0, 0, 0.6)
	frame.shadow_size = 9 if highlighted else 5
	frame.shadow_offset = Vector2(0, 5)
	draw_style_box(frame, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(7, 7, 150, 212), GOLD, false, 1)
	# Deterministic flecks make the stock feel printed rather than digitally flat.
	for i in 72:
		var at := Vector2(8 + fposmod(i * 37.17, 148), 8 + fposmod(i * 61.13, 210))
		draw_circle(at, 0.55, Color(0.3, 0.24, 0.14, 0.1))


func _draw() -> void:
	draw_card_frame()
	draw_panel()
	draw_energy_medallion()
	var title: String = card.get("title", "SAILING")
	text_center(title, 31, fitted_title_size(title), INK, 46, 108)
	var cannon_card := String(card.get("kind", "maneuver")) == "cannon"
	if cannon_card:
		draw_cannon_vignette()
	else:
		draw_maneuver_vignette()
	draw_line(Vector2(12, 153), Vector2(152, 153), GOLD, 1)
	text_center(("CANNON" if cannon_card else "MANEUVER") + "  ·  %d ENERGY" % card.get("energy", 1), 168, 10, MUTED_INK)
	draw_line(Vector2(12, 174), Vector2(152, 174), GOLD, 1)
	var detail: String = "Range %.1f · Damage %d" % [card.get("range", 0), card.get("damage", 0)] if cannon_card else card.get("detail", "")
	var lines := detail.split(" · ")
	text_center(lines[0], 195, 14 if lines[0].length() < 13 else 12)
	if lines.size() > 1:
		text_center(lines[1], 213, 12)
	else:
		text_center("Fire broadside" if cannon_card else "Move your ship", 213, 11, MUTED_INK)
	if locked:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.1, 0.08, 0.16))
