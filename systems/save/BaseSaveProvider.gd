## BaseSaveProvider.gd
## Abstract base class for all save/load backends.
##
## Implement this class to add a new storage backend.
## SaveSystem holds one active provider and delegates all persistence to it.
##
## v1 → LocalSaveProvider  (FileAccess + JSON, ships in release)
## TODO v2 → SupabaseSaveProvider  (REST API, behind FEATURE_CLOUD_SAVE flag)
##           Swap the provider in SaveSystem._ready() — no other code changes needed.
class_name BaseSaveProvider
extends RefCounted

## Persists a save-data dictionary to storage.
## Returns true on success, false on any error.
func save(data: Dictionary) -> bool:
	push_error("BaseSaveProvider: save() is not implemented.")
	return false

## Loads and returns the save-data dictionary from storage.
## Returns an empty Dictionary {} if no save exists or on any error.
func load_data() -> Dictionary:
	push_error("BaseSaveProvider: load_data() is not implemented.")
	return {}

## Returns true if a save record exists in storage.
func has_save() -> bool:
	push_error("BaseSaveProvider: has_save() is not implemented.")
	return false

## Permanently deletes the save. Used for "new game" and debug resets.
## Returns true on success.
func delete_save() -> bool:
	push_error("BaseSaveProvider: delete_save() is not implemented.")
	return false
