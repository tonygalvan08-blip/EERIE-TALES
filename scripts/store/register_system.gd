extends Node
class_name RegisterSystem
## Scan items, total, accept cash, make correct change.

signal transaction_opened(total: float, cash_given: float)
signal item_added(product: Dictionary, new_total: float)
signal change_updated(owed: float)
signal transaction_complete
signal transaction_cancelled

var active: bool = false
var customer: Node = null
var cart: Array = []
var total: float = 0.0
var cash_tendered: float = 0.0
var change_owed: float = 0.0
var change_given: float = 0.0

const BILLS := [20.0, 10.0, 5.0, 1.0]
const COINS := [0.25, 0.10, 0.05, 0.01]

func start_transaction(c: Node, product_ids: Array) -> void:
	customer = c
	cart.clear()
	total = 0.0
	cash_tendered = 0.0
	change_owed = 0.0
	change_given = 0.0
	active = true
	for id in product_ids:
		var p: Dictionary = GameState.get_product(id)
		if not p.is_empty():
			cart.append(p)
	EventBus.checkout_started.emit(c)
	transaction_opened.emit(total, 0.0)

func scan_next() -> Dictionary:
	if not active or cart.is_empty():
		return {}
	# Move from unscanned conceptually — here cart holds unscanned; we scan one
	var p: Dictionary = cart.pop_front()
	total = snappedf(total + float(p.price), 0.01)
	EventBus.item_scanned.emit(str(p.id))
	item_added.emit(p, total)
	_play("res://assets/audio/register_beep.wav")
	if cart.is_empty():
		_tender()
	return p

func remaining_items() -> int:
	return cart.size()

func all_scanned() -> bool:
	return active and cart.is_empty() and total > 0.0

func _tender() -> void:
	# Customer pays with a bill covering total
	var bill := 5.0
	if total > 20.0:
		bill = 50.0
	elif total > 10.0:
		bill = 20.0
	elif total > 5.0:
		bill = 10.0
	elif total > 1.0:
		bill = 5.0
	else:
		bill = 1.0
	# sometimes exact-ish
	if randf() < 0.25:
		bill = ceil(total)
	cash_tendered = bill
	change_owed = snappedf(cash_tendered - total, 0.01)
	change_given = 0.0
	change_updated.emit(change_owed)
	_play("res://assets/audio/cash_drawer.wav")

func give_denomination(amount: float) -> void:
	if not active or change_owed <= 0.0:
		return
	if amount > change_owed + 0.001:
		return  # don't overpay incorrectly — require exact path
	change_given = snappedf(change_given + amount, 0.01)
	var remaining := snappedf(change_owed - change_given, 0.01)
	change_updated.emit(remaining)
	if remaining <= 0.001:
		_complete()

func give_correct_auto() -> void:
	## Helper for tests / accessibility
	change_given = change_owed
	change_updated.emit(0.0)
	_complete()

func _complete() -> void:
	GameState.money_in_drawer = snappedf(GameState.money_in_drawer + total, 0.01)
	active = false
	transaction_complete.emit()
	EventBus.checkout_completed.emit(customer)
	if customer and customer.has_method("begin_leave"):
		customer.begin_leave()
	customer = null

func cancel() -> void:
	active = false
	customer = null
	transaction_cancelled.emit()

func _play(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
