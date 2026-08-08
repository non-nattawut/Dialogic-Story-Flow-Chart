@tool
class_name FlowChartNodeData
extends Resource

@export var node_id: String = ""
@export var title: String = "Story Node"
@export var position: Vector2 = Vector2.ZERO

# Dialogic Scene Events
@export var background_path: String = ""
@export var background_fade: float = 1.0

@export var bgm_path: String = ""
@export var bgm_crossfade: float = 1.0

@export var character_path: String = ""
@export var character_portrait: String = ""
@export var character_position: String = "center" # "left", "center", "right"

@export_multiline var dialogue_text: String = ""

# Emote transitions mid-dialogue (array of { line_index: int, portrait: String })
@export var emote_transitions: Array[Dictionary] = []

# Choices: Array of { "text": String, "target_node_id": String }
@export var choices: Array[Dictionary] = []

# Next Node ID for linear progression without choices
@export var default_next_node_id: String = ""

# Condition / Branch Logic
@export var is_condition_node: bool = false
@export var condition_variable: String = ""
@export var condition_value: String = ""
@export var true_node_id: String = ""
@export var false_node_id: String = ""
