extends Node3D
class_name WorldBuilder
## Eerie Springs Gas world.
## Layout (Z forward toward road):
##   Store interior z in [-10, 0], front door at z≈0 facing +Z
##   Lot + pumps/canopy z in [2, 14]
##   Road runs PARALLEL along X at z≈18 (east-west), never through the store
##   Forest surrounds everything; road vanishes into fog both ±X

signal build_finished

var mats: Dictionary = {}
var nav_mesh_instance: NavigationRegion3D

func build() -> void:
	_load_mats()
	nav_mesh_instance = NavigationRegion3D.new()
	nav_mesh_instance.name = "NavRegion"
	add_child(nav_mesh_instance)
	var root := Node3D.new()
	root.name = "WorldRoot"
	nav_mesh_instance.add_child(root)
	_build_environment()
	_build_ground(root)
	_build_road(root)
	_build_forest(root)
	_build_canopy_and_pumps(root)
	_build_store(root)
	_build_exterior_props(root)
	await _bake_nav()
	build_finished.emit()

func _tex(name: String) -> Texture2D:
	return load("res://assets/textures/%s" % name) as Texture2D

func _mat(name: String, tex_name: String, rough := 0.85, metal := 0.0, uv := 1.0) -> StandardMaterial3D:
	if mats.has(name):
		return mats[name]
	var m := StandardMaterial3D.new()
	var t := _tex(tex_name)
	if t:
		m.albedo_texture = t
		m.uv1_scale = Vector3(uv, uv, uv)
	m.roughness = rough
	m.metallic = metal
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats[name] = m
	return m

func _mat_color(name: String, color: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	if mats.has(name):
		return mats[name]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	mats[name] = m
	return m

func _mat_alpha(name: String, tex_name: String) -> StandardMaterial3D:
	if mats.has(name):
		return mats[name]
	var m := StandardMaterial3D.new()
	var t := _tex(tex_name)
	if t:
		m.albedo_texture = t
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mats[name] = m
	return m

func _load_mats() -> void:
	_mat("asphalt", "asphalt.png", 0.95, 0.0, 10.0)
	_mat("lino", "linoleum.png", 0.72, 0.0, 8.0)
	_mat("ceiling", "ceiling_tile.png", 0.9, 0.0, 4.0)
	_mat("siding", "store_siding.png", 0.75, 0.0, 2.5)
	_mat("canopy", "canopy.png", 0.55, 0.15, 2.0)
	_mat("fascia", "canopy_fascia.png", 0.5, 0.1, 1.0)
	_mat("brick", "brick.png", 0.9, 0.0, 2.0)
	_mat("wall", "wall_paint.png", 0.88, 0.0, 2.0)
	_mat("wood", "wood.png", 0.8, 0.0, 1.5)
	_mat("metal", "metal.png", 0.35, 0.7, 1.0)
	_mat("bark", "bark.png", 0.95, 0.0, 1.0)
	_mat("counter", "counter.png", 0.6, 0.0, 1.5)
	_mat("grass", "grass.png", 0.95, 0.0, 12.0)
	_mat("pump", "gas_pump.png", 0.45, 0.35, 1.0)
	_mat("baseboard", "baseboard.png", 0.85, 0.0, 1.0)
	_mat("door", "door.png", 0.5, 0.4, 1.0)
	_mat("price", "price_sign.png", 0.6, 0.0, 1.0)
	_mat("storesign", "sign_eerie.png", 0.55, 0.0, 1.0)
	_mat_alpha("leaf", "leaf_card.png")
	_mat_alpha("pine", "pine_card.png")
	var g := _mat("glass", "storefront_glass.png", 0.05, 0.0, 1.0)
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g.albedo_color = Color(0.55, 0.7, 0.8, 0.28)
	g.metallic = 0.2

func _box(parent: Node, size: Vector3, pos: Vector3, mat: Material, name := "Box", collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi

func _mesh(parent: Node, size: Vector3, pos: Vector3, mat: Material, name := "Prop") -> MeshInstance3D:
	return _box(parent, size, pos, mat, name, false)

func _cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, mat: Material, name := "Cyl", rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi

func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.008, 0.01, 0.02)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.06, 0.08, 0.1)
	e.ambient_light_energy = 0.4
	e.fog_enabled = true
	e.fog_light_color = Color(0.08, 0.1, 0.12)
	e.fog_density = 0.007
	e.fog_aerial_perspective = 0.55
	e.fog_sun_scatter = 0.05
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 1.0
	e.tonemap_white = 1.2
	e.glow_enabled = true
	e.glow_intensity = 0.25
	e.glow_bloom = 0.08
	e.ssao_enabled = true
	e.ssao_radius = 1.4
	e.ssao_intensity = 1.2
	e.ssil_enabled = false  # too expensive on software GL
	env.environment = e
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.55, 0.75)
	moon.light_energy = 0.55
	moon.shadow_enabled = false
	moon.rotation_degrees = Vector3(-40, 50, 0)
	add_child(moon)

func _build_ground(root: Node) -> void:
	_box(root, Vector3(160, 0.2, 160), Vector3(0, -0.1, 0), mats["grass"], "Ground")
	# Lot pad between store front (z=0) and road (z≈18)
	_box(root, Vector3(32, 0.12, 16), Vector3(0, 0.02, 8), mats["asphalt"], "Lot")

func _build_road(root: Node) -> void:
	# East-west road PARALLEL to storefront, in front of the lot
	var road_z := 18.0
	_box(root, Vector3(200, 0.1, 7.5), Vector3(0, 0.04, road_z), mats["asphalt"], "Road")
	# Yellow center dashes along X (never enter store)
	var dash := BoxMesh.new()
	dash.size = Vector3(2.2, 0.04, 0.18)
	var mm := MultiMeshInstance3D.new()
	mm.name = "RoadDashes"
	var mult := MultiMesh.new()
	mult.transform_format = MultiMesh.TRANSFORM_3D
	mult.mesh = dash
	var count := 70
	mult.instance_count = count
	for i in range(count):
		var x := -90.0 + i * 2.6
		mult.set_instance_transform(i, Transform3D(Basis(), Vector3(x, 0.1, road_z)))
	mm.multimesh = mult
	mm.material_override = _mat_color("yellow_line", Color(0.92, 0.82, 0.18))
	root.add_child(mm)
	# White edge lines
	for side in [-3.4, 3.4]:
		_mesh(root, Vector3(200, 0.03, 0.12), Vector3(0, 0.1, road_z + side), _mat_color("white_line", Color(0.9, 0.9, 0.88)), "EdgeLine")
	# Road lamps both sides so the highway reads in fog both directions
	for i in range(10):
		var x := -70.0 + i * 16.0
		for side in [-5.2, 5.2]:
			_box(root, Vector3(0.18, 6.5, 0.18), Vector3(x, 3.25, road_z + side), mats["metal"], "RoadLamp", false)
			_mesh(root, Vector3(0.5, 0.12, 0.35), Vector3(x, 6.4, road_z + side), _mat_color("lamphead", Color(0.3, 0.3, 0.32)), "LampHead")
			var rl := OmniLight3D.new()
			rl.light_color = Color(1.0, 0.92, 0.7)
			rl.light_energy = 4.5
			rl.omni_range = 22.0
			rl.omni_attenuation = 1.1
			rl.position = Vector3(x, 6.2, road_z + side)
			root.add_child(rl)

func _build_forest(root: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var trunk_m := CylinderMesh.new()
	trunk_m.top_radius = 0.18
	trunk_m.bottom_radius = 0.32
	trunk_m.height = 5.5
	var trunks := MultiMeshInstance3D.new()
	trunks.name = "Trunks"
	var tm := MultiMesh.new()
	tm.transform_format = MultiMesh.TRANSFORM_3D
	tm.mesh = trunk_m
	var positions: Array[Vector3] = []
	# Dense fill around the property
	for i in range(420):
		var x := rng.randf_range(-75, 75)
		var z := rng.randf_range(-60, 75)
		# Keep clear of lot, road corridor, and store
		if absf(x) < 18.0 and z > -14.0 and z < 24.0:
			continue
		if absf(z - 18.0) < 4.5 and absf(x) < 55.0:
			continue
		positions.append(Vector3(x, 0, z))
	# Extra dense belts right along the road (both sides) so forest reads in shot 06
	for i in range(90):
		var x := rng.randf_range(-55, 55)
		var z := 18.0 + rng.randf_range(5.0, 14.0) * (1.0 if i % 2 == 0 else -1.0)
		if absf(x) < 14.0 and z < 14.0 and z > 2.0:
			continue  # don't plant in lot
		positions.append(Vector3(x, 0, z))
	tm.instance_count = positions.size()
	for i in range(positions.size()):
		var p: Vector3 = positions[i]
		var s := rng.randf_range(0.75, 1.6)
		var yaw := rng.randf() * TAU
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(s, s * rng.randf_range(0.9, 1.35), s))
		tm.set_instance_transform(i, Transform3D(basis, p + Vector3(0, 2.7 * s, 0)))
	trunks.multimesh = tm
	trunks.material_override = mats["bark"]
	root.add_child(trunks)
	# Layered conifer cones (slight emission so they read at night)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 1.7
	cone.height = 3.3
	var cones := MultiMeshInstance3D.new()
	var cm := MultiMesh.new()
	cm.transform_format = MultiMesh.TRANSFORM_3D
	cm.mesh = cone
	var cone_xfs: Array[Transform3D] = []
	for i in range(positions.size()):
		if i % 2 == 0:
			var p: Vector3 = positions[i]
			var s := rng.randf_range(0.85, 1.45)
			for layer in range(3):
				var y := 3.3 * s + layer * 1.15 * s
				var sc := s * (1.0 - layer * 0.22)
				cone_xfs.append(Transform3D(Basis.from_scale(Vector3(sc, sc, sc)), p + Vector3(0, y, 0)))
	cm.instance_count = cone_xfs.size()
	for i in range(cone_xfs.size()):
		cm.set_instance_transform(i, cone_xfs[i])
	cones.multimesh = cm
	var pine_m := _mat_color("pine_green", Color(0.22, 0.42, 0.24))
	pine_m.emission_enabled = true
	pine_m.emission = Color(0.04, 0.1, 0.05)
	pine_m.emission_energy_multiplier = 0.35
	cones.material_override = pine_m
	cones.name = "ConiferFoliage"
	root.add_child(cones)
	# Deciduous leaf billboards (cross quads) + extra pine cards
	var quad := QuadMesh.new()
	quad.size = Vector2(3.4, 2.8)
	var leaves := MultiMeshInstance3D.new()
	leaves.name = "DeciduousLeaves"
	var lm := MultiMesh.new()
	lm.transform_format = MultiMesh.TRANSFORM_3D
	lm.mesh = quad
	var leaf_xfs: Array[Transform3D] = []
	for i in range(positions.size()):
		if i % 2 == 1:
			var p: Vector3 = positions[i]
			var s := rng.randf_range(0.95, 1.55)
			var y := 5.1 * s
			for ang in [0.0, 60.0, 120.0]:
				var b := Basis(Vector3.UP, deg_to_rad(ang)).scaled(Vector3(s, s, s))
				leaf_xfs.append(Transform3D(b, p + Vector3(0, y, 0)))
	lm.instance_count = leaf_xfs.size()
	for i in range(leaf_xfs.size()):
		lm.set_instance_transform(i, leaf_xfs[i])
	leaves.multimesh = lm
	var leaf_m: StandardMaterial3D = mats["leaf"]
	leaf_m.emission_enabled = true
	leaf_m.emission = Color(0.05, 0.09, 0.03)
	leaf_m.emission_energy_multiplier = 0.25
	leaves.material_override = leaf_m
	root.add_child(leaves)
	# Pine card crosses on some conifers
	var pine_q := QuadMesh.new()
	pine_q.size = Vector2(2.8, 3.6)
	var pines := MultiMeshInstance3D.new()
	pines.name = "PineCards"
	var pm := MultiMesh.new()
	pm.transform_format = MultiMesh.TRANSFORM_3D
	pm.mesh = pine_q
	var pxf: Array[Transform3D] = []
	for i in range(positions.size()):
		if i % 3 == 0:
			var p: Vector3 = positions[i]
			var s := rng.randf_range(0.9, 1.4)
			for ang in [0.0, 90.0]:
				pxf.append(Transform3D(Basis(Vector3.UP, deg_to_rad(ang)).scaled(Vector3(s, s, s)), p + Vector3(0, 4.2 * s, 0)))
	pm.instance_count = pxf.size()
	for i in range(pxf.size()):
		pm.set_instance_transform(i, pxf[i])
	pines.multimesh = pm
	pines.material_override = mats["pine"]
	root.add_child(pines)
	# Undergrowth near lot / road edge
	var bush := QuadMesh.new()
	bush.size = Vector2(1.3, 1.0)
	var ug := MultiMeshInstance3D.new()
	ug.name = "Undergrowth"
	var um := MultiMesh.new()
	um.transform_format = MultiMesh.TRANSFORM_3D
	um.mesh = bush
	var uxf: Array[Transform3D] = []
	for i in range(220):
		var x := rng.randf_range(-45, 45)
		var z := rng.randf_range(-45, 55)
		if absf(x) < 16.0 and z > -13.0 and z < 22.0:
			continue
		if absf(z - 18.0) < 3.8:
			continue
		uxf.append(Transform3D(Basis(), Vector3(x, 0.5, z)))
		uxf.append(Transform3D(Basis(Vector3.UP, deg_to_rad(90)), Vector3(x, 0.5, z)))
	um.instance_count = uxf.size()
	for i in range(uxf.size()):
		um.set_instance_transform(i, uxf[i])
	ug.multimesh = um
	ug.material_override = _mat_alpha("under", "undergrowth.png")
	root.add_child(ug)

func _build_canopy_and_pumps(root: Node) -> void:
	# Canopy between road and store
	var cy := 4.6
	var cz := 9.0
	_box(root, Vector3(18, 0.3, 11), Vector3(0, cy, cz), mats["canopy"], "CanopyDeck")
	# Fascia stripe band
	for zoff in [-5.4, 5.4]:
		_mesh(root, Vector3(18.2, 0.55, 0.2), Vector3(0, cy - 0.15, cz + zoff), mats["fascia"], "Fascia")
	for xoff in [-9.0, 9.0]:
		_mesh(root, Vector3(0.2, 0.55, 11.2), Vector3(xoff, cy - 0.15, cz), mats["fascia"], "FasciaSide")
	# Stripe lights under canopy
	for i in range(6):
		var x := -7.5 + i * 3.0
		_mesh(root, Vector3(2.4, 0.06, 0.35), Vector3(x, cy - 0.2, cz), _mat_color("canopy_light", Color(1.0, 0.95, 0.8)), "CanopyStrip")
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.92, 0.75)
		l.light_energy = 2.8
		l.omni_range = 9.0
		l.shadow_enabled = false
		l.position = Vector3(x, cy - 0.35, cz)
		root.add_child(l)
	# Posts
	for x in [-8.0, 8.0]:
		for z in [5.0, 13.0]:
			_box(root, Vector3(0.35, 4.5, 0.35), Vector3(x, 2.25, z), mats["metal"], "CanopyPost")
	# Detailed pumps
	for i in range(4):
		_build_pump(root, Vector3(-6.0 + i * 4.0, 0, 9.0), i)
	# Tall price pylon
	_box(root, Vector3(0.4, 7.0, 0.4), Vector3(-12, 3.5, 15), mats["metal"], "PylonPole")
	_box(root, Vector3(2.8, 5.2, 0.25), Vector3(-12, 4.5, 15), mats["price"], "PylonSign")
	var pl := OmniLight3D.new()
	pl.light_color = Color(0.4, 1.0, 0.5)
	pl.light_energy = 1.2
	pl.omni_range = 5.0
	pl.position = Vector3(-12, 4.5, 15.3)
	root.add_child(pl)
	# Storefront sign on building
	var ssign := _mesh(root, Vector3(9.0, 1.1, 0.12), Vector3(0, 4.2, 0.55), mats["storesign"], "StoreSign")
	var neon := OmniLight3D.new()
	neon.light_color = Color(0.7, 1.0, 0.4)
	neon.light_energy = 1.3
	neon.omni_range = 6.0
	neon.position = Vector3(0, 4.2, 1.0)
	root.add_child(neon)
	# Parking stall lines (lot only, z 3..7)
	var lm := _mat_color("park", Color(0.9, 0.9, 0.85))
	for i in range(6):
		_mesh(root, Vector3(0.1, 0.03, 4.0), Vector3(-8.0 + i * 3.0, 0.1, 4.5), lm, "ParkLine")

func _build_pump(root: Node, pos: Vector3, idx: int) -> void:
	var g := Node3D.new()
	g.name = "Pump%d" % idx
	g.position = pos
	root.add_child(g)
	_box(g, Vector3(0.85, 1.7, 0.65), Vector3(0, 0.85, 0), mats["metal"], "Body")
	_mesh(g, Vector3(0.7, 0.45, 0.08), Vector3(0, 1.55, 0.34), _mat("pump_scr%d" % idx, "register_screen.png"), "Screen")
	_mesh(g, Vector3(0.35, 0.25, 0.2), Vector3(0.35, 1.1, 0.2), _mat_color("holster", Color(0.15, 0.15, 0.15)), "Holster")
	_cyl(g, 0.04, 0.04, 1.4, Vector3(0.45, 0.9, 0.55), _mat_color("hose", Color(0.08, 0.08, 0.08)), "Hose", Vector3(15, 0, 30))
	_mesh(g, Vector3(0.12, 0.35, 0.08), Vector3(0.55, 0.55, 0.85), _mat_color("nozzle", Color(0.2, 0.2, 0.22), 0.3, 0.8), "Nozzle")
	_mesh(g, Vector3(0.5, 0.15, 0.05), Vector3(0, 1.85, 0.3), _mat_color("price_disp", Color(0.05, 0.15, 0.05)), "PriceDisp")

func _build_store(root: Node) -> void:
	var store := Node3D.new()
	store.name = "Store"
	root.add_child(store)
	var W := 14.0
	var D := 10.0
	var H := 3.5
	# Floor (raised above lot)
	_box(store, Vector3(W, 0.14, D), Vector3(0, 0.12, -D * 0.5), mats["lino"], "Floor")
	# Drop ceiling grid panels
	_box(store, Vector3(W, 0.08, D), Vector3(0, H, -D * 0.5), mats["ceiling"], "Ceiling")
	# Walls
	_box(store, Vector3(W, H, 0.25), Vector3(0, H * 0.5, -D), mats["wall"], "BackWall")
	_box(store, Vector3(0.25, H, D), Vector3(-W * 0.5, H * 0.5, -D * 0.5), mats["siding"], "LeftWall")
	_box(store, Vector3(0.25, H, D), Vector3(W * 0.5, H * 0.5, -D * 0.5), mats["siding"], "RightWall")
	# Front wall with door + windows
	_box(store, Vector3(3.2, H, 0.25), Vector3(-5.4, H * 0.5, 0), mats["siding"], "FrontL")
	_box(store, Vector3(3.2, H, 0.25), Vector3(5.4, H * 0.5, 0), mats["siding"], "FrontR")
	_box(store, Vector3(8.0, 0.7, 0.25), Vector3(0, H - 0.35, 0), mats["siding"], "FrontHeader")
	_box(store, Vector3(8.0, 0.35, 0.2), Vector3(0, 0.2, 0), mats["siding"], "FrontKick")
	# Glass
	_mesh(store, Vector3(3.5, 2.5, 0.06), Vector3(-2.1, 1.55, 0.05), mats["glass"], "GlassL")
	_mesh(store, Vector3(3.5, 2.5, 0.06), Vector3(2.1, 1.55, 0.05), mats["glass"], "GlassR")
	# Door with push bar
	_box(store, Vector3(1.8, 2.35, 0.08), Vector3(0, 1.25, 0.08), mats["door"], "Door", false)
	_mesh(store, Vector3(1.4, 0.08, 0.06), Vector3(0, 1.15, 0.14), mats["metal"], "PushBar")
	_box(store, Vector3(0.12, 2.4, 0.12), Vector3(-0.95, 1.25, 0.1), mats["metal"], "DoorFrameL")
	_box(store, Vector3(0.12, 2.4, 0.12), Vector3(0.95, 1.25, 0.1), mats["metal"], "DoorFrameR")
	# Baseboards
	for z in [0.05, -D + 0.05]:
		_mesh(store, Vector3(W - 0.4, 0.12, 0.04), Vector3(0, 0.22, z), mats["baseboard"], "Base")
	_mesh(store, Vector3(0.04, 0.12, D - 0.2), Vector3(-W * 0.5 + 0.15, 0.22, -D * 0.5), mats["baseboard"], "BaseL")
	_mesh(store, Vector3(0.04, 0.12, D - 0.2), Vector3(W * 0.5 - 0.15, 0.22, -D * 0.5), mats["baseboard"], "BaseR")
	# Posters
	_decal(store, Vector3(-3.0, 1.7, 0.14), Vector2(0.95, 1.35), "poster_lotto.png", "PosterLotto")
	_decal(store, Vector3(3.0, 1.7, 0.14), Vector2(0.95, 1.35), "poster_snacks.png", "PosterSnacks")
	# Fluorescent panels + realistic green-tint lights (not blown out)
	for xz in [[-3.5, -2.5], [0.0, -2.5], [3.5, -2.5], [-3.5, -5.5], [0.0, -5.5], [3.5, -5.5], [-3.5, -8.2], [3.5, -8.2]]:
		_mesh(store, Vector3(1.3, 0.04, 0.55), Vector3(xz[0], H - 0.06, xz[1]), _mat("fluor", "fluorescent_panel.png"), "Fluor")
		var fl := OmniLight3D.new()
		fl.name = "StoreLight"
		fl.light_color = Color(0.85, 0.95, 0.88)  # slight green fluorescent
		fl.light_energy = 0.85
		fl.omni_range = 4.5
		fl.omni_attenuation = 1.4
		fl.position = Vector3(xz[0], H - 0.25, xz[1])
		# Dimmer toward back
		if xz[1] < -6.0:
			fl.light_energy = 0.65
		store.add_child(fl)
	# Dim fill only — avoid washout
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.8, 0.9, 0.85)
	fill.light_energy = 0.35
	fill.omni_range = 8.0
	fill.position = Vector3(0, 2.5, -3)
	store.add_child(fill)
	# Counter + register
	_build_counter(store)
	# Aisles
	_build_gondola(store, Vector3(-2.2, 0, -4.8), 0)
	_build_gondola(store, Vector3(0.6, 0, -4.8), 1)
	_build_gondola(store, Vector3(3.2, 0, -4.8), 2)
	_build_endcap(store, Vector3(-2.2, 0, -7.4))
	_build_endcap(store, Vector3(0.6, 0, -7.4))
	# Coffee / fountain / slushie wall (left)
	_build_beverage_station(store)
	# Coolers along back
	_build_coolers(store)
	# Stock / alarm area behind coolers (dark)
	_build_stock(store, H)
	# Restroom + mop closet
	_box(store, Vector3(2.4, H - 0.1, 2.4), Vector3(5.5, (H - 0.1) * 0.5, -8.3), mats["wall"], "RestroomWall")
	_make_interactable(store, Vector3(0.5, 0.3, 0.5), Vector3(5.5, 0.95, -7.6), "restroom_sink", "Clean Restroom", "RestroomSink")
	_mesh(store, Vector3(0.12, 0.7, 0.04), Vector3(4.35, 1.2, -7.1), _mat("rrkey", "rr_key.png"), "RRKey")
	_box(store, Vector3(1.1, H - 0.1, 1.1), Vector3(-5.9, (H - 0.1) * 0.5, -8.3), mats["wall"], "MopCloset")
	_build_mop_bucket(store, Vector3(-5.4, 0, -7.2))
	_decal(store, Vector3(-4.2, 0.55, -6.2), Vector2(0.55, 0.75), "wet_floor.png", "WetFloor")
	# Spill
	var spill_mat := _mat_color("spill", Color(0.35, 0.4, 0.55, 0.55))
	spill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh(store, Vector3(1.1, 0.02, 1.0), Vector3(0.6, 0.2, -5.6), spill_mat, "SpillVis")
	_make_interactable(store, Vector3(1.2, 0.08, 1.2), Vector3(0.6, 0.2, -5.6), "spill_aisle2", "Mop Spill (Aisle 2)", "Spill")
	# Trash
	_build_trash(store, Vector3(-5.6, 0, -5.2), "trash_bag", "Take Out Trash")
	# ATM + bulletin + news
	_box(store, Vector3(0.65, 1.55, 0.45), Vector3(-5.9, 0.85, -1.2), _mat("atm", "atm.png"), "ATM")
	_decal(store, Vector3(6.4, 1.85, -3.5), Vector2(1.15, 0.95), "bulletin.png", "Bulletin")
	_box(store, Vector3(0.75, 1.15, 0.45), Vector3(-4.2, 0.65, -1.3), _mat("news", "news_rack.png"), "NewsRack")
	# Wall clock
	_cyl(store, 0.32, 0.32, 0.07, Vector3(-1.2, 2.75, -0.2), _mat_color("clock", Color(0.95, 0.95, 0.9)), "WallClock", Vector3(90, 0, 0))
	# Interactables at counter already added in _build_counter

func _build_counter(store: Node) -> void:
	_box(store, Vector3(4.2, 1.05, 0.75), Vector3(2.4, 0.6, -1.6), mats["counter"], "Counter")
	_box(store, Vector3(0.75, 1.05, 2.1), Vector3(4.15, 0.6, -2.4), mats["counter"], "CounterReturn")
	# Register with screen, keypad, drawer
	var reg := Node3D.new()
	reg.name = "RegisterProp"
	reg.position = Vector3(2.0, 1.2, -1.45)
	store.add_child(reg)
	_mesh(reg, Vector3(0.5, 0.28, 0.4), Vector3(0, 0, 0), mats["metal"], "RegBody")
	_mesh(reg, Vector3(0.38, 0.28, 0.04), Vector3(0, 0.28, 0.05), _mat("rscreen", "register_screen.png"), "RegScreen")
	_mesh(reg, Vector3(0.22, 0.02, 0.18), Vector3(0, 0.02, -0.28), _mat_color("keypad", Color(0.12, 0.12, 0.14)), "Keypad")
	for i in range(12):
		_mesh(reg, Vector3(0.04, 0.015, 0.035), Vector3(-0.07 + (i % 3) * 0.05, 0.03, -0.22 - (i / 3) * 0.04), _mat_color("key", Color(0.25, 0.25, 0.28)), "Key")
	_mesh(reg, Vector3(0.48, 0.12, 0.35), Vector3(0, -0.22, 0.05), _mat_color("drawer", Color(0.4, 0.35, 0.3)), "CashDrawer")
	# Security TV
	_mesh(store, Vector3(0.48, 0.38, 0.12), Vector3(3.15, 1.5, -1.3), _mat("tv", "tv_bezel.png"), "SecurityTVMesh")
	# Lottery strip
	_decal(store, Vector3(1.2, 1.22, -1.2), Vector2(0.9, 0.12), "lottery_strip.png", "Lottery")
	# Cigarette rack
	_box(store, Vector3(1.7, 1.5, 0.28), Vector3(4.3, 2.0, -3.1), _mat("cigrack", "cig_rack.png"), "CigRack")
	for row in range(4):
		for col in range(5):
			_mesh(store, Vector3(0.12, 0.18, 0.06), Vector3(3.7 + col * 0.28, 1.45 + row * 0.32, -2.95), _mat("cig%d" % ((row + col) % 3), "cig_pack.png"), "CigPack")
	# Hot dog roller
	var hd := Node3D.new()
	hd.position = Vector3(0.5, 1.2, -1.45)
	store.add_child(hd)
	_mesh(hd, Vector3(0.7, 0.25, 0.4), Vector3(0, 0, 0), _mat("roller", "roller_metal.png"), "RollerBase")
	for i in range(5):
		_cyl(hd, 0.03, 0.03, 0.55, Vector3(-0.2 + i * 0.1, 0.12, 0), _mat_color("rod", Color(0.7, 0.7, 0.75), 0.3, 0.8), "Rod", Vector3(0, 0, 90))
		_cyl(hd, 0.045, 0.045, 0.2, Vector3(-0.2 + i * 0.1, 0.16, 0), _mat_color("dog", Color(0.75, 0.35, 0.2)), "Dog", Vector3(0, 0, 90))
	# Timecard, note, phone
	_make_interactable(store, Vector3(0.28, 0.4, 0.08), Vector3(2.7, 1.55, -1.2), "timecard", "Timecard (Clock In)", "Timecard")
	_make_interactable(store, Vector3(0.35, 0.45, 0.06), Vector3(3.5, 1.55, -1.2), "manager_note", "Manager's Note", "ManagerNote")
	_decal(store, Vector3(3.5, 1.55, -1.15), Vector2(0.35, 0.45), "manager_note.png", "NoteVis")
	_make_interactable(store, Vector3(0.22, 0.22, 0.22), Vector3(1.4, 1.35, -1.25), "phone", "Landline Phone", "Phone")
	_mesh(store, Vector3(0.2, 0.12, 0.2), Vector3(1.4, 1.35, -1.25), _mat_color("phone", Color(0.12, 0.12, 0.12)), "PhoneMesh")

func _build_gondola(store: Node, origin: Vector3, variant: int) -> void:
	# Frame with shelf lips
	_box(store, Vector3(0.08, 1.7, 3.6), origin + Vector3(-0.28, 0.9, 0), _mat_color("shelf_metal", Color(0.55, 0.57, 0.6), 0.45, 0.55), "GondolaL")
	_box(store, Vector3(0.08, 1.7, 3.6), origin + Vector3(0.28, 0.9, 0), _mat_color("shelf_metal2", Color(0.55, 0.57, 0.6), 0.45, 0.55), "GondolaR")
	_box(store, Vector3(0.55, 0.06, 3.6), origin + Vector3(0, 0.15, 0), _mat_color("shelf_metal3", Color(0.5, 0.52, 0.55), 0.5, 0.4), "GondolaBase")
	for shelf_y in [0.45, 0.85, 1.25, 1.6]:
		_box(store, Vector3(0.55, 0.04, 3.6), origin + Vector3(0, shelf_y, 0), _mat_color("shelf_board", Color(0.62, 0.58, 0.5), 0.7), "Shelf", false)
		# Lip
		_mesh(store, Vector3(0.55, 0.06, 0.03), origin + Vector3(0, shelf_y + 0.04, 1.78), _mat_color("lip", Color(0.75, 0.75, 0.78)), "Lip")
		_mesh(store, Vector3(0.55, 0.06, 0.03), origin + Vector3(0, shelf_y + 0.04, -1.78), _mat_color("lip2", Color(0.75, 0.75, 0.78)), "Lip2")
		_mesh(store, Vector3(0.5, 0.035, 0.01), origin + Vector3(0.3, shelf_y - 0.01, 1.82), _mat("pstrip", "price_strip.png"), "PriceStripFront")
	# Varied products as bags/cans/boxes
	_scatter_products(store, origin, variant)

func _scatter_products(store: Node, origin: Vector3, variant: int) -> void:
	# Dense both-sides stocking; materials keyed by texture so we don't thrash the importer
	for shelf in range(4):
		var y := 0.55 + shelf * 0.4
		for side in [-1, 1]:
			var x := origin.x + 0.24 * float(side)
			for i in range(10):
				var z := origin.z - 1.45 + i * 0.3
				var kind: int = (shelf + i + variant + side + 2) % 3
				var ti: int = absi(i + variant + shelf) % 8
				if kind == 0:
					_mesh(store, Vector3(0.14, 0.22, 0.06), Vector3(x, y, z), _mat("chip_%d" % ti, "chip_%d.png" % ti), "Bag")
				elif kind == 1:
					_cyl(store, 0.045, 0.045, 0.16, Vector3(x, y, z), _mat("drink_%d" % (ti % 8), "drink_%d.png" % (ti % 8)), "Can")
				else:
					_mesh(store, Vector3(0.12, 0.055, 0.07), Vector3(x, y - 0.04, z), _mat("candy_%d" % (ti % 6), "candy_%d.png" % (ti % 6)), "Box")

func _build_endcap(store: Node, origin: Vector3) -> void:
	_box(store, Vector3(1.3, 1.55, 0.45), origin + Vector3(0, 0.8, 0), mats["metal"], "EndCap")
	for i in range(12):
		_mesh(store, Vector3(0.16, 0.22, 0.06), origin + Vector3(-0.45 + (i % 4) * 0.3, 0.45 + (i / 4) * 0.4, 0.28), _mat("end%d" % i, "chip_%d.png" % (i % 8)), "EndProd")

func _build_beverage_station(store: Node) -> void:
	_box(store, Vector3(1.15, 1.35, 0.55), Vector3(-5.7, 0.75, -1.9), _mat("coffee", "coffee_machine.png"), "Coffee")
	_mesh(store, Vector3(0.35, 0.25, 0.35), Vector3(-5.7, 1.5, -1.9), _mat_color("pot", Color(0.15, 0.1, 0.08)), "Pot")
	_box(store, Vector3(1.35, 1.75, 0.65), Vector3(-5.7, 0.95, -3.3), _mat("fount", "fountain.png"), "Fountain")
	for i in range(4):
		_mesh(store, Vector3(0.18, 0.5, 0.12), Vector3(-6.15 + i * 0.28, 1.4, -3.05), _mat_color("noz%d" % i, [Color(0.8,0.1,0.1), Color(0.1,0.3,0.8), Color(0.1,0.6,0.2), Color(0.9,0.7,0.1)][i]), "FNoz")
	_box(store, Vector3(0.7, 1.3, 0.7), Vector3(-5.7, 0.75, -4.4), _mat("slush", "slushie.png"), "Slushie")
	_cyl(store, 0.22, 0.25, 0.5, Vector3(-5.7, 1.5, -4.4), _mat_color("dome", Color(0.9, 0.3, 0.7, 0.5)), "Dome")

func _build_coolers(store: Node) -> void:
	for i in range(5):
		var x := -4.2 + i * 1.75
		var g := Node3D.new()
		g.name = "Cooler%d" % i
		g.position = Vector3(x, 0, -9.0)
		store.add_child(g)
		# Hollow cabinet: back, sides, top, bottom (NOT a solid filled box)
		_box(g, Vector3(1.55, 2.15, 0.08), Vector3(0, 1.1, -0.35), mats["metal"], "CabBack")
		_box(g, Vector3(0.08, 2.15, 0.7), Vector3(-0.74, 1.1, 0.0), mats["metal"], "CabL")
		_box(g, Vector3(0.08, 2.15, 0.7), Vector3(0.74, 1.1, 0.0), mats["metal"], "CabR")
		_box(g, Vector3(1.55, 0.08, 0.7), Vector3(0, 2.15, 0.0), mats["metal"], "CabTop")
		_box(g, Vector3(1.55, 0.08, 0.7), Vector3(0, 0.08, 0.0), mats["metal"], "CabBot")
		# White interior back panel so bottles read
		_mesh(g, Vector3(1.35, 1.9, 0.02), Vector3(0, 1.1, -0.3), _mat_color("cwhite", Color(0.85, 0.9, 0.95)), "InnerBack")
		# Door frame + glass
		_mesh(g, Vector3(1.45, 0.07, 0.06), Vector3(0, 2.05, 0.38), mats["metal"], "FrameTop")
		_mesh(g, Vector3(1.45, 0.07, 0.06), Vector3(0, 0.2, 0.38), mats["metal"], "FrameBot")
		_mesh(g, Vector3(0.07, 1.9, 0.06), Vector3(-0.69, 1.1, 0.38), mats["metal"], "FrameL")
		_mesh(g, Vector3(0.07, 1.9, 0.06), Vector3(0.69, 1.1, 0.38), mats["metal"], "FrameR")
		var glass := StandardMaterial3D.new()
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.6, 0.8, 0.95, 0.12)
		glass.roughness = 0.05
		glass.metallic = 0.1
		_mesh(g, Vector3(1.25, 1.75, 0.02), Vector3(0, 1.1, 0.4), glass, "DoorGlass")
		_mesh(g, Vector3(0.05, 0.6, 0.08), Vector3(0.55, 1.1, 0.48), mats["metal"], "Handle")
		var cl := OmniLight3D.new()
		cl.light_color = Color(0.75, 0.9, 1.0)
		cl.light_energy = 3.0
		cl.omni_range = 2.8
		cl.position = Vector3(0, 1.9, 0.0)
		g.add_child(cl)
		# Lit shelves of bottles INSIDE the hollow cab
		for shelf in range(3):
			var sy := 0.45 + shelf * 0.55
			_mesh(g, Vector3(1.3, 0.04, 0.55), Vector3(0, sy, 0.0), _mat_color("csh", Color(0.8, 0.85, 0.9)), "CShelf")
			for b in range(5):
				var ti: int = (i + b + shelf) % 8
				var bm := _mat("drink_%d" % ti, "drink_%d.png" % ti).duplicate() as StandardMaterial3D
				bm.emission_enabled = true
				bm.emission = Color(0.4, 0.55, 0.7)
				bm.emission_energy_multiplier = 0.6
				_cyl(g, 0.05, 0.05, 0.24, Vector3(-0.5 + b * 0.25, sy + 0.16, 0.1), bm, "Bot")
	_make_interactable(store, Vector3(1.6, 1.0, 0.4), Vector3(-2.0, 1.0, -8.6), "cooler_stock", "Restock Coolers", "CoolerStock")
	_make_interactable(store, Vector3(1.0, 1.8, 0.25), Vector3(2.0, 1.1, -8.55), "cooler_door", "Check Coolers", "CoolerDoor")

func _build_stock(store: Node, H: float) -> void:
	var stock := Node3D.new()
	stock.name = "StockArea"
	store.add_child(stock)
	_box(stock, Vector3(7, 0.1, 2.6), Vector3(0, 0.1, -11.3), mats["lino"], "StockFloor")
	_box(stock, Vector3(7, H, 0.2), Vector3(0, H * 0.5, -12.5), mats["wall"], "StockBack")
	_box(stock, Vector3(0.2, H, 2.6), Vector3(-3.5, H * 0.5, -11.3), mats["wall"], "StockL")
	_box(stock, Vector3(0.2, H, 2.6), Vector3(3.5, H * 0.5, -11.3), mats["wall"], "StockR")
	var sl := OmniLight3D.new()
	sl.light_energy = 0.15
	sl.light_color = Color(0.7, 0.75, 0.55)
	sl.omni_range = 3.5
	sl.position = Vector3(0, 2.8, -11.3)
	stock.add_child(sl)
	_make_interactable(stock, Vector3(0.35, 0.4, 0.15), Vector3(2.6, 1.5, -11.0), "alarm_box", "Alarm Box", "AlarmBox")
	var al := OmniLight3D.new()
	al.name = "AlarmLight"
	al.light_color = Color(1, 0.1, 0.1)
	al.light_energy = 0.0
	al.omni_range = 3.0
	al.position = Vector3(2.6, 1.5, -11.0)
	stock.add_child(al)

func _build_mop_bucket(store: Node, pos: Vector3) -> void:
	var g := Node3D.new()
	g.position = pos
	store.add_child(g)
	_cyl(g, 0.28, 0.32, 0.4, Vector3(0, 0.25, 0), _mat("mopb", "mop_bucket.png"), "Bucket")
	_cyl(g, 0.02, 0.02, 1.2, Vector3(0.1, 0.9, 0), _mat_color("handle", Color(0.3, 0.3, 0.35)), "MopHandle")
	_mesh(g, Vector3(0.25, 0.15, 0.08), Vector3(0.1, 0.35, 0), _mat_color("mophead", Color(0.4, 0.35, 0.3)), "MopHead")

func _build_trash(parent: Node, pos: Vector3, id: String, label: String) -> void:
	_cyl(parent, 0.28, 0.3, 0.85, pos + Vector3(0, 0.45, 0), _mat("trash", "trash_can.png"), "TrashCan")
	_make_interactable(parent, Vector3(0.55, 0.9, 0.55), pos + Vector3(0, 0.45, 0), id, label, "Trash")

func _build_exterior_props(root: Node) -> void:
	_box(root, Vector3(1.5, 1.05, 0.9), Vector3(7.5, 0.55, 2.8), _mat("ice", "ice_chest.png"), "IceChest")
	_box(root, Vector3(1.6, 1.5, 1.1), Vector3(9.2, 0.75, 2.5), _mat("prop", "propane.png"), "PropaneCage")
	for x in [-7.0, 7.0]:
		_cyl(root, 0.28, 0.3, 0.9, Vector3(x, 0.45, 13.5), _mat("trash2", "trash_can.png"), "PumpTrash")
	# Dumpster beside store
	_box(root, Vector3(2.4, 1.5, 1.6), Vector3(9.5, 0.75, -2.0), _mat_color("dumpster", Color(0.15, 0.35, 0.2)), "Dumpster")
	_mesh(root, Vector3(2.5, 0.1, 1.7), Vector3(9.5, 1.55, -2.0), _mat_color("dlid", Color(0.12, 0.3, 0.18)), "DumpLid")
	# Lot poles
	for xz in [[-10.0, 5.0], [10.0, 5.0], [-10.0, 14.0], [10.0, 14.0]]:
		_box(root, Vector3(0.18, 5.2, 0.18), Vector3(xz[0], 2.6, xz[1]), mats["metal"], "LotPole")
		var pl := OmniLight3D.new()
		pl.light_color = Color(0.95, 0.85, 0.65)
		pl.light_energy = 2.2
		pl.omni_range = 11.0
		pl.position = Vector3(xz[0], 5.1, xz[1])
		root.add_child(pl)
	# Player car parked in lot (facing store-ish / along lot)
	var car := Node3D.new()
	car.name = "PlayerCar"
	car.position = Vector3(5.5, 0, 4.5)
	car.rotation_degrees = Vector3(0, -20, 0)
	root.add_child(car)
	_mesh(car, Vector3(4.3, 1.35, 1.85), Vector3(0, 0.75, 0), _mat("car", "car_paint.png"), "CarBody")
	_mesh(car, Vector3(3.4, 0.55, 1.6), Vector3(0, 1.55, 0), _mat_color("carglass", Color(0.25, 0.35, 0.45, 0.55)), "Cabin")
	for wx in [-1.35, 1.35]:
		for wz in [-1.05, 1.05]:
			_cyl(car, 0.34, 0.34, 0.28, Vector3(wx, 0.34, wz), _mat_color("tire", Color(0.05, 0.05, 0.05)), "Wheel", Vector3(0, 0, 90))

func _decal(parent: Node, pos: Vector3, size: Vector2, tex_name: String, name: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex(tex_name)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)

func _make_interactable(parent: Node, size: Vector3, pos: Vector3, id: String, label: String, name: String) -> Interactable:
	var body := Interactable.new()
	body.name = name
	body.interact_id = id
	body.label = label
	body.one_shot = id in ["timecard", "manager_note", "spill_aisle2", "cooler_stock", "trash_bag", "restroom_sink", "cooler_door"]
	body.collision_layer = 8
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body

func _bake_nav() -> void:
	var nmesh := NavigationMesh.new()
	nmesh.cell_size = 0.25
	nmesh.cell_height = 0.2
	nmesh.agent_radius = 0.4
	nmesh.agent_height = 1.6
	nmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh_instance.navigation_mesh = nmesh
	await get_tree().process_frame
	nav_mesh_instance.bake_navigation_mesh()
