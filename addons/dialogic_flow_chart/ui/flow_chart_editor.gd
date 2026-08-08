@tool
class_name FlowChartEditor
extends Control

var current_flow_chart: FlowChartData
var current_resource_path: String = "res://example/demo_flowchart.tres"

@onready var graph_edit: GraphEdit = $MainVBox/HSplitContainer/GraphEdit
@onready var inspector_panel: VBoxContainer = $MainVBox/HSplitContainer/InspectorScroll/InspectorVBox

@onready var btn_new: Button = $MainVBox/Toolbar/BtnNew
@onready var btn_open: Button = $MainVBox/Toolbar/BtnOpen
@onready var btn_save: Button = $MainVBox/Toolbar/BtnSave
@onready var btn_save_as: Button = $MainVBox/Toolbar/BtnSaveAs
@onready var btn_add_node: Button = $MainVBox/Toolbar/BtnAddNode
@onready var current_file_label: Label = $MainVBox/Toolbar/CurrentFileLabel

var inspector_manager: FlowChartInspectorManager
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
		graph_edit.right_disconnects = false
		graph_edit.node_selected.connect(_on_node_selected)
		graph_edit.connection_request.connect(_on_connection_request)
		graph_edit.disconnection_request.connect(_on_disconnection_request)
		if graph_edit.has_signal("popup_request"):
			graph_edit.popup_request.connect(_on_graph_popup_request)
		if graph_edit.has_signal("delete_nodes_request"):
			graph_edit.delete_nodes_request.connect(_on_delete_nodes_request)
		if graph_edit.has_signal("end_node_move"):
			graph_edit.end_node_move.connect(_sync_node_positions_from_graph)

	inspector_manager = FlowChartInspectorManager.new()
	inspector_manager.setup(inspector_panel, _refresh_graph, _save_current_chart_silent, _open_timeline_in_dialogic)
	_setup_confirm_dialog()

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
		_handle_file_dropped(at_position, files[0])

func _handle_file_dropped(at_position: Vector2, dtl_path: String) -> void:
	_sync_node_positions_from_graph()
	if current_flow_chart == null:
		_do_new_chart()

	var node: FlowChartNodeData = FlowChartNodeData.new()
	node.node_id = "node_" + str(Time.get_ticks_msec())
	node.title = dtl_path.get_file().get_basename().capitalize()
	node.timeline_path = dtl_path
	
	var graph_pos: Vector2 = at_position
	if graph_edit != null:
		graph_pos = (at_position + graph_edit.scroll_offset) / graph_edit.zoom
	node.position = graph_pos

	current_flow_chart.add_node(node)
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
		FlowChartFileManager.save_flowchart_silent(current_flow_chart, current_resource_path)

func _on_save_chart() -> void:
	if current_flow_chart == null:
		return
	_sync_node_positions_from_graph()
	if current_resource_path.is_empty():
		_on_save_as_file_dialog()
		return
	FlowChartFileManager.save_flowchart_silent(current_flow_chart, current_resource_path)
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
	FlowChartFileManager.create_empty_dtl(dtl_path)
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
					FlowChartFileManager.remove_jump(n.timeline_path, target_name)
					n.default_next_node_id = ""
				for choice: Dictionary in n.choices:
					if choice.get("target_node_id", "") == id_str:
						var c_text: String = choice.get("text", "")
						FlowChartFileManager.remove_choice_jump(n.timeline_path, c_text, target_name)

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

	for child in graph_edit.get_children():
		if child is GraphNode:
			if current_flow_chart.get_node_by_id(child.name) == null:
				child.queue_free()

	for node_data: FlowChartNodeData in current_flow_chart.nodes:
		var choices: Array[Dictionary] = FlowChartFileManager.get_choices_from_dtl(node_data.timeline_path)
		var gnode: GraphNode = graph_edit.get_node_or_null(NodePath(node_data.node_id)) as GraphNode
		var is_new: bool = (gnode == null)
		if is_new:
			gnode = GraphNode.new()
			gnode.name = node_data.node_id
			gnode.title = node_data.title
			gnode.position_offset = node_data.position
			gnode.custom_minimum_size = Vector2(240, 70)
			gnode.resizable = false

			var header_hbox: HBoxContainer = HBoxContainer.new()
			header_hbox.name = "HeaderHBox"

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

			gnode.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
					accept_event()
					_open_timeline_in_dialogic(node_data.timeline_path)
			)

			graph_edit.add_child(gnode)
		else:
			gnode.title = node_data.title
			gnode.position_offset = node_data.position
			var lbl: Label = gnode.get_node_or_null("HeaderHBox/PathLabel") as Label
			if lbl != null:
				lbl.text = node_data.timeline_path.get_file() if not node_data.timeline_path.is_empty() else "(No DTL File)"

		# Clear old choice labels & footers immediately
		gnode.clear_all_slots()
		gnode.set_slot(0, true, 0, Color.WHITE, true, 0, Color.GREEN)

		for child in gnode.get_children():
			if child != null and (child.name.begins_with("ChoiceSlot_") or child.name == "AddChoiceFooter"):
				gnode.remove_child(child)
				child.queue_free()

		# Build choice slots with inline LineEdit and Delete button
		for c_idx in range(choices.size()):
			var choice_info: Dictionary = choices[c_idx]
			var c_text: String = choice_info.get("text", "")
			
			var choice_hbox: HBoxContainer = HBoxContainer.new()
			choice_hbox.name = "ChoiceSlot_" + str(c_idx)
			choice_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			var prefix_lbl: Label = Label.new()
			prefix_lbl.text = "-"
			choice_hbox.add_child(prefix_lbl)

			var line_edit: LineEdit = LineEdit.new()
			line_edit.name = "ChoiceEdit"
			line_edit.text = c_text
			line_edit.placeholder_text = "Choice text..."
			line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line_edit.flat = true
			
			var dtl_p: String = node_data.timeline_path
			var old_t: String = c_text
			line_edit.text_submitted.connect(func(new_text: String):
				var trimmed: String = new_text.strip_edges()
				if not trimmed.is_empty() and trimmed != old_t:
					FlowChartFileManager.rename_choice_in_dtl(dtl_p, old_t, trimmed)
					node_data.set_choice_target(trimmed, node_data.get_choice_target(old_t))
					_save_current_chart_silent()
					_refresh_graph()
			)
			line_edit.focus_exited.connect(func():
				var trimmed: String = line_edit.text.strip_edges()
				if not trimmed.is_empty() and trimmed != old_t:
					FlowChartFileManager.rename_choice_in_dtl(dtl_p, old_t, trimmed)
					node_data.set_choice_target(trimmed, node_data.get_choice_target(old_t))
					_save_current_chart_silent()
					_refresh_graph()
			)
			choice_hbox.add_child(line_edit)

			var del_choice_btn: Button = Button.new()
			del_choice_btn.text = "✕"
			del_choice_btn.flat = true
			del_choice_btn.pressed.connect(func():
				FlowChartFileManager.delete_choice_from_dtl(dtl_p, old_t)
				_save_current_chart_silent()
				_refresh_graph()
			)
			choice_hbox.add_child(del_choice_btn)

			gnode.add_child(choice_hbox)
			
			var slot_idx: int = c_idx + 1
			gnode.set_slot(slot_idx, false, 0, Color.WHITE, true, 0, Color(0.2, 0.7, 1.0, 1.0))

		# Build "+ Add Choice" Footer Button
		var footer_hbox: HBoxContainer = HBoxContainer.new()
		footer_hbox.name = "AddChoiceFooter"
		footer_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var add_btn: Button = Button.new()
		add_btn.text = "+ Add Choice"
		add_btn.flat = true
		add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var target_dtl: String = node_data.timeline_path
		add_btn.pressed.connect(func():
			FlowChartFileManager.add_choice_to_dtl(target_dtl, "New Choice")
			_save_current_chart_silent()
			_refresh_graph()
		)
		footer_hbox.add_child(add_btn)

		gnode.add_child(footer_hbox)
		var footer_slot: int = choices.size() + 1
		gnode.set_slot(footer_slot, false, 0, Color.WHITE, false, 0, Color.WHITE)

	if is_inside_tree():
		await get_tree().process_frame

	graph_edit.clear_connections()
	for node_data: FlowChartNodeData in current_flow_chart.nodes:
		if not node_data.default_next_node_id.is_empty():
			if current_flow_chart.get_node_by_id(node_data.default_next_node_id) != null:
				graph_edit.connect_node(node_data.node_id, 0, node_data.default_next_node_id, 0)

		var choices: Array[Dictionary] = FlowChartFileManager.get_choices_from_dtl(node_data.timeline_path)
		for c_idx in range(choices.size()):
			var choice_info: Dictionary = choices[c_idx]
			var c_text: String = choice_info.get("text", "")
			var target_name: String = choice_info.get("target_timeline", "")
			var target_node_id: String = node_data.get_choice_target(c_text)

			if target_node_id.is_empty() and not target_name.is_empty():
				for target_node: FlowChartNodeData in current_flow_chart.nodes:
					if target_node.get_timeline_name() == target_name:
						target_node_id = target_node.node_id
						node_data.set_choice_target(c_text, target_node_id)
						break

			if not target_node_id.is_empty() and current_flow_chart.get_node_by_id(target_node_id) != null:
				graph_edit.connect_node(node_data.node_id, c_idx + 1, target_node_id, 0)

func _on_node_selected(node: Node) -> void:
	if current_flow_chart == null:
		return
	var selected: FlowChartNodeData = current_flow_chart.get_node_by_id(node.name)
	if inspector_manager != null:
		inspector_manager.select_node(selected)

func _open_timeline_in_dialogic(dtl_path: String) -> void:
	if dtl_path.is_empty() or not FileAccess.file_exists(dtl_path):
		return
	FlowChartFileManager.force_reload_resource(dtl_path)
	var res: Resource = ResourceLoader.load(dtl_path, "", ResourceLoader.CACHE_MODE_REPLACE)
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
		var choices: Array[Dictionary] = FlowChartFileManager.get_choices_from_dtl(from_data.timeline_path)
		if from_port == 0:
			from_data.default_next_node_id = String(to_node)
			call_deferred("_deferred_inject_jump", from_data.timeline_path, to_data.get_timeline_name())
		elif from_port <= choices.size():
			var choice_text: String = choices[from_port - 1].get("text", "")
			from_data.set_choice_target(choice_text, String(to_node))
			call_deferred("_deferred_inject_choice_jump", from_data.timeline_path, choice_text, to_data.get_timeline_name())

func _deferred_inject_jump(from_path: String, to_name: String) -> void:
	FlowChartFileManager.inject_jump(from_path, to_name)
	_save_current_chart_silent()

func _deferred_inject_choice_jump(from_path: String, choice_text: String, to_name: String) -> void:
	FlowChartFileManager.inject_choice_jump(from_path, choice_text, to_name)
	_save_current_chart_silent()

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	var from_data: FlowChartNodeData = current_flow_chart.get_node_by_id(String(from_node))
	var to_data: FlowChartNodeData = current_flow_chart.get_node_by_id(String(to_node))

	if from_data != null and to_data != null:
		var choices: Array[Dictionary] = FlowChartFileManager.get_choices_from_dtl(from_data.timeline_path)
		if from_port == 0:
			if from_data.default_next_node_id == String(to_node):
				from_data.default_next_node_id = ""
			call_deferred("_deferred_remove_jump", from_data.timeline_path, to_data.get_timeline_name())
		elif from_port <= choices.size():
			var choice_text: String = choices[from_port - 1].get("text", "")
			from_data.set_choice_target(choice_text, "")
			call_deferred("_deferred_remove_choice_jump", from_data.timeline_path, choice_text, to_data.get_timeline_name())
	else:
		_save_current_chart_silent()

func _deferred_remove_jump(from_path: String, to_name: String) -> void:
	FlowChartFileManager.remove_jump(from_path, to_name)
	_save_current_chart_silent()

func _deferred_remove_choice_jump(from_path: String, choice_text: String, to_name: String) -> void:
	FlowChartFileManager.remove_choice_jump(from_path, choice_text, to_name)
	_save_current_chart_silent()

func _on_graph_popup_request(at_position: Vector2) -> void:
	if graph_edit == null or current_flow_chart == null:
		return
	var graph_pos: Vector2 = (at_position + graph_edit.scroll_offset) / graph_edit.zoom
	var conn: Dictionary = _find_connection_near_position(graph_pos)
	if not conn.is_empty():
		var from_node: StringName = conn.from_node
		var from_port: int = conn.from_port
		var to_node: StringName = conn.to_node
		var to_port: int = conn.to_port
		_on_disconnection_request(from_node, from_port, to_node, to_port)

func _find_connection_near_position(graph_pos: Vector2, threshold: float = 30.0) -> Dictionary:
	if graph_edit == null:
		return {}

	var connections: Array = graph_edit.get_connection_list()
	for conn: Dictionary in connections:
		var from_path: NodePath = NodePath(String(conn.from_node))
		var to_path: NodePath = NodePath(String(conn.to_node))
		var from_node: GraphNode = graph_edit.get_node_or_null(from_path) as GraphNode
		var to_node: GraphNode = graph_edit.get_node_or_null(to_path) as GraphNode
		if from_node == null or to_node == null:
			continue

		var p0: Vector2 = from_node.position_offset + from_node.get_output_port_position(conn.from_port)
		var p3: Vector2 = to_node.position_offset + to_node.get_input_port_position(conn.to_port)

		var cp_distance: float = abs(p3.x - p0.x) * 0.5
		var p1: Vector2 = p0 + Vector2(cp_distance, 0)
		var p2: Vector2 = p3 - Vector2(cp_distance, 0)

		var min_dist: float = 999999.0
		var samples: int = 24
		for i in range(samples + 1):
			var t: float = float(i) / float(samples)
			var pt: Vector2 = p0.cubic_interpolate(p3, p1, p2, t)
			var dist: float = graph_pos.distance_to(pt)
			if dist < min_dist:
				min_dist = dist

		if min_dist <= threshold:
			return conn

	return {}
