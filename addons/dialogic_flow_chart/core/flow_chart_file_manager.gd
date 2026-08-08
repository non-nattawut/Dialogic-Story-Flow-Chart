@tool
class_name FlowChartFileManager
extends RefCounted

static func create_empty_dtl(dtl_path: String) -> void:
	if not FileAccess.file_exists(dtl_path):
		var file: FileAccess = FileAccess.open(dtl_path, FileAccess.WRITE)
		if file != null:
			file.store_string("")
			file.close()
			print("Created clean empty DTL timeline file: ", dtl_path)
			force_reload_resource(dtl_path)

static func force_reload_resource(path: String) -> void:
	if path.is_empty() or not FileAccess.file_exists(path):
		return

	if Engine.is_editor_hint():
		# 1. Update FileSystem scan safely without triggering asset importer error on text files
		var fs: EditorFileSystem = EditorInterface.get_resource_filesystem()
		if fs != null:
			if fs.has_method("update_file"):
				fs.update_file(path)
			fs.scan()

		# 2. Invalidate & Replace Godot's in-memory Resource cache
		var reloaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)

		# 3. If it's a DTL timeline, read raw disk text and force re-parse Dialogic timeline event objects
		if path.ends_with(".dtl"):
			var disk_text: String = FileAccess.get_file_as_string(path)
			if reloaded != null and reloaded.has_method("from_text"):
				reloaded.from_text(disk_text)
				if reloaded.has_method("process"):
					reloaded.process()

		# 4. Refresh Dialogic's internal metadata index
		DialogicResourceUtil.update_directory('.dtl')

		# 5. Notify Dialogic's active EditorsManager to clear & redraw visual event blocks
		if reloaded != null and path.ends_with(".dtl"):
			var main_screen: Node = EditorInterface.get_editor_main_screen()
			var dialogic_plugin: Node = main_screen.get_node_or_null("Dialogic")
			if dialogic_plugin != null:
				var editors_manager: Node = dialogic_plugin.find_child("EditorsManager", true, false)
				if editors_manager != null and editors_manager.has_method("clear_editor"):
					var editors_dict: Dictionary = editors_manager.get("editors") if "editors" in editors_manager else {}
					var timeline_editor: Node = editors_dict.get("Timeline", {}).get("node", null)
					if timeline_editor != null:
						editors_manager.clear_editor(timeline_editor, true)
						editors_manager.edit_resource(reloaded, true, true)
			EditorInterface.edit_resource(reloaded)

static func save_flowchart_silent(chart: FlowChartData, resource_path: String) -> void:
	if chart != null and not resource_path.is_empty():
		ResourceSaver.save(chart, resource_path)
		force_reload_resource(resource_path)

static func is_jump_to_target(line: String, target_timeline_name: String) -> bool:
	var target_clean: String = target_timeline_name.get_file().trim_suffix(".dtl").strip_edges()
	if target_clean.is_empty():
		return false
	var s: String = line.strip_edges()
	if not s.begins_with("jump "):
		return false
	var dest: String = s.trim_prefix("jump ").strip_edges()
	if dest.ends_with("/"):
		dest = dest.trim_suffix("/").strip_edges()
	elif "/" in dest and not dest.begins_with("res://"):
		dest = dest.split("/")[0].strip_edges()
	var dest_clean: String = dest.get_file().trim_suffix(".dtl").strip_edges()
	return dest_clean == target_clean

static func inject_jump(source_dtl_path: String, target_timeline_name: String) -> void:
	var target_clean: String = target_timeline_name.get_file().trim_suffix(".dtl").strip_edges()
	if source_dtl_path.is_empty() or target_clean.is_empty():
		return
	if not FileAccess.file_exists(source_dtl_path):
		return

	var file: FileAccess = FileAccess.open(source_dtl_path, FileAccess.READ)
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()

	var has_jump: bool = false
	for line: String in content.split("\n"):
		if is_jump_to_target(line, target_clean):
			has_jump = true
			break

	if not has_jump:
		content = content.strip_edges()
		if not content.is_empty():
			content += "\n"
		content += "jump " + target_clean + "/\n"

		var write_file: FileAccess = FileAccess.open(source_dtl_path, FileAccess.WRITE)
		if write_file != null:
			write_file.store_string(content)
			write_file.close()
			print("Injected jump into [", source_dtl_path, "]: jump ", target_clean, "/")
			force_reload_resource(source_dtl_path)

static func remove_jump(source_dtl_path: String, target_timeline_name: String) -> void:
	if source_dtl_path.is_empty() or target_timeline_name.is_empty():
		return
	if not FileAccess.file_exists(source_dtl_path):
		return

	var file: FileAccess = FileAccess.open(source_dtl_path, FileAccess.READ)
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()

	var lines: PackedStringArray = content.split("\n")
	var new_lines: Array = []
	var modified: bool = false

	for line: String in lines:
		if is_jump_to_target(line, target_timeline_name):
			modified = true
		else:
			new_lines.append(line)

	if modified:
		var new_content: String = "\n".join(new_lines)
		var write_file: FileAccess = FileAccess.open(source_dtl_path, FileAccess.WRITE)
		if write_file != null:
			write_file.store_string(new_content)
			write_file.close()
			print("Removed jump from [", source_dtl_path, "]: ", target_timeline_name)
			force_reload_resource(source_dtl_path)
