## LocalSaveProvider.gd
## File-system save provider — FileAccess + JSON.
##
## Writes to GameConfig.SAVE_FILE_PATH ("user://save_data.json").
## "user://" resolves to a platform-appropriate writable location:
##   iOS     → <app>/Documents/
##   Android → internal app storage (no SD card permission needed)
##
## Data is stored as pretty-printed UTF-8 JSON for easy debugging.
## TODO v2: consider store_buffer with a key for anti-cheat on competitive features.
class_name LocalSaveProvider
extends BaseSaveProvider


func save(data: Dictionary) -> bool:
	var file := FileAccess.open(GameConfig.SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("LocalSaveProvider: cannot open file for writing — error %s"
				% FileAccess.get_open_error())
		return false

	file.store_string(JSON.stringify(data, "\t"))  # "\t" = pretty-print
	file.close()
	return true


func load_data() -> Dictionary:
	if not has_save():
		return {}

	var file := FileAccess.open(GameConfig.SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("LocalSaveProvider: cannot open file for reading — error %s"
				% FileAccess.get_open_error())
		return {}

	var content := file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(content) != OK:
		push_error("LocalSaveProvider: JSON parse error at line %d — %s"
				% [json.get_error_line(), json.get_error_message()])
		return {}

	if not json.data is Dictionary:
		push_error("LocalSaveProvider: save file root is not a Dictionary.")
		return {}

	return json.data


func has_save() -> bool:
	return FileAccess.file_exists(GameConfig.SAVE_FILE_PATH)


func delete_save() -> bool:
	if not has_save():
		return true  # Nothing to delete — treat as success

	var abs_path := ProjectSettings.globalize_path(GameConfig.SAVE_FILE_PATH)
	var err := DirAccess.remove_absolute(abs_path)
	if err != OK:
		push_error("LocalSaveProvider: failed to delete save — error %s" % err)
		return false
	return true
