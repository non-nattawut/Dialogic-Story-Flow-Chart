@tool
class_name FlowChartData
extends Resource

@export var start_node_id: String = ""
@export var nodes: Array[FlowChartNodeData] = []

func get_node_by_id(id: String) -> FlowChartNodeData:
	for node: FlowChartNodeData in nodes:
		if node.node_id == id:
			return node
	return null

func add_node(node: FlowChartNodeData) -> void:
	if not nodes.has(node):
		nodes.append(node)

func remove_node_by_id(id: String) -> void:
	var target: FlowChartNodeData = get_node_by_id(id)
	if target != null:
		nodes.erase(target)
