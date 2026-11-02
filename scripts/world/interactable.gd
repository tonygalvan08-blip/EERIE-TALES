extends StaticBody3D
class_name Interactable

@export var interact_id: String = ""
@export var label: String = "Interact"
@export var one_shot: bool = false
var used: bool = false

signal interacted(player: Node)

func get_interact_label() -> String:
	return label if not used else ""

func interact(player: Node) -> void:
	if one_shot and used:
		return
	used = true
	interacted.emit(player)
	_on_interact(player)

func _on_interact(_player: Node) -> void:
	match interact_id:
		"timecard":
			if not GameState.clocked_in:
				GameState.clocked_in = true
				EventBus.clocked_in.emit()
				GameState.mark_chore("clock_in")
				GameState.set_objective("Read the manager's note")
				EventBus.jake_remark.emit("Alright... night shift. Let's do this.")
		"manager_note":
			GameState.note_read = true
			EventBus.note_read.emit()
			GameState.mark_chore("read_note")
			GameState.set_objective("Keep the store running — mop aisle 2")
		"spill_aisle2":
			GameState.mark_chore("mop_aisle2")
			GameState.set_objective("Restock the coolers when you can")
			EventBus.jake_remark.emit("Floor's clean. Good enough.")
		"cooler_stock":
			GameState.mark_chore("restock_cooler")
		"trash_bag":
			GameState.mark_chore("take_trash")
		"restroom_sink":
			GameState.mark_chore("clean_restroom")
		"cooler_door":
			GameState.mark_chore("check_coolers")
		"alarm_box":
			EventBus.alarm_cleared.emit()
			EventBus.jake_remark.emit("Alarm off. Come on...")
			if GameState.current_objective.begins_with("Shut off"):
				GameState.set_objective("Continue your shift")
		"phone":
			EventBus.phone_answered.emit("strange")
		"security_tv":
			pass
