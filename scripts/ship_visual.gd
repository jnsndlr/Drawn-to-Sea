extends Node3D

func paint(hex: String) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(hex)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func part(mesh: Mesh, color: String, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = paint(color)
	instance.position = at
	add_child(instance)
	return instance

func _ready() -> void:
	var outline := PackedVector2Array([Vector2(0, -0.48), Vector2(0.19, -0.16), Vector2(0.18, 0.27), Vector2(0.11, 0.37), Vector2(-0.11, 0.37), Vector2(-0.18, 0.27), Vector2(-0.19, -0.16)])
	var hull := ImmediateMesh.new()
	hull.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		for vertex in [Vector3(0, 0.19, 0), Vector3(a.x, 0.19, a.y), Vector3(b.x, 0.19, b.y), Vector3(a.x, 0.19, a.y), Vector3(0, 0.025, 0), Vector3(b.x, 0.19, b.y)]:
			hull.surface_add_vertex(vertex)
	hull.surface_end()
	part(hull, "493726", Vector3.ZERO)
	var deck := CylinderMesh.new()
	deck.top_radius = 0.13
	deck.bottom_radius = 0.13
	deck.height = 0.02
	var deck_part := part(deck, "b69a65", Vector3(0, 0.205, 0))
	deck_part.scale.z = 2.4
	var mast := CylinderMesh.new()
	mast.top_radius = 0.014
	mast.bottom_radius = 0.025
	mast.height = 0.8
	part(mast, "493726", Vector3(0, 0.59, 0))
	var sail := ImmediateMesh.new()
	sail.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in [Vector3(-0.28, 0.85, 0.025), Vector3(0.28, 0.85, 0.025), Vector3(0.24, 0.39, -0.065), Vector3(-0.28, 0.85, 0.025), Vector3(0.24, 0.39, -0.065), Vector3(-0.24, 0.39, -0.065)]:
		sail.surface_add_vertex(vertex)
	sail.surface_end()
	part(sail, "e3d1a0", Vector3.ZERO)
	var spar := BoxMesh.new()
	spar.size = Vector3(0.60, 0.025, 0.025)
	part(spar, "493726", Vector3(0, 0.85, 0.025))
	var keel_mark := BoxMesh.new()
	keel_mark.size = Vector3(0.015, 0.025, 0.57)
	part(keel_mark, "493726", Vector3(0, 0.23, 0))
