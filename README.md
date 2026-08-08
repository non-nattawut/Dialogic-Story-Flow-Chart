# Dialogic Story Flow Chart

A visual node-based story flowchart editor and runtime framework for **Godot Engine 4.7+**, seamlessly integrated with the **Dialogic 2** dialogue framework.

---

## 🌟 Key Features

- **1 Box = 1 `.dtl` Timeline Architecture**: Every node box in the flowchart represents a discrete Dialogic `.dtl` timeline file.
- **Dynamic Choice Ports**: Choice blocks (`- Choice Text`) inside a `.dtl` file are automatically parsed into dedicated **Cyan Choice Ports** on the node box. Linking a choice port directly injects `jump target/` beneath that choice option in the `.dtl` file without needing to open Dialogic!
- **Automatic Jump Injection & Removal**: Connecting Node A to Node B automatically appends `jump timeline_b/` (with trailing slash) to Node A's `.dtl` file. Unlinking or deleting nodes strips the corresponding `jump` line cleanly.
- **Right-Click Connection Disconnection**: Right-click directly on any link line in the flowchart to remove connections instantly.
- **Drag & Drop Support**: Drag any `.dtl` timeline file directly from Godot's FileSystem dock onto the flowchart canvas to create and bind a node box instantly.
- **Double-Click Redirection**: Double-clicking any flowchart box immediately switches the main editor screen to Dialogic's Timeline Editor for fast dialogue editing.
- **Clean Empty Timelines**: Creating a new timeline node generates a 100% clean, empty `.dtl` file without default characters or background placeholders.
- **Live Cache Reloading**: Changes to `.dtl` files and `.tres` flowchart resources reload live across open editor tabs using `ResourceLoader.CACHE_MODE_REPLACE` without requiring Godot project restarts.
- **Runtime Execution**: Run flowcharts directly in-game using `FlowChartRunner` or render interactive overlay maps with `FlowChartGraphUI`.

---

## 📦 Installation

1. Copy the `addons/dialogic_flow_chart` directory into your Godot project's `addons/` folder:
   ```
   res://addons/dialogic_flow_chart/
   ```
2. Ensure **Dialogic 2** is installed in your project under `res://addons/dialogic/`.
3. Open Godot Engine and navigate to:
   `Project -> Project Settings -> Plugins`
4. Enable the **Story Flow Chart** plugin checkbox.

---

## 🚀 Quick Start Guide

### 1. Creating & Editing Flowcharts
1. Click the **Story Flow Chart** tab on the top main screen editor bar.
2. Click **New Flow Chart** or **Open File...** to load a `.tres` flowchart data resource (e.g. `res://example/demo_flowchart.tres`).
3. Click **+ Add Timeline Box Node** (or drag a `.dtl` file from FileSystem) to create a new timeline box.
4. Drag from the output port (green) of a node to the input port (white) of another node to establish a narrative connection.
5. Double-click any node box to edit its dialogue events directly in Dialogic.

### 2. Running a Flowchart In-Game
Attach `FlowChartRunner` and `FlowChartGraphUI` to your game scene:

```gdscript
extends Node

@onready var runner: FlowChartRunner = $FlowChartRunner
@onready var graph_ui: FlowChartGraphUI = $FlowChartGraphUI

func _ready() -> void:
    var chart: FlowChartData = load("res://example/demo_flowchart.tres")
    if graph_ui != null:
        graph_ui.load_flowchart(chart)
    if runner != null:
        runner.start_flow_chart(chart)
```

---

## 📂 Project Architecture

```
addons/dialogic_flow_chart/
├── core/                               # Data Models & File Managers
│   ├── flow_chart_file_manager.gd      # Handles .dtl I/O, jump injection & cache reload
│   ├── flow_chart_node_data.gd         # Flowchart node data model
│   ├── flow_chart_resource.gd          # Flowchart resource container model
│   └── flow_chart_runner.gd            # In-game flowchart execution controller
├── ui/                                 # Editor Controllers, Views & Inspectors
│   ├── flow_chart_editor.gd            # Main addon editor controller
│   ├── flow_chart_editor.tscn          # Main addon editor UI scene
│   ├── flow_chart_graph_edit.gd        # GraphEdit canvas & drag-and-drop handler
│   ├── flow_chart_graph_ui.gd          # In-game flowchart UI renderer
│   └── flow_chart_inspector_manager.gd  # Node inspector manager
├── plugin.cfg                          # Addon metadata
└── plugin.gd                           # Main plugin entry point
```

---

## 🤝 Maintenance & Synchronization Rules

AI Agents and developers working on this project MUST follow the repository synchronization rules defined in [AGENTS.md](file:///f:/Work/Programming/Godot/Projects/dialogic-story-flow-chart/AGENTS.md):
- Keep `README.md` updated whenever new features, APIs, or architectural changes are introduced.
- Follow Senior Game Developer OOP standards (concise scripts ≤ 250–300 lines, modular subdirectories).
- Verify all changes with `Godot 4.7+` headless checks (`--check-only`).