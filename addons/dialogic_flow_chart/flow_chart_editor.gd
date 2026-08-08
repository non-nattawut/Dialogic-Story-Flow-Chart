@tool
class_name FlowChartEditor
extends Control

var current_flow_chart: FlowChartData
var current_resource_path: String = "res://example/demo_flowchart.tres"
var selected_node_data: FlowChartNodeData

@onready var graph_edit: GraphEdit = $MainVBox/HSplitContainer/GraphEdit
@onready var inspector_panel: VBoxContainer = $MainVBox/HSplitContainer/InspectorScroll/InspectorVBox

@onready var btn_new: Button = $MainVBox/Toolbar/BtnNew
@onready var btn_open: Button = $MainVBox/Toolbar/BtnOpen
@onready var btn_save: Button = $MainVBox/Toolbar/BtnSave
@onready var btn_save_as: Button = $MainVBox/Toolbar/BtnSaveAs
@onready var btn_add_node: Button = $MainVBox/Toolbar/BtnAddNode
@onready var current_file_label: Label = $MainVBox/Toolbar/CurrentFileLabel

# Form Fields
var title_field: LineEdit
var timeline_path_field: LineEdit
var default_next_field: LineEdit

var file_dialog: EditorFileDialog
var confirm_dialog: ConfirmationDialog
var pending_action: Callable

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	if btn_new != null:
		btn_new.pressed.connect(func(): _confirm_unsaved_changes(_do_new_chart))
	if btn_open != null:
		btn_open.pressed.connect(func(): _confirm_unsaved_changes(_on_open_file_dialog))
	if btn_save != null:
		btn_save.pressed.connect(_on_save_chart)
	if btn_save_as != null:
		btn_save_as.pressed.connect(_on_save_as_file_dialog)
	if btn_add_node != null:
		btn_add_node.pressed.connect(_on_add_timeline_node)

	if graph_edit != null:
		graph_edit.node_selected.connect(_on_node_selected)
		graph_edit.connection_request.connect(_on_connection_request)
		graph_edit.disconnection_request.connect(_on_disconnection_request)
		if graph_edit.has_signal("delete_nodes_request"):
			graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
		if graph_edit.has_signal("end_node_move"):
			graph_edit.end_node_move.connect(_sync_node_positions_from_graph)

	_build_inspector_fields()
	_setup_confirm_dialog()

	# Auto-load existing demo flowchart
	if FileAccess.file_exists(current_resource_path):
		var res: FlowChartData = load(current_resource_path) as FlowChartData
		if res != null:
			load_flow_chart(res, current_resource_path)
		else:
			_do_new_chart()
	else:
		_do_new_chart()

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
		_handle_file_dropped(at_position, dtl_path)

func _handle_file_dropped(at_position: Vector2, dtl_path: String) -> void:
	_sync_node_positions_from_graph()
	if current_flow_chart == null:
		_do_new_chart()

	var time_stamp: String = str(Time.get_ticks_msec())
	var new_id: String = "node_" + time_stamp
	var node: FlowChartNodeData = FlowChartNodeData.new()
	node.node_id = new_id
	var file_name: String = dtl_path.get_file().get_basename()
	node.title = file_name.capitalize()
	node.timeline_path = dtl_path
	
	# Calculate position in graph
	var graph_pos: Vector2 = at_position
	if graph_edit != null:
		graph_pos = (at_position + graph_edit.scroll_offset) / graph_edit.zoom
	node.position = graph_pos

	current_flow_chart.add_node(node)
	_save_current_chart_silent()
	_refresh_graph()

func _bind_timeline_to_node(node_id: String, dtl_path: String) -> void:
	if current_flow_chart == null:
		return
	var node_data: FlowChartNodeData = current_flow_chart.get_node_by_id(node_id)
	if node_data != null:
		node_data.timeline_path = dtl_path
		node_data.title = dtl_path.get_file().get_basename().capitalize()
		_save_current_chart_silent()
		_refresh_graph()

func _setup_confirm_dialog() -> void:
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Save Flow Chart Changes?"
	confirm_dialog.dialog_text = "Do you want to save changes to the current flowchart before proceeding?"
	confirm_dialog.ok_button_text = "Save"
	confirm_dialog.add_cancel_button("Don't Save")
	
	confirm_dialog.confirmed.connect(func():
		_on_save_chart()
		if pending_action.is_valid():
			pending_action.call()
	)
	confirm_dialog.custom_action.connect(func(action):
		if action == "Don't Save" and pending_action.is_valid():
			confirm_dialog.hide()
			pending_action.call()
	)
	add_child(confirm_dialog)

func _confirm_unsaved_changes(action: Callable) -> void:
	pending_action = action
	if confirm_dialog != null:
		confirm_dialog.popup_centered()
	else:
		action.call()

func _build_inspector_fields() -> void:
	if inspector_panel == null:
		return

	for child in inspector_panel.get_children():
		child.queue_free()

	var label_heading: Label = Label.new()
	label_heading.text = "Timeline Node Inspector"
	label_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspector_panel.add_child(label_heading)

	inspector_panel.add_child(HSeparator.new())

	title_field = _add_field("Node Title:")
	title_field.text_changed.connect(_on_title_changed)

	timeline_path_field = _add_field("Dialogic Timeline (.dtl) Path:")
	timeline_path_field.text_changed.connect(func(val):
		if selected_node_data:
			selected_node_data.timeline_path = val
			_save_current_chart_silent()
			_refresh_graph()
	)

	default_next_field = _add_field("Default Next Timeline ID:")
	default_next_field.text_changed.connect(func(val):
		if selected_node_data:
			selected_node_data.default_next_node_id = val
			_save_current_chart_silent()
	)

	var btn_open_dialogic: Button = Button.new()
	btn_open_dialogic.text = "Open Timeline in Dialogic Editor"
	btn_open_dialogic.pressed.connect(_on_open_timeline_file)
	inspector_panel.add_child(btn_open_dialogic)

func _add_field(title: String) -> LineEdit:
	var lbl: Label = Label.new()
	lbl.text = title
	inspector_panel.add_child(lbl)
	var line: LineEdit = LineEdit.new()
	inspector_panel.add_child(line)
	return line

func load_flow_chart(chart: FlowChartData, path: String = "") -> void:
	current_flow_chart = chart
	if not path.is_empty():
		current_resource_path = path
	if current_file_label != null:
		current_file_label.text = "File: " + current_resource_path
	_refresh_graph()

func _do_new_chart() -> void:
	current_flow_chart = FlowChartData.new()
	current_flow_chart.start_node_id = "start"

	var start_node: FlowChartNodeData = FlowChartNodeData.new()
	start_node.node_id = "start"
	start_node.title = "Start Scene"
	start_node.timeline_path = "res://example/timelines/start.dtl"
	start_node.position = Vector2(80, 140)
	current_flow_chart.add_node(start_node)

	current_resource_path = "res://example/new_flowchart.tres"
	if current_file_label != null:
		current_file_label.text = "File: " + current_resource_path
	_refresh_graph()

func _save_current_chart_silent() -> void:
	if current_flow_chart != null and not current_resource_path.is_empty():
		_sync_node_positions_from_graph()
		ResourceSaver.save(current_flow_chart, current_resource_path)

func _on_save_chart() -> void:
	if current_flow_chart == null:
		return
	_sync_node_positions_from_graph()
	if current_resource_path.is_empty():
		_on_save_as_file_dialog()
		return
	ResourceSaver.save(current_flow_chart, current_resource_path)
	print("Saved Flow Chart to: ", current_resource_path)
	if current_file_label != null:
		current_file_label.text = "File: " + current_resource_path

func _on_save_as_file_dialog() -> void:
	if Engine.is_editor_hint():
		file_dialog = EditorFileDialog.new()
		file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		file_dialog.add_filter("*.tres", "FlowChart Data Resource")
		file_dialog.file_selected.connect(func(path):
			current_resource_path = path
			_on_save_chart()
			file_dialog.queue_free()
		)
		add_child(file_dialog)
		file_dialog.popup_centered_ratio(0.6)

func _on_open_file_dialog() -> void:
	if Engine.is_editor_hint():
		file_dialog = EditorFileDialog.new()
		file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		file_dialog.add_filter("*.tres", "FlowChart Data Resource")
		file_dialog.file_selected.connect(func(path):
			var res: FlowChartData = load(path) as FlowChartData
			if res != null:
				load_flow_chart(res, path)
			file_dialog.queue_free()
		)
		add_child(file_dialog)
		file_dialog.popup_centered_ratio(0.6)

func _on_add_timeline_node() -> void:
	_sync_node_positions_from_graph()

	if current_flow_chart == null:
		_do_new_chart()

	if Engine.is_editor_hint():
		var dtl_dialog: EditorFileDialog = EditorFileDialog.new()
		dtl_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		dtl_dialog.add_filter("*.dtl", "Dialogic Timeline File")
		dtl_dialog.current_dir = "res://example/timelines/"
		dtl_dialog.current_file = "new_timeline.dtl"
		dtl_dialog.file_selected.connect(func(dtl_path: String):
			_create_and_bind_new_dtl(dtl_path)
			dtl_dialog.queue_free()
		)
		add_child(dtl_dialog)
		dtl_dialog.popup_centered_ratio(0.6)
	else:
		var default_path: String = "res://example/timelines/timeline_" + str(Time.get_ticks_msec()) + ".dtl"
		_create_and_bind_new_dtl(default_path)

func _create_and_bind_new_dtl(dtl_path: String) -> void:
	if not FileAccess.file_exists(dtl_path):
		var file: FileAccess = FileAccess.open(dtl_path, FileAccess.WRITE)
		if file != null:
			file.store_string("")
			file.close()
			print("Created clean empty DTL timeline file: ", dtl_path)
			if Engine.is_editor_hint():
				EditorInterface.get_resource_filesystem().scan()

	var base_name: String = dtl_path.get_file().get_basename()
	var node: FlowChartNodeData = FlowChartNodeData.new()
	node.node_id = base_name + "_" + str(Time.get_ticks_msec())
	node.title = base_name.capitalize()
	node.timeline_path = dtl_path
	node.position = Vector2(300, 140)
	current_flow_chart.add_node(node)
	_save_current_chart_silent()
	_refresh_graph()

func _on_delete_nodes_request(node_names: Array) -> void:
	_sync_node_positions_from_graph()

	if current_flow_chart == null:
		return

	for node_name: Variant in node_names:
		var id_str: String = String(node_name)
		var deleted_node: FlowChartNodeData = current_flow_chart.get_node_by_id(id_str)
		if deleted_node != null:
			var target_name: String = deleted_node.get_timeline_name()
			for n: FlowChartNodeData in current_flow_chart.nodes:
				if n.default_next_node_id == id_str:
					_remove_jump_from_timeline(n.timeline_path, target_name)
					n.default_next_node_id = ""
				for choice: Dictionary in n.choices:
					if choice.get("target_node_id", "") == id_str:
						_remove_jump_from_timeline(n.timeline_path, target_name)

			current_flow_chart.remove_node_by_id(id_str)

	_save_current_chart_silent()
	_refresh_graph()

func _sync_node_positions_from_graph() -> void:
	if graph_edit == null or current_flow_chart == null:
		return
	for child in graph_edit.get_children():
		if child is GraphNode:
			var node_data: FlowChartNodeData = current_flow_chart.get_node_by_id(child.name)
			if node_data != null:
				node_data.position = child.position_offset

func _refresh_graph() -> void:
	if graph_edit == null or current_flow_chart == null:
		return

	_sync_node_positions_from_graph()

	# 1. Remove nodes no longer in current_flow_chart
	for child in graph_edit.get_children():
		if child is GraphNode:
			if current_flow_chart.get_node_by_id(child.name) == null:
				child.queue_free()

	# 2. Add missing nodes or update existing ones
	for node_data: FlowChartNodeData in current_flow_chart.nodes:
		var gnode: GraphNode = graph_edit.get_node_or_null(node_data.node_id) as GraphNode
		if gnode == null:
			gnode = GraphNode.new()
			gnode.name = node_data.node_id
			gnode.title = node_data.title
			gnode.position_offset = node_data.position
			
			gnode.custom_minimum_size = Vector2(180, 60)
			gnode.resizable = false

			var header_hbox: HBoxContainer = HBoxContainer.new()

			var path_lbl: Label = Label.new()
			path_lbl.name = "PathLabel"
			var short_name: String = node_data.timeline_path.get_file() if not node_data.timeline_path.is_empty() else "(No DTL File)"
			path_lbl.text = short_name
			path_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			path_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			header_hbox.add_child(path_lbl)

			var del_btn: Button = Button.new()
			del_btn.text = "✕"
			del_btn.flat = true
			del_btn.pressed.connect(func(): _on_delete_nodes_request([gnode.name]))
			header_hbox.add_child(del_btn)

			gnode.add_child(header_hbox)

			# Double click on GraphNode to switch tab directly to Dialogic
			gnode.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
					accept_event()
					_open_timeline_in_dialogic(node_data.timeline_path)
			)

			# Slot 0: Input & Output
			gnode.set_slot(0, true, 0, Color.WHITE, true, 0, Color.GREEN)

			graph_edit.add_child(gnode)
		else:
			gnode.title = node_data.title
			gnode.position_offset = node_data.position
			var lbl: Label = gnode.get_node_or_null("HeaderHBox/PathLabel") as Label
			if lbl != null:
				lbl.text = node_data.timeline_path.get_file() if not node_data.timeline_path.is_empty() else "(No DTL File)"

	# Defer connection restoration by 1 frame
	if is_inside_tree():
		await get_tree().process_frame

	graph_edit.clear_connections()
	for node_data: FlowChartNodeData in current_flow_chart.nodes:
		if not node_data.default_next_node_id.is_empty():
			if current_flow_chart.get_node_by_id(node_data.default_next_node_id) != null:
				graph_edit.connect_node(node_data.node_id, 0, node_data.default_next_node_id, 0)
		for choice: Dictionary in node_data.choices:
			var target_id: String = choice.get("target_node_id", "")
			if not target_id.is_empty() and current_flow_chart.get_node_by_id(target_id) != null:
				graph_edit.connect_node(node_data.node_id, 0, target_id, 0)

func _on_node_selected(node: Node) -> void:
	if current_flow_chart == null:
		return
	selected_node_data = current_flow_chart.get_node_by_id(node.name)
	if selected_node_data != null:
		title_field.text = selected_node_data.title
		timeline_path_field.text = selected_node_data.timeline_path
		default_next_field.text = selected_node_data.default_next_node_id

func _on_title_changed(new_title: String) -> void:
	if selected_node_data != null:
		selected_node_data.title = new_title
		_save_current_chart_silent()
		if graph_edit.has_node(selected_node_data.node_id):
			var gnode: GraphNode = graph_edit.get_node(selected_node_data.node_id) as GraphNode
			if gnode != null:
				gnode.title = new_title

func _on_open_timeline_file() -> void:
	if selected_node_data != null and not selected_node_data.timeline_path.is_empty():
		_open_timeline_in_dialogic(selected_node_data.timeline_path)

func _open_timeline_in_dialogic(dtl_path: String) -> void:
	if dtl_path.is_empty() or not FileAccess.file_exists(dtl_path):
		return
	var res: Resource = load(dtl_path)
	if res != null and Engine.is_editor_hint():
		if is_inside_tree():
			get_tree().create_timer(0.08).timeout.connect(func():
				EditorInterface.set_main_screen_editor("Dialogic")
				EditorInterface.edit_resource(res)
			, CONNECT_ONE_SHOT)

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	var from_data: FlowChartNodeData = current_flow_chart.get_node_by_id(String(from_node))
	var to_data: FlowChartNodeData = current_flow_chart.get_node_by_id(String(to_node))

	if from_data != null and to_data != null:
		from_data.default_next_node_id = String(to_node)
		_inject_jump_to_timeline(from_data.timeline_path, to_data.get_timeline_name())
		_save_current_chart_silent()

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	var from_data: FlowChartNodeData = current_flow_chart.get_node_by_id(String(from_node))
	var to_data: FlowChartNodeData = current_flow_chart.get_node_by_id(String(to_node))

	if from_data != null and to_data != null:
		_remove_jump_from_timeline(from_data.timeline_path, to_data.get_timeline_name())

	if from_data != null and from_data.default_next_node_id == String(to_node):
		from_data.default_next_node_id = ""

	_save_current_chart_silent()

func _is_jump_to_target(line: String, target_timeline_name: String) -> bool:
	var target_clean: String = target_timeline_name.get_file().trim_suffix(".dtl").strip_edges()
	if target_clean.is_empty():
		return false
	var s: String = line.strip_edges()
	if not s.begins_with("jump "):
		return false
	var dest: String = s.trim_prefix("jump ").strip_edges()
	if dest.ends_with("/"):
		dest = dest.trim_suffix("/").strip_edges()
	elif "/" in dest and not dest.begins_with("res://"):
		dest = dest.split("/")[0].strip_edges()
	var dest_clean: String = dest.get_file().trim_suffix(".dtl").strip_edges()
	return dest_clean == target_clean

func _inject_jump_to_timeline(source_dtl_path: String, target_timeline_name: String) -> void:
	var target_clean: String = target_timeline_name.get_file().trim_suffix(".dtl").strip_edges()
	if source_dtl_path.is_empty() or target_clean.is_empty():
		return
	if not FileAccess.file_exists(source_dtl_path):
		return

	var file: FileAccess = FileAccess.open(source_dtl_path, FileAccess.READ)
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()

	var has_jump: bool = false
	for line: String in content.split("\n"):
		if _is_jump_to_target(line, target_clean):
			has_jump = true
			break

	if not has_jump:
		content = content.strip_edges()
		if not content.is_empty():
			content += "\n"
		content += "jump " + target_clean + "/\n"

		var write_file: FileAccess = FileAccess.open(source_dtl_path, FileAccess.WRITE)
		if write_file != null:
			write_file.store_string(content)
			write_file.close()
			print("Injected jump into [", source_dtl_path, "]: jump ", target_clean, "/")
			if Engine.is_editor_hint():
				EditorInterface.get_resource_filesystem().scan()

func _remove_jump_from_timeline(source_dtl_path: String, target_timeline_name: String) -> void:
	if source_dtl_path.is_empty() or target_timeline_name.is_empty():
		return
	if not FileAccess.file_exists(source_dtl_path):
		return

	var file: FileAccess = FileAccess.open(source_dtl_path, FileAccess.READ)
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()

	var lines: PackedStringArray = content.split("\n")
	var new_lines: Array = []
	var modified: bool = false

	for line: String in lines:
		if _is_jump_to_target(line, target_timeline_name):
			modified = true
		else:
			new_lines.append(line)

	if modified:
		var new_content: String = "\n".join(new_lines)
		var write_file: FileAccess = FileAccess.open(source_dtl_path, FileAccess.WRITE)
		if write_file != null:
			write_file.store_string(new_content)
			write_file.close()
			print("Removed jump from [", source_dtl_path, "]: ", target_timeline_name)
			if Engine.is_editor_hint():
				EditorInterface.get_resource_filesystem().scan()
