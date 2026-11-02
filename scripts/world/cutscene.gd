extends Node3D
class_name OpeningCutscene
## Car drives along the east-west road, turns into the lot, parks, Jake gets out → FPS.

signal finished

var cam: Camera3D
var car: Node3D
var player: Node3D
var playing: bool = false

func run(car_node: Node3D, player_node: Node3D) -> void:
	car = car_node
	player = player_node
	playing = true
	cam = get_node_or_null("CutCam") as Camera3D
	if cam == null:
		cam = Camera3D.new()
		cam.name = "CutCam"
		add_child(cam)
	cam.current = true
	if player.has_method("disable_control"):
		player.disable_control()
	player.visible = false
	# Start far east on the road (z≈18), driving west, then turn into lot
	car.global_position = Vector3(45, 0, 18)
	car.rotation_degrees = Vector3(0, -90, 0)  # facing -X
	cam.global_position = Vector3(30, 5, 28)
	cam.look_at(car.global_position + Vector3(0, 1, 0), Vector3.UP)
	_sfx("res://assets/audio/car_idle.wav")
	var tween := create_tween()
	# Drive west along road toward lot entrance
	tween.tween_property(car, "global_position", Vector3(8, 0, 18), 3.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_method(func(t):
		cam.global_position = Vector3(lerpf(30, 16, t), 5, lerpf(28, 24, t))
		if is_instance_valid(car):
			cam.look_at(car.global_position + Vector3(0, 1, 0), Vector3.UP)
	, 0.0, 1.0, 3.5)
	await tween.finished
	# Turn into lot (rotate toward -Z / store) and park
	var tween2 := create_tween()
	tween2.tween_property(car, "rotation_degrees:y", -20.0, 0.8)
	tween2.parallel().tween_property(car, "global_position", Vector3(5.5, 0, 4.5), 2.2).set_ease(Tween.EASE_OUT)
	tween2.parallel().tween_method(func(t):
		cam.global_position = Vector3(lerpf(16, 12, t), lerpf(5, 4, t), lerpf(24, 14, t))
		if is_instance_valid(car):
			cam.look_at(car.global_position + Vector3(0, 1, 0), Vector3.UP)
	, 0.0, 1.0, 2.2)
	await tween2.finished
	_sfx("res://assets/audio/car_door.wav")
	await get_tree().create_timer(0.55).timeout
	player.global_position = car.global_position + Vector3(-2.0, 0, 0.3)
	player.rotation.y = deg_to_rad(160)  # face toward store roughly
	player.visible = true
	var eye := player.global_position + Vector3(0, 1.6, 0)
	var tween3 := create_tween()
	tween3.tween_property(cam, "global_position", eye, 1.1).set_ease(Tween.EASE_IN_OUT)
	tween3.parallel().tween_method(func(_t):
		cam.look_at(eye + Vector3(-0.2, 0, -1), Vector3.UP)
	, 0.0, 1.0, 1.1)
	await tween3.finished
	playing = false
	if player.has_method("enable_control"):
		player.enable_control()
	cam.current = false
	finished.emit()
	EventBus.cutscene_finished.emit()
	GameState.phase = "play"

func _sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
