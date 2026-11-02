extends Node3D
## Eerie Springs Gas — main entry. Builds world, runs cutscene, systems.

var world: WorldBuilder
var player: CharacterBody3D
var hud: GameHUD
var register: RegisterSystem
var director: ParanormalDirector
var spawner: CustomerSpawner
var cutscene: OpeningCutscene
var ending: EndingSequence
var security_tv: Node

func _ready() -> void:
	randomize()
	_spawn_audio_ambient()
	world = WorldBuilder.new()
	world.name = "World"
	world.add_to_group("world")
	add_child(world)
	await world.build()
	_setup_player()
	_setup_systems()
	_setup_hud()
	_setup_security_tv_logic()
	_setup_cutscene()
	EventBus.dawn_reached.connect(_on_dawn)
	# Auto-start opening
	await get_tree().process_frame
	var car: Node3D = world.find_child("PlayerCar", true, false)
	cutscene.run(car, player)

func _setup_player() -> void:
	player = CharacterBody3D.new()
	player.set_script(load("res://scripts/player/player.gd"))
	player.name = "Player"
	add_child(player)
	player.position = Vector3(0, 0.1, 2)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	pivot.position = Vector3(0, 1.6, 0)
	player.add_child(pivot)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 75
	cam.near = 0.05
	pivot.add_child(cam)
	var fl := SpotLight3D.new()
	fl.name = "Flashlight"
	fl.light_color = Color(1.0, 0.95, 0.8)
	fl.light_energy = 2.5
	fl.spot_range = 14.0
	fl.spot_angle = 35.0
	fl.shadow_enabled = true
	pivot.add_child(fl)
	var ray := RayCast3D.new()
	ray.name = "InteractRay"
	ray.target_position = Vector3(0, 0, -2.5)
	ray.collision_mask = 9  # world + interactable
	ray.enabled = true
	pivot.add_child(ray)
	var scanner := MeshInstance3D.new()
	scanner.name = "Scanner"
	var sm := BoxMesh.new()
	sm.size = Vector3(0.05, 0.025, 0.14)
	scanner.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.15, 0.15, 0.18)
	scanner.material_override = smat
	scanner.position = Vector3(0.28, -0.22, -0.35)
	pivot.add_child(scanner)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	cs.shape = cap
	cs.position.y = 0.9
	player.add_child(cs)
	var rtimer := Timer.new()
	rtimer.name = "RemarkTimer"
	player.add_child(rtimer)
	player.collision_layer = 2
	player.collision_mask = 1
	player.wire_nodes()

func _setup_systems() -> void:
	register = RegisterSystem.new()
	register.name = "Register"
	add_child(register)
	director = ParanormalDirector.new()
	director.name = "Director"
	add_child(director)
	spawner = CustomerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.setup(register)
	ending = EndingSequence.new()
	ending.name = "Ending"
	add_child(ending)

func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	layer.set_script(load("res://scripts/ui/hud.gd"))
	layer.name = "HUD"
	add_child(layer)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	# Clock top-left, compact
	var clock := Label.new()
	clock.name = "Clock"
	clock.position = Vector2(18, 14)
	clock.add_theme_font_size_override("font_size", 18)
	clock.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	clock.add_theme_constant_override("shadow_offset_x", 1)
	clock.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(clock)

	# Objective top-center
	var obj := Label.new()
	obj.name = "Objective"
	obj.set_anchors_preset(Control.PRESET_TOP_WIDE)
	obj.offset_top = 12
	obj.offset_bottom = 40
	obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	obj.add_theme_font_size_override("font_size", 20)
	obj.modulate = Color(1.0, 0.92, 0.55)
	obj.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	obj.add_theme_constant_override("shadow_offset_x", 1)
	obj.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(obj)

	# Chores panel (Tab) — left side, hidden by default
	var cp := PanelContainer.new()
	cp.name = "ChoresPanel"
	cp.position = Vector2(16, 56)
	cp.size = Vector2(300, 220)
	cp.modulate = Color(1, 1, 1, 0.92)
	root.add_child(cp)
	var chores := Label.new()
	chores.name = "Chores"
	chores.add_theme_font_size_override("font_size", 15)
	cp.add_child(chores)

	# Tab hint tiny
	var tabhint := Label.new()
	tabhint.name = "TabHint"
	tabhint.text = "Tab · chores"
	tabhint.position = Vector2(18, 42)
	tabhint.add_theme_font_size_override("font_size", 12)
	tabhint.modulate = Color(0.75, 0.75, 0.7, 0.65)
	root.add_child(tabhint)

	var hint := Label.new()
	hint.name = "Hint"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -70
	hint.offset_bottom = -40
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 17)
	hint.modulate = Color(1, 1, 1, 0)
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(hint)

	var prompt := Label.new()
	prompt.name = "Prompt"
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_top = -100
	prompt.offset_bottom = -78
	prompt.offset_left = -220
	prompt.offset_right = 220
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	prompt.add_theme_constant_override("shadow_offset_x", 1)
	prompt.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(prompt)

	var sub := Label.new()
	sub.name = "Subtitle"
	sub.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sub.offset_top = -130
	sub.offset_bottom = -100
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	sub.add_theme_constant_override("shadow_offset_x", 1)
	sub.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(sub)

	var remark := Label.new()
	remark.name = "Remark"
	remark.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	remark.offset_top = -155
	remark.offset_bottom = -132
	remark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	remark.modulate = Color(0.75, 0.88, 1.0)
	remark.add_theme_font_size_override("font_size", 15)
	root.add_child(remark)

	var rp := PanelContainer.new()
	rp.name = "RegisterPanel"
	rp.set_anchors_preset(Control.PRESET_CENTER)
	rp.offset_left = -240
	rp.offset_right = 240
	rp.offset_top = -170
	rp.offset_bottom = 170
	root.add_child(rp)
	var wrap := VBoxContainer.new()
	rp.add_child(wrap)
	var rtitle := Label.new()
	rtitle.text = "CASH REGISTER"
	rtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wrap.add_child(rtitle)
	var items := Label.new(); items.name = "Items"; wrap.add_child(items)
	var total := Label.new(); total.name = "Total"; wrap.add_child(total)
	var change := Label.new(); change.name = "Change"; wrap.add_child(change)
	var scan := Button.new(); scan.name = "ScanBtn"; scan.text = "Scan Item (LMB)"; wrap.add_child(scan)
	var cb := HBoxContainer.new(); cb.name = "ChangeButtons"; wrap.add_child(cb)

	var np := PanelContainer.new()
	np.name = "NotePanel"
	np.set_anchors_preset(Control.PRESET_CENTER)
	np.offset_left = -260
	np.offset_right = 260
	np.offset_top = -220
	np.offset_bottom = 220
	root.add_child(np)
	var nt := Label.new()
	nt.name = "NoteText"
	nt.autowrap_mode = TextServer.AUTOWRAP_WORD
	np.add_child(nt)

	var pp := PanelContainer.new()
	pp.name = "PausePanel"
	pp.set_anchors_preset(Control.PRESET_CENTER)
	pp.offset_left = -180
	pp.offset_right = 180
	pp.offset_top = -110
	pp.offset_bottom = 110
	root.add_child(pp)
	var pv := VBoxContainer.new()
	pp.add_child(pv)
	var pl := Label.new(); pl.text = "PAUSED — Settings"; pv.add_child(pl)
	var hc := CheckButton.new(); hc.name = "HintsToggle"; hc.text = "Onboarding hints"; hc.button_pressed = true; pv.add_child(hc)
	var quit_hint := Label.new(); quit_hint.text = "Esc resume · H hints · T time · Tab chores"; pv.add_child(quit_hint)

	var tv := TextureRect.new()
	tv.name = "TVOverlay"
	tv.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tv.offset_left = -260
	tv.offset_top = 56
	tv.offset_right = -24
	tv.offset_bottom = 220
	tv.stretch_mode = TextureRect.STRETCH_SCALE
	if ResourceLoader.exists("res://assets/textures/creature.png"):
		tv.texture = load("res://assets/textures/creature.png")
	tv.visible = false
	root.add_child(tv)

	var ec := PanelContainer.new()
	ec.name = "EndCard"
	ec.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(ec)
	var el := Label.new()
	el.text = "EERIE SPRINGS GAS\n\nEpisode 1\n\nJake drove into the sunrise.\nThe forest kept its secrets.\n\nThanks for playing.\n\n— End —"
	el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	el.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	el.set_anchors_preset(Control.PRESET_FULL_RECT)
	el.add_theme_font_size_override("font_size", 28)
	ec.add_child(el)
	ec.visible = false

	hud = layer
	await get_tree().process_frame
	hud.setup_from_tree()
	hud.bind_register(register)

func _setup_cutscene() -> void:
	cutscene = OpeningCutscene.new()
	cutscene.name = "Cutscene"
	add_child(cutscene)
	var cutcam := Camera3D.new()
	cutcam.name = "CutCam"
	cutscene.add_child(cutcam)

func _setup_security_tv_logic() -> void:
	# Creature only shows when player is NOT looking at the TV area
	EventBus.creature_on_tv.connect(func(vis: bool):
		if not vis:
			return
		# If looking toward counter TV, hide immediately
		var check := func():
			if player == null:
				return
			var cam: Camera3D = player.get_node_or_null("Pivot/Camera3D")
			if cam == null:
				return
			var tv_pos := Vector3(3.2, 1.45, -1.35)
			var to_tv := (tv_pos - cam.global_position).normalized()
			var look := -cam.global_transform.basis.z
			if look.dot(to_tv) > 0.82:
				EventBus.creature_on_tv.emit(false)
				director.creature_visible = false
		# poll briefly
		for i in range(20):
			get_tree().create_timer(0.1 * i).timeout.connect(check)
	)

func _on_dawn() -> void:
	var car: Node3D = world.find_child("PlayerCar", true, false)
	await ending.play(player, car, self)

func _spawn_audio_ambient() -> void:
	if ResourceLoader.exists("res://assets/audio/ambient_forest.wav"):
		var a := AudioStreamPlayer.new()
		a.stream = load("res://assets/audio/ambient_forest.wav")
		a.autoplay = true
		a.volume_db = -6
		add_child(a)
		# loop manually
		a.finished.connect(func(): a.play())
	if ResourceLoader.exists("res://assets/audio/fluorescent_hum.wav"):
		var h := AudioStreamPlayer.new()
		h.stream = load("res://assets/audio/fluorescent_hum.wav")
		h.autoplay = true
		h.volume_db = -12
		add_child(h)
		h.finished.connect(func(): h.play())
