extends Node
## Onboarding hints: show once when relevant, fade, taper later in the night.

signal hint_shown(id: String, text: String)
signal hint_hidden
signal hints_toggled(enabled: bool)

var _queue: Array = []
var _showing: bool = false
var _current_id: String = ""

func _ready() -> void:
	EventBus.cutscene_finished.connect(_on_cutscene_finished)
	EventBus.player_ready.connect(_on_player_ready)
	EventBus.interactable_focused.connect(_on_focus)
	EventBus.checkout_started.connect(_on_checkout)
	EventBus.alarm_started.connect(_on_alarm)
	EventBus.pump_customer_arrived.connect(_on_pump)
	EventBus.paranormal_event.connect(_on_para)
	EventBus.time_changed.connect(_on_time)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_hints"):
		set_hints_enabled(not GameState.hints_enabled)

func set_hints_enabled(v: bool) -> void:
	GameState.hints_enabled = v
	hints_toggled.emit(v)
	if not v:
		hint_hidden.emit()

func request(hint_id: String) -> void:
	if not GameState.hints_enabled:
		return
	if GameState.shown_hints.get(hint_id, false):
		return
	# Taper: after ~1 AM, only critical hints
	if _late_night() and hint_id not in ["cooler_alarm", "make_change", "scanner"]:
		return
	_queue.append(hint_id)
	_try_show()

func force_show_for_test(hint_id: String) -> void:
	## Bypass taper/once for smoke tests
	var data: Dictionary = GameState.hints_data.get(hint_id, {})
	var text: String = str(data.get("text", hint_id))
	hint_shown.emit(hint_id, text)

func _try_show() -> void:
	if _showing or _queue.is_empty():
		return
	if not GameState.hints_enabled:
		_queue.clear()
		return
	var id: String = _queue.pop_front()
	if GameState.shown_hints.get(id, false):
		_try_show()
		return
	var data: Dictionary = GameState.hints_data.get(id, {})
	if data.is_empty():
		_try_show()
		return
	GameState.shown_hints[id] = true
	_showing = true
	_current_id = id
	hint_shown.emit(id, str(data.get("text", "")))
	var dur := float(data.get("duration", 4.0))
	get_tree().create_timer(dur).timeout.connect(_hide_current)

func _hide_current() -> void:
	_showing = false
	_current_id = ""
	hint_hidden.emit()
	_try_show()

func _late_night() -> bool:
	var h := GameState.game_hour
	return h >= 1.0 and h < 21.0

func _on_cutscene_finished() -> void:
	request("welcome")
	request("hints_toggle")

func _on_player_ready() -> void:
	request("movement")
	request("flashlight")
	request("clock_in")
	GameState.set_objective("Clock in at the register")

func _on_focus(label: String) -> void:
	request("interact")
	if "note" in label.to_lower() or "manager" in label.to_lower():
		request("manager_note")

func _on_checkout(_c: Node) -> void:
	request("scanner")
	request("register_total")
	request("make_change")
	request("chores")

func _on_alarm() -> void:
	request("cooler_alarm")
	GameState.set_objective("Shut off the cooler alarm")

func _on_pump(_c: Node) -> void:
	request("pump_customer")

func _on_para(event_id: String) -> void:
	if event_id == "cooler_alarm":
		request("cooler_alarm")

func _on_time(_h: float) -> void:
	pass

func was_shown(hint_id: String) -> bool:
	return GameState.shown_hints.get(hint_id, false)
