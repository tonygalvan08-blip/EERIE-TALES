extends Node
class_name EndingSequence

signal finished

func play(player: Node3D, car: Node3D, world: Node3D) -> void:
	GameState.phase = "ending"
	EventBus.ending_started.emit()
	if player.has_method("disable_control"):
		player.disable_control()
	# Dawn lighting
	_dawn_lights(world)
	# Spawn day clerk
	var clerk := CustomerNPC.new()
	clerk.name = "DayClerk"
	world.add_child(clerk)
	clerk.global_position = Vector3(0, 0, 1.5)
	clerk.setup_day_clerk()
	await get_tree().create_timer(0.5).timeout
	EventBus.dialogue_line.emit("Day Clerk", "Damn Jake, you look like hell...")
	await get_tree().create_timer(2.5).timeout
	# Jake ignores her — walk to car (scripted)
	var tween := create_tween()
	tween.tween_property(player, "global_position", car.global_position + Vector3(-2.0, 0, 0.5), 3.0)
	await tween.finished
	_sfx("res://assets/audio/car_door.wav")
	await get_tree().create_timer(0.5).timeout
	player.visible = false
	# Drive off into sunrise
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(12, 5, 22)
	var drive := create_tween()
	drive.tween_property(car, "global_position", Vector3(-80, 0, 18), 8.0).set_ease(Tween.EASE_IN)
	drive.parallel().tween_method(func(_t):
		cam.look_at(car.global_position + Vector3(0, 1, 0), Vector3.UP)
	, 0.0, 1.0, 8.0)
	await drive.finished
	EventBus.ending_finished.emit()
	finished.emit()

func _dawn_lights(world: Node) -> void:
	for n in world.get_children():
		if n is DirectionalLight3D:
			n.light_color = Color(1.0, 0.75, 0.45)
			n.light_energy = 0.85
			n.rotation_degrees = Vector3(-15, 180, 0)
	var env_nodes := world.get_tree().get_nodes_in_group("")
	for n in world.get_children():
		if n is WorldEnvironment and n.environment:
			n.environment.fog_density = 0.008
			n.environment.background_color = Color(0.55, 0.45, 0.35)
			n.environment.ambient_light_color = Color(0.8, 0.6, 0.4)
			n.environment.ambient_light_energy = 0.6

func _sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
