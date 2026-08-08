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
var map_canvas_layer: CanvasLayer
var visited_node_ids: Array[String] = []
var current_active_node_id: String = ""

@export var is_map_visible: bool = true:
	set(value):
		is_map_visible = value
		if map_canvas_layer != null:
			map_canvas_layer.visible = value
		elif graph_edit != null:
			graph_edit.visible = value

func _ready() -> void:
	_setup_graph_ui()
	if flow_chart != null:
		rebuild_graph()

	_connect_dialogic_signals()

func _setup_graph_ui() -> void:
	for child in get_children():
		child.queue_free()

	map_canvas_layer = CanvasLayer.new()
	map_canvas_layer.name = "MapCanvasLayer"
	map_canvas_layer.layer = 15 # Render above Dialogic UI layer (layer 1-10)
	add_child(map_canvas_layer)

	graph_edit = GraphEdit.new()
	graph_edit.anchors_preset = Control.PRESET_FULL_RECT
	graph_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.right_disconnects = false
	map_canvas_layer.add_child(graph_edit)

func toggle_map_visibility() -> bool:
	is_map_visible = not is_map_visible
	return is_map_visible

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
	if is_inside_tree():
		rebuild_graph()

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
		var choices: Array[Dictionary] = FlowChartFileManager.get_choices_from_dtl(node_data.timeline_path)
		var gnode: GraphNode = GraphNode.new()
		gnode.name = node_data.node_id
		gnode.title = node_data.title
		gnode.position_offset = node_data.position
		if node_data.size != Vector2.ZERO:
			gnode.size = node_data.size
		gnode.draggable = true
		gnode.resizable = false
		gnode.custom_minimum_size = Vector2(240, 70)

		var v_box: VBoxContainer = VBoxContainer.new()
		var desc_label: Label = Label.new()
		desc_label.text = node_data.timeline_path.get_file() if not node_data.timeline_path.is_empty() else node_data.node_id
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v_box.add_child(desc_label)

		gnode.add_child(v_box)

		# Allow player to click on node
		gnode.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				node_clicked.emit(node_data.node_id)
		)

		graph_edit.add_child(gnode)
		gnode.set_slot(0, true, 0, Color.WHITE, true, 0, Color.GREEN)

		# Build choice slots
		for c_idx in range(choices.size()):
			var choice_info: Dictionary = choices[c_idx]
			var c_text: String = choice_info.get("text", "")
			var c_label: Label = Label.new()
			c_label.text = "- " + c_text
			c_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			c_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gnode.add_child(c_label)
			
			var slot_idx: int = c_idx + 1
			gnode.set_slot(slot_idx, false, 0, Color.WHITE, true, 0, Color(0.2, 0.7, 1.0, 1.0))

	# Connect edges
	for node_data: FlowChartNodeData in flow_chart.nodes:
		if not node_data.default_next_node_id.is_empty():
			if flow_chart.get_node_by_id(node_data.default_next_node_id) != null:
				graph_edit.connect_node(node_data.node_id, 0, node_data.default_next_node_id, 0)

		var choices: Array[Dictionary] = FlowChartFileManager.get_choices_from_dtl(node_data.timeline_path)
		for c_idx in range(choices.size()):
			var choice_info: Dictionary = choices[c_idx]
			var c_text: String = choice_info.get("text", "")
			var target_name: String = choice_info.get("target_timeline", "")
			var target_node_id: String = node_data.get_choice_target(c_text)

			if target_node_id.is_empty() and not target_name.is_empty():
				for target_node: FlowChartNodeData in flow_chart.nodes:
					if target_node.get_timeline_name() == target_name:
						target_node_id = target_node.node_id
						node_data.set_choice_target(c_text, target_node_id)
						break

			if not target_node_id.is_empty() and flow_chart.get_node_by_id(target_node_id) != null:
				graph_edit.connect_node(node_data.node_id, c_idx + 1, target_node_id, 0)

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
