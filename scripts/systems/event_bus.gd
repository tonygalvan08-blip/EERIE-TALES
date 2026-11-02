extends Node
## Global signal hub

signal cutscene_finished
signal player_ready
signal clocked_in
signal note_read
signal chore_completed(chore_id: String)
signal customer_arrived(customer: Node)
signal customer_at_register(customer: Node)
signal customer_left(customer: Node)
signal checkout_started(customer: Node)
signal item_scanned(product_id: String)
signal checkout_completed(customer: Node)
signal pump_customer_arrived(customer: Node)
signal dialogue_line(speaker: String, text: String)
signal jake_remark(text: String)
signal paranormal_event(event_id: String)
signal alarm_started
signal alarm_cleared
signal phone_ringing
signal phone_answered(call_type: String)
signal creature_on_tv(visible: bool)
signal candy_scene_started
signal candy_scene_finished
signal time_changed(hour: float)
signal dawn_reached
signal ending_started
signal ending_finished
signal objective_changed(text: String)
signal hint_requested(hint_id: String)
signal interactable_focused(label: String)
signal interactable_unfocused
