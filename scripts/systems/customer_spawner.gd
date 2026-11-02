extends Node
class_name CustomerSpawner

var register: RegisterSystem
var spawn_timer: float = 12.0
var active_count: int = 0
var max_active: int = 2
var candy_scheduled: bool = false
var candy_done: bool = false
var index: int = 0

func setup(reg: RegisterSystem) -> void:
	register = reg

func _process(delta: float) -> void:
	if GameState.phase != "play":
		return
	if not GameState.clocked_in:
		return
	spawn_timer -= delta * GameState.time_scale
	# Schedule candy man after clock-in once enough shift time passes
	if not candy_scheduled and GameState.clocked_in and not candy_done:
		var due := false
		if GameState.time_scale >= 10.0 and GameState.real_elapsed > 8.0:
			due = true
		elif GameState.game_hour >= 23.0 or (GameState.game_hour < 12.0 and GameState.real_elapsed > 20.0):
			due = true
		if due:
			candy_scheduled = true
			candy_done = true
			_spawn_old_man()
			return
	if spawn_timer <= 0.0 and active_count < max_active and not register.active:
		spawn_timer = lerpf(45.0, 20.0, GameState.intensity()) / maxf(1.0, sqrt(GameState.time_scale))
		_spawn_regular()

func _spawn_regular() -> void:
	var list: Array = GameState.customers_data
	if list.is_empty():
		return
	var cdata: Dictionary = list[index % list.size()]
	index += 1
	var cust := CustomerNPC.new()
	cust.name = "Customer_%s" % cdata.id
	get_parent().add_child(cust)
	cust.global_position = Vector3(randf_range(-1, 1), 0, 2.5)
	cust.setup(cdata)
	cust.start_shopping(GameState.products)
	cust.ready_for_checkout.connect(_on_checkout)
	cust.left_store.connect(_on_left)
	active_count += 1
	EventBus.customer_arrived.emit(cust)
	# Dialogue flavor
	_maybe_talk(cust)

func _spawn_old_man() -> void:
	var cust := CustomerNPC.new()
	cust.name = "OldMan"
	get_parent().add_child(cust)
	cust.global_position = Vector3(0, 0, 2.0)
	cust.setup_old_man()
	cust.start_candy_visit()
	cust.ready_for_checkout.connect(_on_candy_checkout)
	cust.left_store.connect(_on_left)
	active_count += 1
	EventBus.candy_scene_started.emit()
	EventBus.customer_arrived.emit(cust)

func _on_candy_checkout(c: CustomerNPC) -> void:
	# Special candy dialogue flow — auto scene
	EventBus.dialogue_line.emit("Old Man", "Evening, son.")
	await get_tree().create_timer(1.2 / GameState.time_scale).timeout
	EventBus.dialogue_line.emit("Old Man", "You look like you could use a little sugar.")
	await get_tree().create_timer(1.4 / GameState.time_scale).timeout
	EventBus.dialogue_line.emit("Old Man", "Go on. Take it.")
	await get_tree().create_timer(1.0 / GameState.time_scale).timeout
	EventBus.jake_remark.emit("Uh... thanks?")
	await get_tree().create_timer(1.0 / GameState.time_scale).timeout
	EventBus.dialogue_line.emit("Old Man", "That's the spirit!")
	await get_tree().create_timer(1.2 / GameState.time_scale).timeout
	EventBus.dialogue_line.emit("Old Man", "You should never take candy from strangers.")
	await get_tree().create_timer(2.0 / GameState.time_scale).timeout
	GameState.candy_done = true
	GameState.paranormal_unlocked = true
	EventBus.candy_scene_finished.emit()
	c.begin_leave()
	# Still ring him up lightly
	if register and not register.active:
		register.start_transaction(c, ["muddybar"])
		while register.remaining_items() > 0:
			register.scan_next()
			await get_tree().process_frame
		register.give_correct_auto()

func _on_checkout(c: CustomerNPC) -> void:
	if c.is_old_man:
		return
	if register and not register.active:
		register.start_transaction(c, c.cart)
		GameState.set_objective("Ring up the customer")

func _on_left(_c: CustomerNPC) -> void:
	active_count = maxi(0, active_count - 1)
	if GameState.clocked_in and not GameState.ending_triggered:
		GameState.set_objective("Continue your shift — keep the store tidy")

func _maybe_talk(c: CustomerNPC) -> void:
	var key := c.dialogue_set
	if key == "scary" and not GameState.paranormal_unlocked:
		key = "weird"
	var arr: Array = GameState.dialogue.get(key, GameState.dialogue.get("normal", []))
	if arr.is_empty():
		return
	var entry: Dictionary = arr[randi() % arr.size()]
	for line in entry.get("lines", []):
		EventBus.dialogue_line.emit("Customer", str(line))
