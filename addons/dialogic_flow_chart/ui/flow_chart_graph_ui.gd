class_name FlowChartGraphUI
extends Control

signal node_clicked(node_id: String)

@export var flow_chart: FlowChartData:
	set(value):
		flow_chart = value
		if is_inside_tree():
			rebuild_graph()

@export var active_node_color: Color = Color(0.2, 0.8, 0.4, 1.0)
@export var visited_node_color: Color = Color(0.3, 0.6, 0.9, 1.0)
@export var locked_node_color: Color = Color(0.4, 0.4, 0.4, 0.8)

var graph_edit: GraphEdit
var visited_node_ids: Array[String] = []
var current_active_node_id: String = ""

func _ready() -> void:
	_setup_graph_ui()
	if flow_chart != null:
		rebuild_graph()

	_connect_dialogic_signals()

func _setup_graph_ui() -> void:
	for child in get_children():
		child.queue_free()

	graph_edit = GraphEdit.new()
	graph_edit.anchors_preset = Control.PRESET_FULL_RECT
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.right_disconnects = true
	add_child(graph_edit)

func _connect_dialogic_signals() -> void:
	if Engine.has_singleton("Dialogic") or get_node_or_null("/root/Dialogic") != null:
		var dialogic_node = get_node_or_null("/root/Dialogic")
		if dialogic_node != null and dialogic_node.has_signal("timeline_started"):
			dialogic_node.timeline_started.connect(_on_dialogic_timeline_started)

func _on_dialogic_timeline_started() -> void:
	var dialogic_node = get_node_or_null("/root/Dialogic")
	if dialogic_node != null and dialogic_node.get("current_timeline") != null:
		var timeline_res = dialogic_node.current_timeline
		var timeline_name: String = ""
		if timeline_res != null and timeline_res.has_method("get_identifier"):
			timeline_name = timeline_res.get_identifier()
		elif timeline_res != null and "resource_path" in timeline_res:
			timeline_name = timeline_res.resource_path.get_file().trim_suffix(".dtl")

		if not timeline_name.is_empty():
			set_active_timeline_node(timeline_name)

func load_flowchart(chart: FlowChartData) -> void:
	flow_chart = chart

func set_active_timeline_node(timeline_name: String) -> void:
	if flow_chart == null:
		return

	for node_data: FlowChartNodeData in flow_chart.nodes:
		if node_data.get_timeline_name() == timeline_name or node_data.node_id == timeline_name:
			current_active_node_id = node_data.node_id
			if not visited_node_ids.has(node_data.node_id):
				visited_node_ids.append(node_data.node_id)
			update_node_visuals()
			return

func set_active_node(node_id: String) -> void:
	current_active_node_id = node_id
	if not visited_node_ids.has(node_id):
		visited_node_ids.append(node_id)
	update_node_visuals()

func rebuild_graph() -> void:
	if graph_edit == null or flow_chart == null:
		return

	graph_edit.clear_connections()
	for child in graph_edit.get_children():
		if child is GraphNode:
			child.queue_free()

	for node_data: FlowChartNodeData in flow_chart.nodes:
		var gnode: GraphNode = GraphNode.new()
		gnode.name = node_data.node_id
		gnode.title = node_data.title
		gnode.position_offset = node_data.position
		gnode.draggable = true
		gnode.resizable = false
		gnode.size = Vector2(240, 140)

		var v_box: VBoxContainer = VBoxContainer.new()
		var desc_label: Label = Label.new()
		desc_label.text = node_data.timeline_path.get_file() if not node_data.timeline_path.is_empty() else node_data.node_id
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v_box.add_child(desc_label)

		gnode.add_child(v_box)
		graph_edit.add_child(gnode)
		gnode.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)

	# Connect edges
	for node_data: FlowChartNodeData in flow_chart.nodes:
		if not node_data.default_next_node_id.is_empty():
			graph_edit.connect_node(node_data.node_id, 0, node_data.default_next_node_id, 0)
		for choice: Dictionary in node_data.choices:
			var target_id: String = choice.get("target_node_id", "")
			if not target_id.is_empty():
				graph_edit.connect_node(node_data.node_id, 0, target_id, 0)

	update_node_visuals()

func update_node_visuals() -> void:
	if graph_edit == null:
		return

	for child in graph_edit.get_children():
		if child is GraphNode:
			var node_id: String = child.name
			if node_id == current_active_node_id:
				child.modulate = active_node_color
			elif visited_node_ids.has(node_id):
				child.modulate = visited_node_color
			else:
				child.modulate = locked_node_color
