extends "res://scripts/ship_visual.gd"

var origin := Vector3.ZERO
var destination := Vector3.ZERO
var shot := "ball"
var age := 0.0
var duration := 0.7
var impacted := false
var projectile := Node3D.new()
var flash: MeshInstance3D
var smoke: MeshInstance3D
var burst: MeshInstance3D

func orb(radius: float, color: String, at: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	return part(mesh, color, at)

func _ready() -> void:
	add_child(projectile)
	var count := 7 if shot in ["grape", "canister"] else 2 if shot in ["chain", "bar"] else 1
	for i in count:
		var ball := orb(0.045 if count > 2 else 0.075, "322d26", Vector3.ZERO)
		ball.reparent(projectile)
		ball.position = Vector3((i - (count - 1) * 0.5) * 0.10, 0, sin(i * 2.0) * 0.07)
	if shot in ["chain", "bar"]:
		var link := BoxMesh.new()
		link.size = Vector3(0.16, 0.018, 0.018)
		var bar := part(link, "514734", Vector3.ZERO)
		bar.reparent(projectile)
	flash = orb(0.2, "ffd78a", origin)
	smoke = orb(0.16, "b9b49d", origin)
	burst = orb(0.1, "d5e4d0", destination)
	burst.hide()
	projectile.position = origin

# Return true exactly once, at contact; gameplay and visual timing share this clock.
func advance(delta: float) -> bool:
	age += delta
	var t := clampf(age / duration, 0, 1)
	projectile.position = origin.lerp(destination, t) + Vector3.UP * sin(t * PI) * (0.8 if shot == "bomb" else 0.16)
	projectile.rotation.z = t * TAU * 2
	flash.visible = age < 0.14
	smoke.position = origin + Vector3.UP * age * 0.3
	smoke.scale = Vector3.ONE * (1.0 + age * 2.5)
	smoke.visible = age < 0.65
	if t >= 1:
		projectile.hide()
		burst.show()
		burst.scale = Vector3.ONE * (1 + (age - duration) * 8)
		burst.scale.y = 0.4
		if shot == "bomb": burst.material_override.albedo_color = Color("e8ab53")
		if not impacted:
			impacted = true
			return true
	return false
