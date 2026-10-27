class_name CrewProp
extends Node3D
# A crew member standing in the field: a simple figure, look only. No collision,
# so the drone and debris pass through it; the HazardZone around it does the work.

@export var color := Color(0.3, 0.6, 0.9)
@export var height := 1.75

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var body := CapsuleMesh.new()
	body.radius = 0.22
	body.height = height * 0.78
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	for part in [[body, height * 0.39], [head, height * 0.88]]:
		var mi := MeshInstance3D.new()
		mi.mesh = part[0]
		mi.material_override = mat
		mi.position.y = part[1]
		add_child(mi)
