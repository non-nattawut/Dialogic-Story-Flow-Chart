class_name FlowChartRunner
extends Node

signal node_started(node_id: String)
signal node_completed(node_id: String)
signal flow_chart_ended()

@export var flow_chart: FlowChartData
@export var ui_graph: FlowChartGraphUI

var current_node: FlowChartNodeData

func start_flow_chart(chart: FlowChartData = null) -> void:
	if chart != null:
		flow_chart = chart

	if flow_chart == null or flow_chart.start_node_id.is_empty():
		push_error("FlowChartRunner: No valid FlowChartData or start_node_id set!")
		return

	execute_node(flow_chart.start_node_id)

func execute_node(node_id: String) -> void:
	if flow_chart == null:
		return

	current_node = flow_chart.get_node_by_id(node_id)
	if current_node == null:
		push_error("FlowChartRunner: Node ID not found: " + node_id)
		emit_signal("flow_chart_ended")
		return

	node_started.emit(node_id)
	if ui_graph != null:
		ui_graph.set_active_node(node_id)

	# Execute Condition Node
	if current_node.is_condition_node:
		var var_val: Variant = Dialogic.VAR.get_variable(current_node.condition_variable)
		var is_true: bool = str(var_val) == current_node.condition_value
		var next_id: String = current_node.true_node_id if is_true else current_node.false_node_id
		if not next_id.is_empty():
			execute_node(next_id)
		else:
			emit_signal("flow_chart_ended")
		return

	_play_node_sequence(current_node)

func _play_node_sequence(node_data: FlowChartNodeData) -> void:
	var dtl_text: String = ""

	# Background Event
	if not node_data.background_path.is_empty():
		dtl_text += '[background path="' + node_data.background_path + '" fade="' + str(node_data.background_fade) + '"]\n'

	# Music Event
	if not node_data.bgm_path.is_empty():
		dtl_text += '[music path="' + node_data.bgm_path + '" fade="' + str(node_data.bgm_crossfade) + '"]\n'

	# Character Join & Portrait Event
	var char_name: String = ""
	if not node_data.character_path.is_empty():
		var char_res: DialogicCharacter = load(node_data.character_path) as DialogicCharacter
		if char_res != null:
			char_name = char_res.get_character_name()
			dtl_text += 'join ' + char_name + ' ' + node_data.character_position + '\n'
			if not node_data.character_portrait.is_empty():
				dtl_text += '[portrait ' + node_data.character_portrait + ']\n'

	# Dialogue Text & Mid-dialogue Emote Changes
	if not node_data.dialogue_text.is_empty():
		var lines: PackedStringArray = node_data.dialogue_text.split("\n")
		for i: int in lines.size():
			var line: String = lines[i].strip_edges()
			if line.is_empty():
				continue

			for emote: Dictionary in node_data.emote_transitions:
				if emote.get("line_index", -1) == i:
					var new_portrait: String = emote.get("portrait", "")
					if not new_portrait.is_empty():
						dtl_text += '[portrait ' + new_portrait + ']\n'

			if not char_name.is_empty():
				dtl_text += char_name + ": " + line + "\n"
			else:
				dtl_text += line + "\n"

	# Choice Branches
	if node_data.choices.size() > 0:
		for idx: int in node_data.choices.size():
			var choice: Dictionary = node_data.choices[idx]
			var choice_text: String = choice.get("text", "Option " + str(idx + 1))
			dtl_text += "- " + choice_text + "\n"
			dtl_text += "\t[signal arg=\"choice_" + str(idx) + "\"]\n"

	if dtl_text.is_empty():
		_advance_next_node(node_data)
		return

	if Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.disconnect(_on_dialogic_signal)
	if Dialogic.timeline_ended.is_connected(_on_timeline_ended):
		Dialogic.timeline_ended.disconnect(_on_timeline_ended)

	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_on_timeline_ended)

	Dialogic.start_string(dtl_text)

func _on_dialogic_signal(argument: String) -> void:
	if argument.begins_with("choice_"):
		var idx: int = argument.trim_prefix("choice_").to_int()
		if current_node != null and idx < current_node.choices.size():
			var selected_choice: Dictionary = current_node.choices[idx]
			var target_id: String = selected_choice.get("target_node_id", "")
			if not target_id.is_empty():
				execute_node(target_id)
				return
	_advance_next_node(current_node)

func _on_timeline_ended() -> void:
	if current_node != null and current_node.choices.size() == 0:
		_advance_next_node(current_node)

func _advance_next_node(node_data: FlowChartNodeData) -> void:
	if node_data != null and not node_data.default_next_node_id.is_empty():
		execute_node(node_data.default_next_node_id)
	else:
		emit_signal("flow_chart_ended")
