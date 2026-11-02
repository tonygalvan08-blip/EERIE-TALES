extends CharacterBody3D
class_name PlayerController

const SPEED := 3.6
const SPRINT := 5.2
const MOUSE_SENS := 0.0022

var pivot: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var ray: RayCast3D
var scanner_mesh: MeshInstance3D

var enabled: bool = false
var flashlight_on: bool = false
var focused: Node = null
var _yaw := 0.0
var _pitch := 0.0
var _wired: bool = false

func wire_nodes() -> void:
	pivot = $Pivot
	camera = $Pivot/Camera3D
	flashlight = $Pivot/Flashlight
	ray = $Pivot/InteractRay
	scanner_mesh = $Pivot/Scanner
	flashlight.visible = false
	scanner_mesh.visible = true
	_wired = true
	add_to_group("player")

func enable_control() -> void:
	enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if camera:
		camera.current = true
	EventBus.player_ready.emit()

func disable_control() -> void:
	enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not _wired:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch -= event.relative.y * MOUSE_SENS
		_pitch = clampf(_pitch, -1.2, 1.2)
		rotation.y = _yaw
		pivot.rotation.x = _pitch
	if event.is_action_pressed("flashlight"):
		flashlight_on = not flashlight_on
		flashlight.visible = flashlight_on
	if event.is_action_pressed("interact"):
		_try_interact()

func _physics_process(delta: float) -> void:
	if not enabled or not _wired:
		velocity = Vector3.ZERO
		return
	var input := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var spd := SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		spd = SPRINT
	if direction != Vector3.ZERO:
		velocity.x = direction.x * spd
		velocity.z = direction.z * spd
	else:
		velocity.x = move_toward(velocity.x, 0, spd)
		velocity.z = move_toward(velocity.z, 0, spd)
	velocity.y -= 20.0 * delta
	move_and_slide()
	_update_focus()

func _update_focus() -> void:
	if ray.is_colliding():
		var col := ray.get_collider()
		var target = col
		if col and not col.has_method("get_interact_label") and col.get_parent() and col.get_parent().has_method("get_interact_label"):
			target = col.get_parent()
		if target and target.has_method("get_interact_label"):
			var lab: String = target.get_interact_label()
			if lab == "":
				if focused:
					focused = null
					EventBus.interactable_unfocused.emit()
				return
			if focused != target:
				focused = target
				EventBus.interactable_focused.emit(lab)
			return
	if focused:
		focused = null
		EventBus.interactable_unfocused.emit()

func _try_interact() -> void:
	if focused and focused.has_method("interact"):
		focused.interact(self)

func remark(key: String) -> void:
	var remarks: Dictionary = GameState.dialogue.get("jake_remarks", {})
	var text: String = str(remarks.get(key, ""))
	if text != "":
		EventBus.jake_remark.emit(text)

func get_camera() -> Camera3D:
	return camera
