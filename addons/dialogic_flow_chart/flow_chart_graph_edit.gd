@tool
class_name FlowChartGraphEdit
extends GraphEdit

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) == TYPE_DICTIONARY:
		var type: String = data.get("type", "")
		if type == "files" or type == "files_and_dirs":
			var files: PackedStringArray = data.get("files", [])
			if files.size() > 0 and files[0].ends_with(".dtl"):
				return true
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		var files: PackedStringArray = data.get("files", [])
		var dtl_path: String = files[0]
		var main_vbox: Node = get_parent()
		if main_vbox != null and main_vbox.get_parent() is FlowChartEditor:
			var editor: FlowChartEditor = main_vbox.get_parent() as FlowChartEditor
			editor._handle_file_dropped(at_position, dtl_path)
