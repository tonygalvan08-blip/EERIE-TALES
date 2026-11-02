extends Node
const OUT := "/workspace/eerie_springs/screenshots"

func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	GameState.debug_fast = true
	GameState.time_scale = 80.0
	var packed = load("res://scenes/main.tscn")
	var main = packed.instantiate()
	get_tree().root.add_child(main)
	await get_tree().create_timer(2.2).timeout
	await _shot("01_cutscene_or_lot.png")

	GameState.phase = "play"
	if main.cutscene:
		# Abort opening cutscene so its tweens cannot teleport the player mid-shoot
		main.cutscene.playing = false
		if main.cutscene.cam:
			main.cutscene.cam.current = false
		main.cutscene.queue_free()
		main.cutscene = null
		await get_tree().process_frame
	var pl = main.player
	pl.visible = true
	if pl.has_method("enable_control"):
		pl.enable_control()
	pl.camera.current = true
	if pl.scanner_mesh:
		pl.scanner_mesh.visible = false

	# Interior looking down aisle toward coolers; slight angle to show stocked shelves
	pl.global_position = Vector3(-0.3, 0.1, -1.0)
	pl.rotation.y = deg_to_rad(12)
	pl.pivot.rotation.x = deg_to_rad(-6)
	await get_tree().process_frame
	await _shot("02_store_interior.png")

	# Register counter from customer side
	pl.global_position = Vector3(1.0, 0.1, -0.4)
	pl.rotation.y = deg_to_rad(-40)
	pl.pivot.rotation.x = deg_to_rad(-8)
	await get_tree().process_frame
	await _shot("03_register_area.png")

	if main.register:
		var dummy = Node.new(); add_child(dummy)
		main.register.start_transaction(dummy, ["cornbites", "fizzrite", "muddybar"])
		main.register.scan_next()
		main.register.scan_next()
		await get_tree().process_frame
		await _shot("04_register_ui.png")
		main.register.give_correct_auto()

	# Exterior: under canopy looking at storefront (toward -Z)
	pl.global_position = Vector3(0.0, 0.1, 11.5)
	pl.rotation.y = 0.0
	pl.pivot.rotation.x = deg_to_rad(-6)
	await get_tree().process_frame
	await _shot("05_pumps_exterior.png")

	# Forest road: on centerline looking west — lamps, dashes, trees vanishing into fog
	pl.global_position = Vector3(22.0, 0.1, 18.0)
	pl.rotation.y = deg_to_rad(-90)
	pl.pivot.rotation.x = deg_to_rad(-3)
	await get_tree().process_frame
	await _shot("06_forest_road.png")

	EventBus.creature_on_tv.emit(true)
	pl.global_position = Vector3(2.4, 0.1, -0.7)
	pl.rotation.y = deg_to_rad(-30)
	pl.pivot.rotation.x = deg_to_rad(-10)
	await get_tree().process_frame
	await _shot("07_security_tv_creature.png")
	EventBus.creature_on_tv.emit(false)

	# Cooler close-up from center aisle (avoid gondola collision at x≈-2.2)
	pl.global_position = Vector3(-0.8, 0.1, -7.6)
	pl.rotation.y = deg_to_rad(15)
	pl.pivot.rotation.x = deg_to_rad(-8)
	await get_tree().process_frame
	await _shot("09_cooler_wall.png")

	# NPC at register
	var cust = CustomerNPC.new()
	main.add_child(cust)
	# Customer on aisle side of counter; clerk (player) behind register looking +Z at them
	cust.global_position = Vector3(1.6, 0.0, -0.85)
	cust.setup(GameState.customers_data[0] if GameState.customers_data.size() else {"height":1.0,"skin":"#c68642","clothing":"#2a3a5a","face":"face_cust_a.png","gender":"m"})
	cust.rotation.y = PI  # face quad on +Z → world -Z toward clerk
	pl.global_position = Vector3(1.6, 0.1, -2.55)
	pl.rotation.y = PI  # look toward +Z at customer
	pl.pivot.rotation.x = deg_to_rad(-10)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("10_npc_at_register.png")
	cust.queue_free()

	EventBus.ending_finished.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("08_ending_card.png")
	print("Screenshots written to ", OUT)
	get_tree().quit(0)

func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(OUT.path_join(name))
	print("Saved ", name)
