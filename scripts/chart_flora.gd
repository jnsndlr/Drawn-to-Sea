extends Node3D
## Scatters billboard trees, bushes and palms over the explorer's chart, using
## land data baked from the same geography the chart shader paints.

const SPACING := 0.17
const TREE := 0.0
const BUSH := 0.5
const PALM := 1.0
# Atlas layout from flora_atlas_bake.gdshader: first cell and variant count per kind.
const ATLAS_CELLS := {TREE: [0, 16], BUSH: [16, 8], PALM: [24, 8]}
# Offset of each ground shadow, away from the upper-left light.
const SHADOW_OFFSET := Vector2(0.28, 0.2)

var land: Image
var chart_size: Vector2
var atlas: Texture2D

func build(land_image: Image, size: Vector2, plant_atlas: Texture2D) -> void:
	land = land_image
	atlas = plant_atlas
	chart_size = size
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var plants: Array[Dictionary] = []
	var half := size * 0.5
	var y := -half.y
	while y < half.y:
		var x := -half.x
		while x < half.x:
			var p := Vector2(x, y) + Vector2(rng.randf(), rng.randf()) * SPACING
			var plant := choose_plant(p, rng)
			if not plant.is_empty():
				plants.append(plant)
			x += SPACING
		y += SPACING
	add_child(make_shadows(plants))
	add_child(make_sprites(plants))

# Returns {} for bare ground, else {position, kind, size, seed}.
func choose_plant(p: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var sample := sample_land(p)
	var zone := zone_of(sample)
	var grove := sample.b
	var roll := rng.randf()
	var kind := -1.0
	var size := 0.0
	if zone == "plateau":
		if grove > 0.47 and roll < 0.92 and is_solid_plateau(p):
			kind = TREE
			size = rng.randf_range(0.4, 0.54)
		elif grove > 0.41 and roll < 0.35:
			kind = BUSH
			size = rng.randf_range(0.26, 0.36)
		elif roll < 0.05:
			kind = BUSH
			size = rng.randf_range(0.22, 0.32)
	elif zone == "sand":
		if roll < 0.06:
			kind = PALM
			size = rng.randf_range(0.55, 0.72)
		elif roll < 0.08:
			kind = BUSH
			size = rng.randf_range(0.2, 0.28)
	if kind < 0.0:
		return {}
	return {
		"position": Vector3(p.x, sample.r, p.y),
		"kind": kind,
		"size": size,
		"seed": rng.randf(),
	}

# Trees need room: keep crowns from hanging over cliff edges.
func is_solid_plateau(p: Vector2) -> bool:
	for offset in [Vector2(0.12, 0), Vector2(-0.12, 0), Vector2(0, 0.12), Vector2(0, -0.12)]:
		if zone_of(sample_land(p + offset)) != "plateau":
			return false
	return true

func sample_land(p: Vector2) -> Color:
	var uv := p / chart_size + Vector2(0.5, 0.5)
	var px := clampi(int(uv.x * land.get_width()), 0, land.get_width() - 1)
	var py := clampi(int(uv.y * land.get_height()), 0, land.get_height() - 1)
	return land.get_pixel(px, py)

func zone_of(sample: Color) -> String:
	if sample.g < 0.12:
		return "water"
	if sample.g < 0.37:
		return "sand"
	if sample.g < 0.75:
		return "plateau"
	return "cliff"

func make_sprites(plants: Array[Dictionary]) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = QuadMesh.new()
	multimesh.instance_count = plants.size()
	for i in plants.size():
		var plant: Dictionary = plants[i]
		multimesh.set_instance_transform(i, Transform3D(Basis(), plant.position))
		var cells: Array = ATLAS_CELLS[plant.kind]
		var cell: int = cells[0] + mini(int(plant.seed * cells[1]), cells[1] - 1)
		multimesh.set_instance_custom_data(i, Color(cell, 0.0, plant.size, 0.0))
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/flora_sprite.gdshader")
	material.set_shader_parameter("atlas", atlas)
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	# Sprites are expanded and billboarded in the vertex shader.
	instance.extra_cull_margin = 1.0
	return instance

func make_shadows(plants: Array[Dictionary]) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	multimesh.mesh = plane
	multimesh.instance_count = plants.size()
	for i in plants.size():
		var plant: Dictionary = plants[i]
		var size: float = plant.size
		var stretch := Vector3(1.4, 1.0, 0.9) if plant.kind == PALM else Vector3(1.0, 1.0, 0.8)
		var origin: Vector3 = plant.position + Vector3(SHADOW_OFFSET.x * size, 0.015, SHADOW_OFFSET.y * size)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(stretch * size * 0.95), origin))
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/flora_shadow.gdshader")
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.material_override = material
	return instance
