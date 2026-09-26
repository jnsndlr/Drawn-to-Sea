extends Node3D

const MODEL := preload("res://assets/ship/ship.obj")
const TOON := preload("res://shaders/ship_toon.gdshader")
const OUTLINE := preload("res://shaders/ship_outline.gdshader")
# The OBJ is ~79 units bow to bowsprit with its bow on +Z and keel at y = -1.7.
const MODEL_SCALE := 0.016
const WATERLINE := 1.5
const SAIL_TINT := Color("eadcb4")
const WOOD_TINT := Color("9a7650")
# Sails and flags are single planes, so an inverted hull cannot outline them.
const SAIL_TEXTURES := ["texture012", "texture014"]
const FLAG_TEXTURES := ["texture013"]

static var toon_mesh: ArrayMesh

func _ready() -> void:
	var model := MeshInstance3D.new()
	model.mesh = build_mesh()
	model.scale = Vector3.ONE * MODEL_SCALE
	model.position.y = -WATERLINE * MODEL_SCALE
	model.rotation.y = PI
	add_child(model)
	for i in model.mesh.get_surface_count():
		var source: StandardMaterial3D = MODEL.surface_get_material(i)
		var texture_name := source.albedo_texture.resource_path.get_file().get_basename()
		var material := ShaderMaterial.new()
		material.shader = TOON
		material.set_shader_parameter("albedo_texture", source.albedo_texture)
		material.set_shader_parameter("tint", SAIL_TINT if texture_name in SAIL_TEXTURES else WOOD_TINT)
		if texture_name not in SAIL_TEXTURES and texture_name not in FLAG_TEXTURES:
			var outline := ShaderMaterial.new()
			outline.shader = OUTLINE
			outline.set_shader_parameter("albedo_texture", source.albedo_texture)
			material.next_pass = outline
		model.set_surface_override_material(i, material)

# The OBJ has flat normals, which split an inverted-hull outline at every hard
# edge. Averaging normals that share a position closes those gaps.
static func build_mesh() -> ArrayMesh:
	if toon_mesh:
		return toon_mesh
	toon_mesh = ArrayMesh.new()
	for i in MODEL.get_surface_count():
		var arrays := MODEL.surface_get_arrays(i)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var summed := {}
		for v in vertices.size():
			var key := vertices[v].snappedf(0.001)
			summed[key] = summed.get(key, Vector3.ZERO) + normals[v]
		for v in vertices.size():
			normals[v] = summed[vertices[v].snappedf(0.001)].normalized()
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		toon_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return toon_mesh
