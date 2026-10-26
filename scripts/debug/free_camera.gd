extends Camera3D
# Debug free camera. Right-drag to look, middle-drag to pan, wheel to dolly.

@export var look_speed := 0.005
@export var pan_speed := 0.02
@export var dolly_step := 1.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			rotation.y -= event.relative.x * look_speed
			rotation.x = clampf(rotation.x - event.relative.y * look_speed, -1.5, 1.5)
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			translate(Vector3(-event.relative.x, event.relative.y, 0) * pan_speed)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			translate(Vector3(0, 0, -dolly_step))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			translate(Vector3(0, 0, dolly_step))
