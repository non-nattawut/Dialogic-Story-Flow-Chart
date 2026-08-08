@tool
class_name FlowChartNodeData
extends Resource

@export var node_id: String = ""
@export var title: String = "Timeline Node"
@export var position: Vector2 = Vector2.ZERO
@export var timeline_path: String = "" # e.g. "res://example/timelines/start.dtl"

# Parsed Choices: Array of { "text": String, "target_node_id": String }
@export var choices: Array[Dictionary] = []

# Default Next Timeline Node ID if no choices
@export var default_next_node_id: String = ""

func get_timeline_name() -> String:
	if not timeline_path.is_empty():
		return timeline_path.get_file().trim_suffix(".dtl")
	return node_id

func set_choice_target(choice_text: String, target_id: String) -> void:
	for choice in choices:
		if choice.get("text", "") == choice_text:
			choice["target_node_id"] = target_id
			return
	choices.append({ "text": choice_text, "target_node_id": target_id })

func get_choice_target(choice_text: String) -> String:
	for choice in choices:
		if choice.get("text", "") == choice_text:
			return choice.get("target_node_id", "")
	return ""
