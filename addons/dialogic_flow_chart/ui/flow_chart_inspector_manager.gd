@tool
class_name FlowChartInspectorManager
extends RefCounted

var inspector_panel: VBoxContainer
var title_field: LineEdit
var timeline_path_field: LineEdit
var default_next_field: LineEdit

var selected_node_data: FlowChartNodeData
var on_refresh_requested: Callable
var on_save_requested: Callable
var on_open_timeline: Callable

func setup(panel: VBoxContainer, refresh_cb: Callable, save_cb: Callable, open_timeline_cb: Callable) -> void:
	inspector_panel = panel
	on_refresh_requested = refresh_cb
	on_save_requested = save_cb
	on_open_timeline = open_timeline_cb
	_build_fields()

func _build_fields() -> void:
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
	title_field.text_changed.connect(func(new_title):
		if selected_node_data:
			selected_node_data.title = new_title
			if on_save_requested.is_valid():
				on_save_requested.call()
			if on_refresh_requested.is_valid():
				on_refresh_requested.call()
	)

	timeline_path_field = _add_field("Dialogic Timeline (.dtl) Path:")
	timeline_path_field.text_changed.connect(func(val):
		if selected_node_data:
			selected_node_data.timeline_path = val
			if on_save_requested.is_valid():
				on_save_requested.call()
			if on_refresh_requested.is_valid():
				on_refresh_requested.call()
	)

	default_next_field = _add_field("Default Next Timeline ID:")
	default_next_field.text_changed.connect(func(val):
		if selected_node_data:
			selected_node_data.default_next_node_id = val
			if on_save_requested.is_valid():
				on_save_requested.call()
	)

	var btn_open_dialogic: Button = Button.new()
	btn_open_dialogic.text = "Open Timeline in Dialogic Editor"
	btn_open_dialogic.pressed.connect(func():
		if selected_node_data and on_open_timeline.is_valid():
			on_open_timeline.call(selected_node_data.timeline_path)
	)
	inspector_panel.add_child(btn_open_dialogic)

func _add_field(title: String) -> LineEdit:
	var lbl: Label = Label.new()
	lbl.text = title
	inspector_panel.add_child(lbl)
	var line: LineEdit = LineEdit.new()
	inspector_panel.add_child(line)
	return line

func select_node(node_data: FlowChartNodeData) -> void:
	selected_node_data = node_data
	if selected_node_data != null:
		title_field.text = selected_node_data.title
		timeline_path_field.text = selected_node_data.timeline_path
		default_next_field.text = selected_node_data.default_next_node_id
