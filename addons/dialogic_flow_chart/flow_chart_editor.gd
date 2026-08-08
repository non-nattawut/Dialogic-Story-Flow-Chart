@tool
class_name FlowChartEditor
extends Control

var current_flow_chart: FlowChartData
var graph_edit: GraphEdit
var inspector_panel: VBoxContainer

var selected_node_data: FlowChartNodeData

# Form Fields
var title_field: LineEdit
var bg_field: LineEdit
var bgm_field: LineEdit
var char_field: LineEdit
var portrait_field: LineEdit
var dialogue_edit: TextEdit
var choices_container: VBoxContainer
var default_next_field: LineEdit

func _init() -> void:
	anchors_preset = Control.PRESET_FULL_RECT

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var h_split: HSplitContainer = HSplitContainer.new()
	h_split.anchors_preset = Control.PRESET_FULL_RECT
	add_child(h_split)

	# Left/Center: Toolbar + GraphEdit
	var main_box: VBoxContainer = VBoxContainer.new()
	h_split.add_child(main_box)
	main_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Toolbar
	var toolbar: HBoxContainer = HBoxContainer.new()
	main_box.add_child(toolbar)

	var btn_new: Button = Button.new()
	btn_new.text = "New Flow Chart"
	btn_new.pressed.connect(_on_new_chart)
	toolbar.add_child(btn_new)

	var btn_add_story: Button = Button.new()
	btn_add_story.text = "+ Add Story Node"
	btn_add_story.pressed.connect(_on_add_story_node)
	toolbar.add_child(btn_add_story)

	var btn_add_cond: Button = Button.new()
	btn_add_cond.text = "+ Add Condition Node"
	btn_add_cond.pressed.connect(_on_add_condition_node)
	toolbar.add_child(btn_add_cond)

	# Graph Canvas
	graph_edit = GraphEdit.new()
	graph_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_edit.right_disconnects = true
	graph_edit.node_selected.connect(_on_node_selected)
	graph_edit.connection_request.connect(_on_connection_request)
	graph_edit.disconnection_request.connect(_on_disconnection_request)
	main_box.add_child(graph_edit)

	# Right Inspector Panel
	var side_scroll: ScrollContainer = ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(320, 0)
	h_split.add_child(side_scroll)

	inspector_panel = VBoxContainer.new()
	inspector_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(inspector_panel)

	_build_inspector_fields()

func _build_inspector_fields() -> void:
	var label_heading: Label = Label.new()
	label_heading.text = "Node Inspector"
	label_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspector_panel.add_child(label_heading)

	inspector_panel.add_child(HSeparator.new())

	title_field = _add_field("Node Title:")
	title_field.text_changed.connect(_on_title_changed)

	bg_field = _add_field("Background Image Path:")
	bg_field.text_changed.connect(func(val): if selected_node_data: selected_node_data.background_path = val)

	bgm_field = _add_field("BGM Audio Path:")
	bgm_field.text_changed.connect(func(val): if selected_node_data: selected_node_data.bgm_path = val)

	char_field = _add_field("Character Path (.dch):")
	char_field.text_changed.connect(func(val): if selected_node_data: selected_node_data.character_path = val)

	portrait_field = _add_field("Character Emote/Portrait:")
	portrait_field.text_changed.connect(func(val): if selected_node_data: selected_node_data.character_portrait = val)

	default_next_field = _add_field("Default Next Node ID:")
	default_next_field.text_changed.connect(func(val): if selected_node_data: selected_node_data.default_next_node_id = val)

	var lbl_dialogue: Label = Label.new()
	lbl_dialogue.text = "Dialogue Text:"
	inspector_panel.add_child(lbl_dialogue)

	dialogue_edit = TextEdit.new()
	dialogue_edit.custom_minimum_size = Vector2(0, 100)
	dialogue_edit.text_changed.connect(func(): if selected_node_data: selected_node_data.dialogue_text = dialogue_edit.text)
	inspector_panel.add_child(dialogue_edit)

	inspector_panel.add_child(HSeparator.new())

	var lbl_choices: Label = Label.new()
	lbl_choices.text = "Choices & Branches:"
	inspector_panel.add_child(lbl_choices)

	choices_container = VBoxContainer.new()
	inspector_panel.add_child(choices_container)

	var btn_add_choice: Button = Button.new()
	btn_add_choice.text = "+ Add Choice Option"
	btn_add_choice.pressed.connect(_on_add_choice_option)
	inspector_panel.add_child(btn_add_choice)

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
	current_flow_chart.start_node_id = "start_node"
	var start_node: FlowChartNodeData = FlowChartNodeData.new()
	start_node.node_id = "start_node"
	start_node.title = "Start Scene"
	start_node.position = Vector2(100, 100)
	current_flow_chart.add_node(start_node)
	_refresh_graph()

func _on_add_story_node() -> void:
	if current_flow_chart == null:
		_on_new_chart()

	var new_id: String = "node_" + str(Time.get_ticks_msec())
	var node: FlowChartNodeData = FlowChartNodeData.new()
	node.node_id = new_id
	node.title = "Story Node"
	node.position = Vector2(300, 150)
	current_flow_chart.add_node(node)
	_refresh_graph()

func _on_add_condition_node() -> void:
	if current_flow_chart == null:
		_on_new_chart()

	var new_id: String = "cond_" + str(Time.get_ticks_msec())
	var node: FlowChartNodeData = FlowChartNodeData.new()
	node.node_id = new_id
	node.title = "Decision / If Check"
	node.is_condition_node = true
	node.position = Vector2(300, 150)
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
		gnode.size = Vector2(220, 140)

		var lbl: Label = Label.new()
		lbl.text = node_data.dialogue_text if not node_data.dialogue_text.is_empty() else "Condition Check"
		gnode.add_child(lbl)

		# Slot 0 input
		gnode.set_slot(0, true, 0, Color.WHITE, true, 0, Color.WHITE)

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
		bg_field.text = selected_node_data.background_path
		bgm_field.text = selected_node_data.bgm_path
		char_field.text = selected_node_data.character_path
		portrait_field.text = selected_node_data.character_portrait
		default_next_field.text = selected_node_data.default_next_node_id
		dialogue_edit.text = selected_node_data.dialogue_text
		_refresh_choices_ui()

func _on_title_changed(new_title: String) -> void:
	if selected_node_data != null:
		selected_node_data.title = new_title
		if graph_edit.has_node(selected_node_data.node_id):
			var gnode: GraphNode = graph_edit.get_node(selected_node_data.node_id) as GraphNode
			if gnode != null:
				gnode.title = new_title

func _on_add_choice_option() -> void:
	if selected_node_data == null:
		return
	selected_node_data.choices.append({ "text": "New Choice", "target_node_id": "" })
	_refresh_choices_ui()

func _refresh_choices_ui() -> void:
	for child in choices_container.get_children():
		child.queue_free()

	if selected_node_data == null:
		return

	for i: int in selected_node_data.choices.size():
		var choice: Dictionary = selected_node_data.choices[i]
		var hbox: HBoxContainer = HBoxContainer.new()

		var text_in: LineEdit = LineEdit.new()
		text_in.text = choice.get("text", "")
		text_in.text_changed.connect(func(val): choice["text"] = val)
		hbox.add_child(text_in)

		var target_in: LineEdit = LineEdit.new()
		target_in.placeholder_text = "Target Node ID"
		target_in.text = choice.get("target_node_id", "")
		target_in.text_changed.connect(func(val): choice["target_node_id"] = val)
		hbox.add_child(target_in)

		choices_container.add_child(hbox)

func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.connect_node(from_node, from_port, to_node, to_port)
	var from_data: FlowChartNodeData = current_flow_chart.get_node_by_id(String(from_node))
	if from_data != null:
		from_data.default_next_node_id = String(to_node)

func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	graph_edit.disconnect_node(from_node, from_port, to_node, to_port)
	var from_data: FlowChartNodeData = current_flow_chart.get_node_by_id(String(from_node))
	if from_data != null and from_data.default_next_node_id == String(to_node):
		from_data.default_next_node_id = ""
