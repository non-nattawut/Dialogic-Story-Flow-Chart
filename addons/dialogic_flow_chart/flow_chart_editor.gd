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
			_refresh_graph()
	)

	default_next_field = _add_field("Default Next Timeline ID:")
	default_next_field.text_changed.connect(func(val):
		if selected_node_data:
			selected_node_data.default_next_node_id = val
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

func _on_save_chart() -> void:
	if current_flow_chart == null:
		return
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
	if current_flow_chart == null:
		_do_new_chart()

	var new_id: String = "node_" + str(Time.get_ticks_msec())
	var node: FlowChartNodeData = FlowChartNodeData.new()
	node.node_id = new_id
	node.title = "New Timeline Box"
	node.position = Vector2(300, 140)
	current_flow_chart.add_node(node)
	_refresh_graph()

func _on_delete_nodes_request(node_names: Array) -> void:
	if current_flow_chart == null:
		return

	for node_name: Variant in node_names:
		var id_str: String = String(node_name)
		current_flow_chart.remove_node_by_id(id_str)
		if graph_edit.has_node(id_str):
			graph_edit.get_node(id_str).queue_free()

	_refresh_graph()

func _refresh_graph() -> void:
	if graph_edit == null or current_flow_chart == null:
		return

	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()

	for node_data: FlowChartNodeData in current_flow_chart.nodes:
		var gnode: GraphNode = GraphNode.new()
		gnode.name = node_data.node_id
		gnode.title = node_data.title
		gnode.position_offset = node_data.position
		
		# Compact node box dimensions
		gnode.custom_minimum_size = Vector2(180, 60)
		gnode.resizable = false

		var header_hbox: HBoxContainer = HBoxContainer.new()

		var path_lbl: Label = Label.new()
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

	# Restore Connections
	for node_data: FlowChartNodeData in current_flow_chart.nodes:
		if not node_data.default_next_node_id.is_empty():
			graph_edit.connect_node(node_data.node_id, 0, node_data.default_next_node_id, 0)
		for choice: Dictionary in node_data.choices:
			var target_id: String = choice.get("target_node_id", "")
			if not target_id.is_empty():
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

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	var from_data: FlowChartNodeData = current_flow_chart.get_node_by_id(String(from_node))
	if from_data != null and from_data.default_next_node_id == String(to_node):
		from_data.default_next_node_id = ""

func _inject_jump_to_timeline(source_dtl_path: String, target_timeline_name: String) -> void:
	if source_dtl_path.is_empty() or target_timeline_name.is_empty():
		return
	if not FileAccess.file_exists(source_dtl_path):
		return

	var file: FileAccess = FileAccess.open(source_dtl_path, FileAccess.READ)
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()

	if not "jump " + target_timeline_name in content:
		content = content.strip_edges() + "\njump " + target_timeline_name + "\n"
		var write_file: FileAccess = FileAccess.open(source_dtl_path, FileAccess.WRITE)
		if write_file != null:
			write_file.store_string(content)
			write_file.close()
