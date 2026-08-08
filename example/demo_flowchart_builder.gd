@tool
class_name DemoFlowChartBuilder
extends RefCounted

static func create_demo_chart() -> FlowChartData:
	var chart: FlowChartData = FlowChartData.new()

	# Node 1: Start
	var node1: FlowChartNodeData = FlowChartNodeData.new()
	node1.node_id = "node_start"
	node1.title = "1. Apartment Exterior"
	node1.position = Vector2(80, 180)
	node1.background_path = "res://assets/background/Apartment_Exterior.png"
	node1.bgm_path = "res://assets/bgm/dramatic_boi.ogg"
	node1.character_path = "res://example/characters/hiyori.dch"
	node1.character_portrait = "outing_normal"
	node1.character_position = "center"
	node1.dialogue_text = "What a nice morning outside the apartment.\nWhere should we head today?"
	node1.emote_transitions = [{ "line_index": 1, "portrait": "outing_blush" }]
	node1.default_next_node_id = "node_choice"
	chart.add_node(node1)

	# Node 2: Choice Node
	var node2: FlowChartNodeData = FlowChartNodeData.new()
	node2.node_id = "node_choice"
	node2.title = "2. Destination Decision"
	node2.position = Vector2(360, 180)
	node2.dialogue_text = "Choose your destination:"
	node2.choices = [
		{ "text": "Take the train to the seaside", "target_node_id": "node_train_day" },
		{ "text": "Visit the local hot spring onsen", "target_node_id": "node_onsen" }
	]
	chart.add_node(node2)

	# Node 3A: Train Day
	var node3a: FlowChartNodeData = FlowChartNodeData.new()
	node3a.node_id = "node_train_day"
	node3a.title = "3A. Seaside Train"
	node3a.position = Vector2(660, 80)
	node3a.background_path = "res://assets/background/Train_Day.png"
	node3a.bgm_path = "res://assets/bgm/hope.ogg"
	node3a.character_path = "res://example/characters/hiyori.dch"
	node3a.character_portrait = "schoolsummer_happy"
	node3a.character_position = "right"
	node3a.dialogue_text = "The seaside train is so refreshing!\nI love watching the coast line go by."
	node3a.emote_transitions = [{ "line_index": 1, "portrait": "schoolsummer_blush" }]
	node3a.default_next_node_id = "node_train_night"
	chart.add_node(node3a)

	# Node 4A: Train Night
	var node4a: FlowChartNodeData = FlowChartNodeData.new()
	node4a.node_id = "node_train_night"
	node4a.title = "4A. Night Train Return"
	node4a.position = Vector2(960, 80)
	node4a.background_path = "res://assets/background/Train_Night.png"
	node4a.bgm_path = "res://assets/bgm/frozen_winter.ogg"
	node4a.character_path = "res://example/characters/hiyori.dch"
	node4a.character_portrait = "schoolsummer_tears"
	node4a.character_position = "right"
	node4a.dialogue_text = "It got dark so quickly...\nThank you for spending today with me!"
	node4a.emote_transitions = [{ "line_index": 1, "portrait": "schoolsummer_smile" }]
	chart.add_node(node4a)

	# Node 3B: Onsen
	var node3b: FlowChartNodeData = FlowChartNodeData.new()
	node3b.node_id = "node_onsen"
	node3b.title = "3B. Onsen Springs"
	node3b.position = Vector2(660, 280)
	node3b.background_path = "res://assets/background/Onsen_Building.png"
	node3b.bgm_path = "res://assets/bgm/beanfeast.ogg"
	node3b.character_path = "res://example/characters/aria.dch"
	node3b.character_portrait = "Happy"
	node3b.character_position = "left"
	node3b.dialogue_text = "Welcome to the Onsen building!\nCareful, the water is very hot today."
	node3b.emote_transitions = [{ "line_index": 1, "portrait": "shy" }]
	node3b.default_next_node_id = "node_futon_night"
	chart.add_node(node3b)

	# Node 4B: Futon Night
	var node4b: FlowChartNodeData = FlowChartNodeData.new()
	node4b.node_id = "node_futon_night"
	node4b.title = "4B. Evening Futon Room"
	node4b.position = Vector2(960, 280)
	node4b.background_path = "res://assets/background/Futon_Room_Night.png"
	node4b.bgm_path = "res://assets/bgm/woo_scary.ogg"
	node4b.character_path = "res://example/characters/aria.dch"
	node4b.character_portrait = "Upset"
	node4b.character_position = "left"
	node4b.dialogue_text = "Did you hear that creaking noise outside?\nWait, it's just the wind!"
	node4b.emote_transitions = [{ "line_index": 1, "portrait": "Overjoyed" }]
	chart.add_node(node4b)

	chart.start_node_id = "node_start"
	return chart
