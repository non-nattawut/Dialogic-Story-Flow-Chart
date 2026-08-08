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
