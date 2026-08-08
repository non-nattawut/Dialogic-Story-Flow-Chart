@tool
class_name FlowChartEditor
extends Control

var current_flow_chart: FlowChartData
var graph_edit: GraphEdit
var inspector_panel: VBoxContainer

var selected_node_data: FlowChartNodeData

# Form Fields
var title_field: LineEdit
var timeline_path_field: LineEdit
var default_next_field: LineEdit

func _init() -> void:
	anchors_preset = Control.PRESET_FULL_RECT

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var main_vbox: VBoxContainer = VBoxContainer.new()
	main_vbox.anchors_preset = Control.PRESET_FULL_RECT
	main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(main_vbox)

	# Toolbar
	var toolbar: HBoxContainer = HBoxContainer.new()
	toolbar.custom_minimum_size = Vector2(0, 36)
	main_vbox.add_child(toolbar)

	var btn_new: Button = Button.new()
	btn_new.text = "New Flow Chart"
	btn_new.pressed.connect(_on_new_chart)
	toolbar.add_child(btn_new)

	var btn_add_node: Button = Button.new()
	btn_add_node.text = "+ Add Timeline Box Node"
	btn_add_node.pressed.connect(_on_add_timeline_node)
	toolbar.add_child(btn_add_node)

	# HSplit for GraphEdit and Inspector
	var h_split: HSplitContainer = HSplitContainer.new()
	h_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h_split.split_offset = 680
	main_vbox.add_child(h_split)

	# Left: Graph Canvas
	graph_edit = GraphEdit.new()
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.right_disconnects = true
	graph_edit.node_selected.connect(_on_node_selected)
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	h_split.add_child(graph_edit)

	# Right: Inspector Scroll Panel
	var side_scroll: ScrollContainer = ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(320, 0)
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h_split.add_child(side_scroll)

	inspector_panel = VBoxContainer.new()
	inspector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(inspector_panel)

	_build_inspector_fields()

func _build_inspector_fields() -> void:
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
	btn_open_dialogic.text = "Open Timeline File"
	btn_open_dialogic.pressed.connect(_on_open_timeline_file)
	inspector_panel.add_child(btn_open_dialogic)

func _add_field(title: String) -> LineEdit:
	var lbl: Label = Label.new()
	lbl.text = title
	inspector_panel.add_child(lbl)
	var line: LineEdit = LineEdit.new()
	inspector_panel.add_child(line)
	return line

func load_flow_chart(chart: FlowChartData) -> void:
	current_flow_chart = chart
	_refresh_graph()

func _on_new_chart() -> void:
	current_flow_chart = FlowChartData.new()
	current_flow_chart.start_node_id = "start"

	var start_node: FlowChartNodeData = FlowChartNodeData.new()
	start_node.node_id = "start"
	start_node.title = "Start Timeline"
	start_node.timeline_path = "res://example/timelines/start.dtl"
	start_node.position = Vector2(80, 180)
	current_flow_chart.add_node(start_node)

	_refresh_graph()

func _on_add_timeline_node() -> void:
	if current_flow_chart == null:
		_on_new_chart()

	var new_id: String = "node_" + str(Time.get_ticks_msec())
	var node: FlowChartNodeData = FlowChartNodeData.new()
	node.node_id = new_id
	node.title = "New Timeline Box"
	node.position = Vector2(300, 180)
	current_flow_chart.add_node(node)
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
		gnode.size = Vector2(240, 140)
		gnode.resizable = true

		var vbox: VBoxContainer = VBoxContainer.new()
		var path_lbl: Label = Label.new()
		path_lbl.text = node_data.timeline_path if not node_data.timeline_path.is_empty() else "(No DTL File Linked)"
		path_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(path_lbl)
		gnode.add_child(vbox)

		# Slot 0: Input & Default Output
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
		var res: Resource = load(selected_node_data.timeline_path)
		if res != null and Engine.is_editor_hint():
			EditorInterface.edit_resource(res)

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
