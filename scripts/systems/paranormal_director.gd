extends Node
class_name ParanormalDirector
## Schedules paranormal events with intensity scaling. Data-driven.

var cooldowns: Dictionary = {}
var timer: float = 8.0
var alarm_active: bool = false
var creature_visible: bool = false
var phone_pending: String = ""

@onready var audio: Node = $Audio if has_node("Audio") else null

func _ready() -> void:
	EventBus.candy_scene_finished.connect(_on_candy)
	EventBus.alarm_cleared.connect(_on_alarm_cleared)
	set_process(true)

func _on_candy() -> void:
	GameState.paranormal_unlocked = true
	timer = 2.0

func _process(delta: float) -> void:
	if GameState.phase != "play":
		return
	if not GameState.paranormal_unlocked and GameState.game_hour < 23.0:
		# Very subtle pre-candy: only light flicker after 22:30
		if GameState.game_hour >= 22.5:
			timer -= delta * GameState.time_scale
			if timer <= 0.0:
				timer = 25.0
				_fire("light_flicker")
		return
	timer -= delta * GameState.time_scale
	if timer <= 0.0:
		timer = lerpf(18.0, 6.0, GameState.intensity())
		_pick_and_fire()

func _pick_and_fire() -> void:
	var pool: Array = []
	var hour := GameState.game_hour
	for e in GameState.events:
		var id: String = e.id
		var min_h: float = float(e.get("min_hour", 22.0))
		# Handle wrap: min_hour 0 means after midnight
		var ok := false
		if min_h >= 22.0:
			ok = hour >= min_h or hour < 12.0
		else:
			ok = hour < 12.0 and hour >= min_h
		if not ok and not GameState.paranormal_unlocked:
			continue
		if not ok:
			continue
		var cd: float = float(e.get("cooldown", 60))
		var last: float = float(cooldowns.get(id, -9999.0))
		if GameState.real_elapsed - last < cd / maxf(GameState.time_scale, 1.0):
			continue
		var w: int = int(e.get("weight", 1))
		for i in range(w):
			pool.append(id)
	if pool.is_empty():
		return
	var pick: String = pool[randi() % pool.size()]
	_fire(pick)

func _fire(id: String) -> void:
	cooldowns[id] = GameState.real_elapsed
	EventBus.paranormal_event.emit(id)
	match id:
		"light_flicker":
			_flicker_lights()
			_jake("light_flicker")
			_sfx("res://assets/audio/light_click.wav")
		"whisper":
			_sfx("res://assets/audio/whisper.wav")
			_jake("whisper")
		"excuse_me":
			_sfx("res://assets/audio/excuse_me.wav")
			EventBus.dialogue_line.emit("???", "Excuse me")
			_jake("excuse_me")
		"cooler_alarm":
			alarm_active = true
			EventBus.alarm_started.emit()
			_sfx_loop("res://assets/audio/cooler_alarm.wav", "alarm")
			_jake("alarm")
			GameState.set_objective("Shut off the cooler alarm")
		"phone_ring":
			phone_pending = "strange"
			EventBus.phone_ringing.emit()
			_sfx("res://assets/audio/phone_ring.wav")
			_jake("phone")
		"phone_self":
			phone_pending = "self"
			EventBus.phone_ringing.emit()
			_sfx("res://assets/audio/phone_ring.wav")
			_jake("phone_self")
		"creature_tv":
			creature_visible = true
			EventBus.creature_on_tv.emit(true)
			_jake("creature_tv")
			get_tree().create_timer(2.5).timeout.connect(func():
				creature_visible = false
				EventBus.creature_on_tv.emit(false)
			)
		"outside_stare":
			_jake("outside_stare")
			EventBus.paranormal_event.emit("outside_stare_spawn")
		"scream_scare":
			_sfx("res://assets/audio/scream.wav")
		"clock_skip":
			GameState.game_hour = minf(5.5, GameState.game_hour + 0.75)
			_jake("clock_skip")
		"customer_grab":
			_jake("grab")
			_sfx("res://assets/audio/scream.wav")
			EventBus.paranormal_event.emit("customer_grab_spawn")

func force_event(id: String) -> void:
	_fire(id)

func _on_alarm_cleared() -> void:
	alarm_active = false
	_stop_loop("alarm")

func _flicker_lights() -> void:
	var lights := get_tree().get_nodes_in_group("store_lights")
	# Also find by name
	for n in get_tree().get_nodes_in_group("world"):
		pass
	var root := get_parent()
	if root == null:
		return
	for l in _find_lights(root):
		var orig: float = l.light_energy
		l.light_energy = 0.05
		get_tree().create_timer(0.1).timeout.connect(func():
			if is_instance_valid(l):
				l.light_energy = orig
		)
		get_tree().create_timer(0.2).timeout.connect(func():
			if is_instance_valid(l):
				l.light_energy = 0.1
		)
		get_tree().create_timer(0.35).timeout.connect(func():
			if is_instance_valid(l):
				l.light_energy = orig
		)

func _find_lights(n: Node) -> Array:
	var out: Array = []
	if n is OmniLight3D and ("StoreLight" in n.name or "Fluor" in n.name or n.name.begins_with("Store")):
		out.append(n)
	if n is OmniLight3D and n.light_energy > 0.5 and n.position.y > 2.0:
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_lights(c))
	return out

func _jake(key: String) -> void:
	var remarks: Dictionary = GameState.dialogue.get("jake_remarks", {})
	var t: String = str(remarks.get(key, ""))
	if t != "":
		EventBus.jake_remark.emit(t)

func _sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

var _loops: Dictionary = {}
func _sfx_loop(path: String, key: String) -> void:
	_stop_loop(key)
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.name = "Loop_%s" % key
	add_child(p)
	p.play()
	_loops[key] = p

func _stop_loop(key: String) -> void:
	if _loops.has(key) and is_instance_valid(_loops[key]):
		_loops[key].stop()
		_loops[key].queue_free()
	_loops.erase(key)
