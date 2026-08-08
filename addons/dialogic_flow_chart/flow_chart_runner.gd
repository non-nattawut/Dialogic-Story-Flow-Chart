class_name FlowChartRunner
extends Node

signal flow_chart_ended()

@export var flow_chart: FlowChartData
@export var ui_graph: FlowChartGraphUI

func start_flow_chart(chart: FlowChartData = null) -> void:
	if chart != null:
		flow_chart = chart

	if flow_chart == null or flow_chart.start_node_id.is_empty():
		push_error("FlowChartRunner: No valid FlowChartData or start_node_id set!")
		return

	var start_node: FlowChartNodeData = flow_chart.get_node_by_id(flow_chart.start_node_id)
	if start_node == null or start_node.timeline_path.is_empty():
		push_error("FlowChartRunner: Start node has no valid timeline_path!")
		return

	if ui_graph != null:
		ui_graph.set_active_node(start_node.node_id)

	# Execute starting timeline directly in Dialogic
	Dialogic.start(start_node.timeline_path)
