extends Node

func _input(event: InputEvent) -> void:
	if event.is_action("Quit"):
		get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("quitting...")
		get_tree().quit() # default behavior
