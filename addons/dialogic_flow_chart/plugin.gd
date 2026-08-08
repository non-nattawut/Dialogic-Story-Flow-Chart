@tool
extends EditorPlugin

var editor_instance: FlowChartEditor

func _enter_tree() -> void:
	var scene: PackedScene = load("res://addons/dialogic_flow_chart/flow_chart_editor.tscn")
	if scene != null:
		editor_instance = scene.instantiate()
		editor_instance.name = "Story Flow Chart"
		get_editor_interface().get_editor_main_screen().add_child(editor_instance)
		_make_visible(false)

func _exit_tree() -> void:
	if editor_instance != null:
		editor_instance.queue_free()

func _has_main_screen() -> bool:
	return true

func _make_visible(visible: bool) -> void:
	if editor_instance != null:
		editor_instance.visible = visible

func _get_plugin_name() -> String:
	return "Story Flow Chart"

func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")
