extends CharacterBody3D
class_name CustomerNPC

enum State { ENTER, BROWSE, QUEUE, CHECKOUT, LEAVE, PUMP, STARE, GRAB, DONE }

var data: Dictionary = {}
var state: State = State.ENTER
var cart: Array = []
var nav: NavigationAgent3D
var mesh_root: Node3D
var speed: float = 2.2
# Updated for new layout: register near counter, exit toward door (+Z), pumps in lot
var register_point: Vector3 = Vector3(1.2, 0, -2.0)
var exit_point: Vector3 = Vector3(0, 0, 3)
var pump_point: Vector3 = Vector3(-3, 0, 9)
var browse_timer: float = 0.0
var is_old_man: bool = false
var is_day_clerk: bool = false
var dialogue_set: String = "normal"

signal ready_for_checkout(customer: CustomerNPC)
signal left_store(customer: CustomerNPC)

func setup(cdata: Dictionary) -> void:
	data = cdata
	dialogue_set = str(cdata.get("personality", "normal"))
	_build_body()
	nav = NavigationAgent3D.new()
	nav.path_desired_distance = 0.5
	nav.target_desired_distance = 0.6
	nav.avoidance_enabled = true
	add_child(nav)
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.65
	cs.shape = cap
	cs.position.y = 0.95
	add_child(cs)

func setup_old_man() -> void:
	is_old_man = true
	dialogue_set = "old_man"
	data = {"height": 0.95, "skin": "#d4c4a8", "clothing": "#2a2a28", "face": "face_oldman.png", "gender": "m", "age": "elder", "pants": "#1a1a1a"}
	setup(data)

func setup_day_clerk() -> void:
	is_day_clerk = true
	data = {"height": 1.0, "skin": "#e8c4a0", "clothing": "#8b3a3a", "face": "face_dayclerk.png", "gender": "f", "age": "young", "pants": "#2a2a40"}
	setup(data)

func _build_body() -> void:
	mesh_root = Node3D.new()
	mesh_root.name = "Mesh"
	add_child(mesh_root)
	var h := float(data.get("height", 1.0))
	mesh_root.scale = Vector3(h, h, h)
	var skin := Color.html(str(data.get("skin", "#c68642")))
	var cloth := Color.html(str(data.get("clothing", "#2a3a5a")))
	var pants := Color.html(str(data.get("pants", "#2a2a32")))
	if not data.has("pants"):
		pants = cloth.darkened(0.35)
	# Hips
	_box_part(Vector3(0.42, 0.22, 0.26), Vector3(0, 0.95, 0), pants)
	# Torso / shirt
	_box_part(Vector3(0.48, 0.55, 0.28), Vector3(0, 1.3, 0), cloth)
	# Shoulders
	_box_part(Vector3(0.56, 0.14, 0.26), Vector3(0, 1.55, 0), cloth)
	# Legs distinct
	for lx in [-0.12, 0.12]:
		_box_part(Vector3(0.13, 0.55, 0.14), Vector3(lx, 0.55, 0), pants)
		_box_part(Vector3(0.12, 0.28, 0.13), Vector3(lx, 0.18, 0.02), pants.darkened(0.15))
		_box_part(Vector3(0.14, 0.1, 0.22), Vector3(lx, 0.05, 0.04), Color(0.1, 0.08, 0.08))
	# Arms
	for ax in [-0.34, 0.34]:
		_box_part(Vector3(0.11, 0.28, 0.11), Vector3(ax, 1.4, 0), cloth)
		_box_part(Vector3(0.1, 0.32, 0.1), Vector3(ax, 1.1, 0.02), skin)
		_box_part(Vector3(0.09, 0.1, 0.12), Vector3(ax, 0.9, 0.04), skin)
	# Shaped head (flattened box + front face quad with texture)
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.28, 0.32, 0.26)
	head.mesh = hb
	head.position = Vector3(0, 1.78, 0)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = skin
	head.material_override = hm
	mesh_root.add_child(head)
	# Face card on front of head
	var face := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.28, 0.32)
	face.mesh = fq
	face.position = Vector3(0, 1.78, 0.135)
	var fm := StandardMaterial3D.new()
	var face_path := "res://assets/faces/%s" % str(data.get("face", "face_cust_a.png"))
	if ResourceLoader.exists(face_path):
		fm.albedo_texture = load(face_path)
	else:
		fm.albedo_color = skin
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	face.material_override = fm
	mesh_root.add_child(face)
	# Hair cap
	var hair_col := Color(0.12, 0.1, 0.08) if str(data.get("age", "")) != "elder" else Color(0.75, 0.75, 0.7)
	if is_old_man:
		hair_col = Color(0.7, 0.7, 0.68)
	_box_part(Vector3(0.3, 0.1, 0.28), Vector3(0, 1.96, -0.02), hair_col)
	if is_old_man:
		_cyl_part(0.2, 0.22, 0.12, Vector3(0, 2.0, 0), Color(0.12, 0.1, 0.08))
	if str(data.get("gender", "m")) == "f":
		# simple ponytail / longer hair
		_box_part(Vector3(0.12, 0.35, 0.1), Vector3(0, 1.7, -0.18), hair_col)

func _box_part(size: Vector3, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	mi.material_override = m
	mesh_root.add_child(mi)

func _cyl_part(rt: float, rb: float, h: float, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	mi.mesh = c
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	mi.material_override = m
	mesh_root.add_child(mi)

func start_shopping(products: Array) -> void:
	cart.clear()
	var n := 1 + randi() % 3
	for i in range(n):
		var p: Dictionary = products[randi() % products.size()]
		cart.append(p.id)
	if data.get("prefers_pump", false) and not is_old_man:
		state = State.PUMP
		browse_timer = 5.0
		_set_target(pump_point)
		EventBus.pump_customer_arrived.emit(self)
	else:
		state = State.ENTER
		_set_target(Vector3(randf_range(-2, 2), 0, -4))
		browse_timer = randf_range(3.0, 7.0)

func start_candy_visit() -> void:
	cart = ["muddybar"]
	state = State.ENTER
	_set_target(register_point)

func _set_target(pos: Vector3) -> void:
	nav.target_position = pos

func _physics_process(delta: float) -> void:
	if state == State.DONE or state == State.CHECKOUT or state == State.STARE:
		velocity = Vector3.ZERO
		return
	if nav.is_navigation_finished():
		_on_arrived(delta)
		return
	var next := nav.get_next_path_position()
	var dir := next - global_position
	dir.y = 0
	if dir.length() > 0.05:
		dir = dir.normalized()
		velocity = dir * speed
		look_at(global_position + dir, Vector3.UP)
	else:
		velocity = Vector3.ZERO
	move_and_slide()

func _on_arrived(delta: float) -> void:
	match state:
		State.ENTER:
			state = State.BROWSE
			browse_timer = randf_range(2.0, 5.0)
		State.BROWSE:
			browse_timer -= delta
			if browse_timer <= 0.0:
				state = State.QUEUE
				_set_target(register_point)
		State.QUEUE:
			state = State.CHECKOUT
			ready_for_checkout.emit(self)
			EventBus.customer_at_register.emit(self)
		State.PUMP:
			browse_timer -= delta
			if browse_timer <= 0.0:
				state = State.LEAVE
				_set_target(Vector3(40, 0, 18))
		State.LEAVE:
			state = State.DONE
			left_store.emit(self)
			EventBus.customer_left.emit(self)
			queue_free()
		State.GRAB:
			pass

func begin_leave() -> void:
	state = State.LEAVE
	_set_target(exit_point)

func force_leave_far() -> void:
	state = State.LEAVE
	_set_target(Vector3(randf_range(-2, 2), 0, 40))

func do_stare() -> void:
	state = State.STARE
	global_position = Vector3(randf_range(-4, 4), 0, 10)

func do_grab(player: Node3D) -> void:
	state = State.GRAB
	_set_target(player.global_position)
