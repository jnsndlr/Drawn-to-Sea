extends "res://scripts/ship_visual.gd"

var health := 60
var number := 1
var label: Label3D
var age := 0.0
var sinking := 0.0

func box(at: Vector3, dimensions: Vector3, color: String) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part(mesh, color, at)

func _ready() -> void:
	for i in 5:
		box(Vector3((i - 2) * 0.14, 0.10, 0), Vector3(0.125, 0.12, 0.8), "81613e")
	for z in [-0.27, 0.27]:
		box(Vector3(0, 0.18, z), Vector3(0.76, 0.035, 0.035), "d4bb81")
	for x in [-0.18, 0.18]:
		var barrel := CylinderMesh.new()
		barrel.top_radius = 0.10
		barrel.bottom_radius = 0.10
		barrel.height = 0.29
		part(barrel, "987447", Vector3(x, 0.32, 0.1))
		for y in [0.23, 0.40]:
			var hoop := CylinderMesh.new()
			hoop.top_radius = 0.106
			hoop.bottom_radius = 0.106
			hoop.height = 0.025
			part(hoop, "403c31", Vector3(x, y, 0.1))
		box(Vector3(x, 0.47, 0.1), Vector3(0.025, 0.02, 0.24), "dbc48d")
	box(Vector3(0, 0.52, -0.23), Vector3(0.025, 0.83, 0.025), "493726")
	var sail := ImmediateMesh.new()
	sail.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(0.02, 0.92, -0.23), Vector3(0.34, 0.51, -0.23), Vector3(0.02, 0.51, -0.23)]:
		sail.surface_add_vertex(v)
	sail.surface_end()
	part(sail, "e5d6aa", Vector3.ZERO)
	box(Vector3(0.12, 0.64, -0.245), Vector3(0.075, 0.08, 0.01), "9d4936")
	label = Label3D.new()
	label.position.y = 1.15
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 28
	label.pixel_size = 0.008
	label.modulate = Color("f2dfb2")
	add_child(label)
	update_label()

func update_label() -> void:
	label.text = "RAFT %d  ·  %d/60" % [number, health] if health > 0 else "SUNK"

func hit(damage: int) -> void:
	health = maxi(0, health - damage)
	update_label()

func advance(delta: float) -> void:
	age += delta
	if health <= 0:
		sinking += delta
		position.y = -sinking * 0.45
		rotation.z = sinking * 0.35
		if sinking > 2.8: hide()
	else:
		position.y = 0.035 + sin(age * 1.7 + number) * 0.025
		rotation.z = sin(age * 1.3 + number) * 0.035
