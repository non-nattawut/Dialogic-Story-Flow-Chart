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

func _setup_graph_ui() -> void:
	for child in get_children():
		child.queue_free()

	graph_edit = GraphEdit.new()
	graph_edit.anchors_preset = Control.PRESET_FULL_RECT
	graph_edit.right_disconnects = true
	graph_edit.scroll_offset = Vector2.ZERO
	add_child(graph_edit)

func load_flowchart(chart: FlowChartData) -> void:
	flow_chart = chart

func set_active_node(node_id: String) -> void:
	current_active_node_id = node_id
	if not visited_node_ids.has(node_id):
		visited_node_ids.append(node_id)
	update_node_visuals()

func mark_visited(node_id: String) -> void:
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
		desc_label.text = _format_node_summary(node_data)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v_box.add_child(desc_label)

		gnode.add_child(v_box)
		
		# Slot 0 for input
		gnode.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)

		graph_edit.add_child(gnode)

	# Connect edges
	for node_data: FlowChartNodeData in flow_chart.nodes:
		if node_data.is_condition_node:
			if not node_data.true_node_id.is_empty():
				graph_edit.connect_node(node_data.node_id, 0, node_data.true_node_id, 0)
			if not node_data.false_node_id.is_empty():
				graph_edit.connect_node(node_data.node_id, 0, node_data.false_node_id, 0)
		else:
			if not node_data.default_next_node_id.is_empty():
				graph_edit.connect_node(node_data.node_id, 0, node_data.default_next_node_id, 0)
			for choice: Dictionary in node_data.choices:
				var target_id: String = choice.get("target_node_id", "")
				if not target_id.is_empty():
					graph_edit.connect_node(node_data.node_id, 0, target_id, 0)

	update_node_visuals()

func _format_node_summary(node_data: FlowChartNodeData) -> String:
	var summary: String = ""
	if not node_data.dialogue_text.is_empty():
		var lines: PackedStringArray = node_data.dialogue_text.split("\n")
		summary += lines[0]
		if lines.size() > 1:
			summary += "..."
	elif node_data.is_condition_node:
		summary += "If " + node_data.condition_variable + " == " + node_data.condition_value
	return summary

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
