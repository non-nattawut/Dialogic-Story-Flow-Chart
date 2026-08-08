extends Control

@export var flow_chart: FlowChartData = preload("res://example/demo_flowchart.tres")

@onready var graph_ui: FlowChartGraphUI = $FlowChartGraphUI
@onready var runner: FlowChartRunner = $FlowChartRunner
@onready var toggle_btn: Button = $CanvasLayer/ToggleMapButton

func _ready() -> void:
	if flow_chart == null:
		flow_chart = preload("res://example/demo_flowchart.tres")

	graph_ui.load_flowchart(flow_chart)
	runner.flow_chart = flow_chart
	runner.ui_graph = graph_ui

	toggle_btn.pressed.connect(_on_toggle_map)

	# Start execution after ready
	call_deferred("_start_demo")

func _start_demo() -> void:
	runner.start_flow_chart()

func _on_toggle_map() -> void:
	graph_ui.visible = not graph_ui.visible
	toggle_btn.text = "Hide Flowchart Map" if graph_ui.visible else "Show Flowchart Map"
