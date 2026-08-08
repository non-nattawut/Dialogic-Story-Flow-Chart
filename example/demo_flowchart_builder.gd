@tool
class_name DemoFlowChartBuilder
extends RefCounted

static func create_demo_chart() -> FlowChartData:
	var chart: FlowChartData = FlowChartData.new()

	# 1. Start Timeline Box
	var node1: FlowChartNodeData = FlowChartNodeData.new()
	node1.node_id = "node_start"
	node1.title = "1. Start Scene (start.dtl)"
	node1.position = Vector2(80, 180)
	node1.timeline_path = "res://example/timelines/start.dtl"
	node1.choices = [
		{ "text": "Take the train to the seaside", "target_node_id": "node_train_day" },
		{ "text": "Visit the local hot spring onsen", "target_node_id": "node_onsen" }
	]
	chart.add_node(node1)

	# 2A. Train Day Timeline Box
	var node2a: FlowChartNodeData = FlowChartNodeData.new()
	node2a.node_id = "node_train_day"
	node2a.title = "2A. Train Journey (train_day.dtl)"
	node2a.position = Vector2(460, 80)
	node2a.timeline_path = "res://example/timelines/train_day.dtl"
	node2a.default_next_node_id = "node_train_night"
	chart.add_node(node2a)

	# 3A. Train Night Timeline Box
	var node3a: FlowChartNodeData = FlowChartNodeData.new()
	node3a.node_id = "node_train_night"
	node3a.title = "3A. Night Return (train_night.dtl)"
	node3a.position = Vector2(820, 80)
	node3a.timeline_path = "res://example/timelines/train_night.dtl"
	chart.add_node(node3a)

	# 2B. Onsen Timeline Box
	var node2b: FlowChartNodeData = FlowChartNodeData.new()
	node2b.node_id = "node_onsen"
	node2b.title = "2B. Onsen Springs (onsen.dtl)"
	node2b.position = Vector2(460, 280)
	node2b.timeline_path = "res://example/timelines/onsen.dtl"
	node2b.default_next_node_id = "node_futon_night"
	chart.add_node(node2b)

	# 3B. Futon Night Timeline Box
	var node3b: FlowChartNodeData = FlowChartNodeData.new()
	node3b.node_id = "node_futon_night"
	node3b.title = "3B. Evening Futon (futon_night.dtl)"
	node3b.position = Vector2(820, 280)
	node3b.timeline_path = "res://example/timelines/futon_night.dtl"
	chart.add_node(node3b)

	chart.start_node_id = "node_start"
	return chart
