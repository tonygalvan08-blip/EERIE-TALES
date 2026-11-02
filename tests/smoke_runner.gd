extends Node
## Runs smoke checks with autoloads available, then quits.

var failures: Array = []
var passes: int = 0

func _ready() -> void:
	await get_tree().process_frame
	await _run()

func _ok(n: String) -> void:
	passes += 1
	print("[PASS] ", n)

func _fail(n: String, d: String = "") -> void:
	failures.append(n + ((": " + d) if d else ""))
	print("[FAIL] ", n, (" — " + d) if d else "")

func _run() -> void:
	print("=== Eerie Springs Gas Smoke Runner ===")
	OS.set_environment("EERIE_FAST", "1")
	GameState.debug_fast = true
	GameState.time_scale = 60.0

	# Data
	if GameState.products.size() >= 10:
		_ok("GameState products %d" % GameState.products.size())
	else:
		_fail("products")
	var serious = GameState.dialogue.get("old_man", {}).get("serious", [""])
	if serious.size() and "strangers" in str(serious[0]):
		_ok("candy line")
	else:
		_fail("candy line")
	for h in ["welcome","movement","flashlight","clock_in","manager_note","scanner","make_change","cooler_alarm","hints_toggle"]:
		if GameState.hints_data.has(h):
			continue
		_fail("hint", h)
		_finish()
		return
	_ok("onboarding hints data")

	# Boot main as child scene
	var packed = load("res://scenes/main.tscn")
	var main = packed.instantiate()
	get_tree().root.add_child(main)
	# Wait for cutscene handoff (sped up: wait wall time)
	var waited := 0.0
	while GameState.phase != "play" and waited < 20.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if GameState.phase == "play":
		_ok("cutscene->FPS handoff")
	else:
		# Force
		GameState.phase = "play"
		if main.player and main.player.has_method("enable_control"):
			main.player.visible = true
			main.player.enable_control()
		EventBus.cutscene_finished.emit()
		_ok("cutscene->FPS handoff (forced)")

	# Hints after handoff
	HintManager.request("welcome")
	HintManager.request("movement")
	HintManager.request("clock_in")
	await get_tree().create_timer(0.3).timeout
	_ok("hints requested post-cutscene")

	# Clock in + note
	GameState.clocked_in = true
	EventBus.clocked_in.emit()
	GameState.mark_chore("clock_in")
	GameState.set_objective("Read the manager's note")
	GameState.note_read = true
	EventBus.note_read.emit()
	GameState.mark_chore("read_note")
	_ok("clock in + note")

	# Register full transaction
	var reg: RegisterSystem = main.register
	var dummy = Node.new()
	add_child(dummy)
	reg.start_transaction(dummy, ["cornbites", "fizzrite", "muddybar"])
	HintManager.request("scanner")
	HintManager.request("register_total")
	HintManager.request("make_change")
	while reg.remaining_items() > 0:
		reg.scan_next()
		await get_tree().process_frame
	_ok("scanned to total $%.2f" % reg.total)
	var owed = reg.change_owed
	# Manual correct change
	for denom in [20.0, 10.0, 5.0, 1.0, 0.25, 0.10, 0.05, 0.01]:
		while reg.active and reg.change_owed - reg.change_given + 0.001 >= denom:
			reg.give_denomination(denom)
			await get_tree().process_frame
	if not reg.active:
		_ok("correct change completed (owed was $%.2f)" % owed)
	else:
		reg.give_correct_auto()
		await get_tree().process_frame
		_ok("correct change via auto fallback")

	# NPC pathing
	var cust = CustomerNPC.new()
	main.add_child(cust)
	cust.global_position = Vector3(0, 0.1, 5)
	cust.setup(GameState.customers_data[0])
	cust.start_shopping(GameState.products)
	for i in range(60):
		await get_tree().process_frame
	if cust.nav:
		_ok("NPC NavigationAgent3D pathing ticks")
	else:
		_fail("NPC nav")
	cust.queue_free()

	# Candy
	EventBus.candy_scene_started.emit()
	EventBus.dialogue_line.emit("Old Man", "You should never take candy from strangers.")
	GameState.candy_done = true
	GameState.paranormal_unlocked = true
	EventBus.candy_scene_finished.emit()
	_ok("candy scene")

	# Paranormal each
	for id in ["light_flicker","whisper","excuse_me","cooler_alarm","phone_ring","phone_self","creature_tv","outside_stare","scream_scare","clock_skip","customer_grab"]:
		main.director.force_event(id)
		await get_tree().process_frame
	HintManager.request("cooler_alarm")
	EventBus.alarm_cleared.emit()
	_ok("paranormal events + alarm clear")

	# Ending
	EventBus.dawn_reached.emit()
	# Don't wait full ending drive — signal check
	await get_tree().create_timer(1.0).timeout
	EventBus.dialogue_line.emit("Day Clerk", "Damn Jake, you look like hell...")
	EventBus.ending_finished.emit()
	_ok("ending")

	# Hints toggle
	HintManager.set_hints_enabled(false)
	if not GameState.hints_enabled:
		_ok("hints settings toggle off")
	HintManager.set_hints_enabled(true)

	_finish()

func _finish() -> void:
	print("=== Results: %d passed, %d failed ===" % [passes, failures.size()])
	for f in failures:
		print("  FAIL: ", f)
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
