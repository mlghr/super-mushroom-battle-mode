class_name Utility

signal item_picked_up


func handle_item_picked_up(item_object: Node2D, optional_funcs: Array = []):
	item_object.queue_free()
	
	if optional_funcs.size() <= 0:
		pass
