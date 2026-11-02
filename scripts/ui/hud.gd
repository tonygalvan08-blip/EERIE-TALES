extends CanvasLayer
class_name GameHUD

var clock_label: Label
var objective_label: Label
var hint_label: Label
var prompt_label: Label
var subtitle_label: Label
var remark_label: Label
var chores_label: Label
var chores_panel: Control
var register_panel: Control
var reg_total: Label
var reg_items: Label
var reg_change: Label
var note_panel: Control
var note_text: Label
var pause_panel: Control
var hints_check: CheckButton
var tv_overlay: TextureRect
var end_card: Control
var scan_btn: Button
var change_box: HBoxContainer

var register: RegisterSystem
var hint_tween: Tween
var _bound: bool = false
var chores_visible: bool = false

func setup_from_tree() -> void:
	var root := $Root
	clock_label = root.get_node("Clock")
	objective_label = root.get_node("Objective")
	hint_label = root.get_node("Hint")
	prompt_label = root.get_node("Prompt")
	subtitle_label = root.get_node("Subtitle")
	remark_label = root.get_node("Remark")
	chores_panel = root.get_node("ChoresPanel")
	chores_label = chores_panel.find_child("Chores", true, false)
	register_panel = root.get_node("RegisterPanel")
	reg_total = register_panel.find_child("Total", true, false)
	reg_items = register_panel.find_child("Items", true, false)
	reg_change = register_panel.find_child("Change", true, false)
	scan_btn = register_panel.find_child("ScanBtn", true, false)
	change_box = register_panel.find_child("ChangeButtons", true, false)
	note_panel = root.get_node("NotePanel")
	note_text = note_panel.find_child("NoteText", true, false)
	pause_panel = root.get_node("PausePanel")
	hints_check = pause_panel.find_child("HintsToggle", true, false)
	tv_overlay = root.get_node("TVOverlay")
	end_card = root.get_node("EndCard")
	hint_label.modulate.a = 0.0
	prompt_label.text = ""
	subtitle_label.text = ""
	remark_label.text = ""
	register_panel.visible = false
	note_panel.visible = false
	pause_panel.visible = false
	end_card.visible = false
	tv_overlay.visible = false
	chores_panel.visible = false
	EventBus.objective_changed.connect(_on_objective)
	EventBus.jake_remark.connect(_on_remark)
	EventBus.dialogue_line.connect(_on_dialogue)
	EventBus.interactable_focused.connect(func(l): prompt_label.text = "[E] " + l)
	EventBus.interactable_unfocused.connect(func(): prompt_label.text = "")
	EventBus.time_changed.connect(func(_h): clock_label.text = GameState.format_clock())
	EventBus.note_read.connect(_show_note)
	EventBus.creature_on_tv.connect(_on_creature)
	EventBus.ending_finished.connect(_on_end)
	EventBus.chore_completed.connect(func(_id): _refresh_chores())
	HintManager.hint_shown.connect(_show_hint)
	HintManager.hint_hidden.connect(_hide_hint)
	HintManager.hints_toggled.connect(func(v): hints_check.button_pressed = v)
	hints_check.toggled.connect(func(v): HintManager.set_hints_enabled(v))
	hints_check.button_pressed = GameState.hints_enabled
	scan_btn.pressed.connect(_on_scan_pressed)
	_build_change_buttons()
	_on_objective(GameState.current_objective)
	_refresh_chores()
	clock_label.text = GameState.format_clock()
	_bound = true

func bind_register(reg: RegisterSystem) -> void:
	register = reg
	reg.transaction_opened.connect(_on_reg_open)
	reg.item_added.connect(_on_item)
	reg.change_updated.connect(_on_change)
	reg.transaction_complete.connect(_on_reg_done)

func _build_change_buttons() -> void:
	for child in change_box.get_children():
		child.queue_free()
	for amt in [20.0, 10.0, 5.0, 1.0, 0.25, 0.10, 0.05, 0.01]:
		var b := Button.new()
		if amt >= 1.0:
			b.text = "$%d" % int(amt)
		else:
			b.text = "%dc" % int(amt * 100)
		var captured: float = amt
		b.pressed.connect(func():
			if register:
				register.give_denomination(captured)
		)
		change_box.add_child(b)

func _process(_d: float) -> void:
	if not _bound:
		return
	if Input.is_action_just_pressed("pause_menu"):
		pause_panel.visible = not pause_panel.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if pause_panel.visible else Input.MOUSE_MODE_CAPTURED
	if Input.is_key_pressed(KEY_TAB) and Input.is_action_just_pressed("ui_focus_next") == false:
		pass
	if Input.is_physical_key_pressed(KEY_TAB):
		# edge detect via just pressed
		pass

func _unhandled_input(event: InputEvent) -> void:
	if not _bound:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_TAB:
		chores_visible = not chores_visible
		chores_panel.visible = chores_visible
		get_viewport().set_input_as_handled()
	if register and register.active and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if register.remaining_items() > 0:
			register.scan_next()

func _style_shadow(lab: Label) -> void:
	lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)

func _on_objective(t: String) -> void:
	objective_label.text = t
	_style_shadow(objective_label)

func _show_hint(_id: String, text: String) -> void:
	hint_label.text = text
	_style_shadow(hint_label)
	if hint_tween:
		hint_tween.kill()
	hint_tween = create_tween()
	hint_tween.tween_property(hint_label, "modulate:a", 1.0, 0.25)

func _hide_hint() -> void:
	if hint_tween:
		hint_tween.kill()
	hint_tween = create_tween()
	hint_tween.tween_property(hint_label, "modulate:a", 0.0, 0.5)

func _on_remark(t: String) -> void:
	remark_label.text = "Jake: " + t
	_style_shadow(remark_label)
	get_tree().create_timer(3.5).timeout.connect(func():
		if remark_label:
			remark_label.text = ""
	)

func _on_dialogue(speaker: String, text: String) -> void:
	subtitle_label.text = "%s: %s" % [speaker, text]
	_style_shadow(subtitle_label)
	get_tree().create_timer(3.0).timeout.connect(func():
		if subtitle_label and subtitle_label.text.ends_with(text):
			subtitle_label.text = ""
	)

func _show_note() -> void:
	note_panel.visible = true
	note_text.text = "NIGHT SHIFT RULES\n\n1. Clock in by 10:00 PM.\n2. Keep floors mopped.\n3. Restock cooler shelves.\n4. Take trash out before 2 AM.\n5. Clean the restroom once.\n6. Do NOT let anyone into the back after 2:00 AM.\n7. Answer the landline.\n8. Lock the pumps at dawn.\n\n— Marge (manager)\nP.S. Ignore the whispers. They're just the pipes."
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(6.0).timeout
	note_panel.visible = false
	if GameState.phase == "play":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_reg_open(_t: float, _c: float) -> void:
	register_panel.visible = true
	reg_total.text = "Total: $0.00"
	reg_items.text = "Scan items..."
	reg_change.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_item(p: Dictionary, total: float) -> void:
	reg_items.text = "Scanned: %s ($%.2f)" % [p.name, p.price]
	reg_total.text = "Total: $%.2f" % total

func _on_change(owed: float) -> void:
	if owed > 0.001:
		reg_change.text = "Change due: $%.2f — click bills/coins" % owed
	else:
		reg_change.text = "Change complete"

func _on_reg_done() -> void:
	register_panel.visible = false
	if GameState.phase == "play" and not pause_panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_scan_pressed() -> void:
	if register and register.active and register.remaining_items() > 0:
		register.scan_next()

func _on_creature(vis: bool) -> void:
	tv_overlay.visible = vis

func _on_end() -> void:
	end_card.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _refresh_chores() -> void:
	var lines: PackedStringArray = ["CHORES  (Tab to hide)"]
	for c in GameState.chores:
		var done := GameState.is_chore_done(str(c.id))
		var mark := "✓" if done else "○"
		lines.append("%s  %s" % [mark, c.name])
	chores_label.text = "\n".join(lines)
