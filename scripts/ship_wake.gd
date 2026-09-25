extends MeshInstance3D

var samples: Array[Dictionary] = []
var lifetime := 3.2
var geography_texture: Texture2D
var ship_position := Vector3.ZERO
var ship_heading := 0.0
var ripple_clock := 0.0

func _ready() -> void:
	var ink := ShaderMaterial.new()
	ink.shader = load("res://shaders/wake.gdshader")
	ink.set_shader_parameter("geography_map", geography_texture)
	material_override = ink

func leave(position_on_map: Vector3, direction: Vector3) -> void:
	var stern := position_on_map - direction * 0.3
	if samples.is_empty() or samples.back().position.distance_to(stern) > 0.09:
		samples.append({"position": stern, "direction": direction, "age": 0.0})
	if samples.size() > 70:
		samples.pop_front()

func advance(delta: float, ripple_delta: float = -1.0) -> void:
	for sample in samples:
		sample.age += delta
	while not samples.is_empty() and samples.front().age > lifetime:
		samples.pop_front()
	ripple_clock += delta if ripple_delta < 0.0 else ripple_delta
	var trail := ImmediateMesh.new()
	trail.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if samples.size() > 1:
		for i in range(1, samples.size()):
			for side in [-1.0, 1.0]:
				var a := edge(samples[i - 1], side)
				var b := edge(samples[i], side)
				var ca := Color(0.30, 0.42, 0.38, (1.0 - samples[i - 1].age / lifetime) * 0.65)
				var cb := Color(0.30, 0.42, 0.38, (1.0 - samples[i].age / lifetime) * 0.65)
				var across := Vector3(0.022, 0, 0.012)
				for index in 6:
					trail.surface_set_color(ca if index in [0, 1, 3] else cb)
					var vertices := [a - across, a + across, b + across, a - across, b + across, b - across]
					trail.surface_add_vertex(vertices[index])
	add_idle_ripples(trail)
	trail.surface_end()
	mesh = trail

# Broken oval contours breathe away from the hull even while the ship is idle.
# Keeping them in the wake mesh gives them the same watercolor ink and land mask.
func add_idle_ripples(trail: ImmediateMesh) -> void:
	const SEGMENTS := 40
	for ring_index in 3:
		var phase := fmod(ripple_clock / 2.8 + float(ring_index) / 3.0, 1.0)
		var radius := 0.03 + phase * 0.23
		var alpha := sin(phase * PI) * 0.24
		var color := Color(0.30, 0.42, 0.38, alpha)
		for segment in SEGMENTS:
			var angle_a := TAU * float(segment) / float(SEGMENTS)
			var angle_b := TAU * float(segment + 1) / float(SEGMENTS)
			# Uneven gaps keep each contour feeling drawn instead of geometric.
			if sin(angle_a * 4.0 + float(ring_index) * 1.9) < -0.48:
				continue
			var a_inner := ripple_point(angle_a, radius - 0.006)
			var a_outer := ripple_point(angle_a, radius + 0.006)
			var b_inner := ripple_point(angle_b, radius - 0.006)
			var b_outer := ripple_point(angle_b, radius + 0.006)
			for vertex in [a_inner, a_outer, b_outer, a_inner, b_outer, b_inner]:
				trail.surface_set_color(color)
				trail.surface_add_vertex(vertex)

func ripple_point(angle: float, radius: float) -> Vector3:
	# The base ellipse clears the hull and rotates with the bow.
	var local := Vector3(cos(angle) * (0.24 + radius), 0.0, sin(angle) * (0.42 + radius))
	var result := ship_position + Basis(Vector3.UP, ship_heading) * local
	result.y = 0.095
	return result

func edge(sample: Dictionary, side: float) -> Vector3:
	var direction: Vector3 = sample.direction
	var sideways := Vector3(-direction.z, 0, direction.x)
	var result: Vector3 = sample.position + sideways * side * (0.12 + sample.age * 0.15 + sin(sample.age * 5.0 + sample.position.z * 3.0) * 0.02)
	result.y = 0.09
	return result
