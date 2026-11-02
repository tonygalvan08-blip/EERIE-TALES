extends Node
## Persistent run state: time, flags, settings

const SHIFT_START := 22.0  # 10 PM
const SHIFT_END := 6.0     # 6 AM (next day)
## Real seconds for full shift (~90 min). Debug timescale shortens this.
const REAL_SECONDS_PER_SHIFT := 90.0 * 60.0

var game_hour: float = SHIFT_START
var real_elapsed: float = 0.0
var time_scale: float = 1.0  # multiply with T key cycles
var debug_fast: bool = false

var phase: String = "cutscene"  # cutscene | play | ending
var clocked_in: bool = false
var note_read: bool = false
var candy_done: bool = false
var paranormal_unlocked: bool = false
var ending_triggered: bool = false

var chores_done: Dictionary = {}
var hints_enabled: bool = true
var shown_hints: Dictionary = {}

var products: Array = []
var dialogue: Dictionary = {}
var events: Array = []
var chores: Array = []
var customers_data: Array = []
var hints_data: Dictionary = {}

var money_in_drawer: float = 150.0
var current_objective: String = "Arrive at Eerie Springs Gas"

func _ready() -> void:
	_load_data()
	if OS.has_feature("editor") or OS.get_environment("EERIE_FAST") == "1":
		debug_fast = true
		time_scale = 20.0

func _load_data() -> void:
	products = _json("res://data/products.json")
	dialogue = _json("res://data/dialogue.json")
	events = _json("res://data/paranormal_events.json")
	chores = _json("res://data/chores.json")
	customers_data = _json("res://data/customers.json")
	hints_data = _json("res://data/hints.json")

func _json(path: String):
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Missing data: " + path)
		return {} if path.ends_with("dialogue.json") or path.ends_with("hints.json") else []
	return JSON.parse_string(f.get_as_text())

func _process(delta: float) -> void:
	if phase != "play":
		return
	if Input.is_action_just_pressed("debug_timescale"):
		_cycle_timescale()
	var hours_per_second := _hours_span() / REAL_SECONDS_PER_SHIFT
	game_hour = _advance_hour(game_hour, hours_per_second * delta * time_scale)
	real_elapsed += delta
	EventBus.time_changed.emit(game_hour)
	if not ending_triggered and _past_dawn():
		ending_triggered = true
		EventBus.dawn_reached.emit()

func _hours_span() -> float:
	# 22 -> 6 = 8 hours
	return 8.0

func _advance_hour(h: float, dh: float) -> float:
	h += dh
	while h >= 24.0:
		h -= 24.0
	return h

func _past_dawn() -> bool:
	# Crossed midnight and reached 6:00
	return game_hour >= 0.0 and game_hour < 12.0 and game_hour >= SHIFT_END and real_elapsed > 10.0

func _cycle_timescale() -> void:
	if time_scale < 2.0:
		time_scale = 5.0
	elif time_scale < 10.0:
		time_scale = 20.0
	elif time_scale < 40.0:
		time_scale = 60.0
	else:
		time_scale = 1.0
	print("Time scale: ", time_scale, "x")

func format_clock() -> String:
	var h := int(floor(game_hour)) % 24
	var m := int(floor(fmod(game_hour, 1.0) * 60.0))
	var ampm := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, m, ampm]

func set_objective(text: String) -> void:
	current_objective = text
	EventBus.objective_changed.emit(text)

func mark_chore(id: String) -> void:
	chores_done[id] = true
	EventBus.chore_completed.emit(id)

func is_chore_done(id: String) -> bool:
	return chores_done.get(id, false)

func get_product(id: String) -> Dictionary:
	for p in products:
		if p.id == id:
			return p
	return {}

func intensity() -> float:
	# 0 at start -> 1 near dawn, boosted after candy
	var t: float
	if game_hour >= 22.0:
		t = (game_hour - 22.0) / 8.0
	else:
		t = (game_hour + 2.0) / 8.0
	t = clampf(t, 0.0, 1.0)
	if paranormal_unlocked:
		t = minf(1.0, t + 0.15)
	return t
