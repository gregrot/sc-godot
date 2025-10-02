## Autoload singleton that discovers and exposes block definition resources.
extends Node

const DEFINITIONS_PATH = "res://blocks/definitions"

const BlockDefinition = preload("res://blocks/BlockDefinition.gd")

## Emitted whenever the registry reloads its known definitions.
signal definitions_refreshed

var _definitions: Dictionary = {}

## Loads block definition resources from the expected directory.
func _ready() -> void:
	load_definitions()

## Clears and repopulates the registry from disk.
func load_definitions() -> void:
	_definitions.clear()
	var dir = DirAccess.open(DEFINITIONS_PATH)
	if dir == null:
		push_warning("BlockRegistry: definitions directory %s not found." % DEFINITIONS_PATH)
		return

	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			entry = dir.get_next()
			continue
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		if not _is_resource_path(entry):
			entry = dir.get_next()
			continue

		var resource_path = "%s/%s" % [DEFINITIONS_PATH, entry]
		var definition = ResourceLoader.load(resource_path)
		if definition == null:
			push_warning("BlockRegistry: unable to load block definition at %s" % resource_path)
		elif not (definition is BlockDefinition):
			push_warning("BlockRegistry: resource %s is not a BlockDefinition" % resource_path)
		else:
			_register_definition(definition)
		entry = dir.get_next()
	dir.list_dir_end()

	definitions_refreshed.emit()

## Returns the definition resource registered under `definition_id`.
func get_definition(definition_id: StringName):
	return _definitions.get(definition_id, null)

## Returns a duplicate dictionary of all registered definitions.
func get_definitions() -> Dictionary:
	return _definitions.duplicate()

## True when a definition with the provided id exists.
func has_definition(definition_id: StringName) -> bool:
	return _definitions.has(definition_id)

## Clears all registered definitions. Intended for tooling/tests.
func clear_definitions() -> void:
	if _definitions.is_empty():
		return
	_definitions.clear()
	definitions_refreshed.emit()

## Registers a definition resource at runtime and emits a refresh when successful.
func register_definition(definition) -> bool:
	var had_key = definition != null and _definitions.has(definition.id)
	_register_definition(definition)
	var success = definition != null and _definitions.has(definition.id)
	if success and not had_key:
		definitions_refreshed.emit()
	return success

## Internal helper that inserts a validated definition into the dictionary.
func _register_definition(definition) -> void:
	if definition.id == StringName():
		push_warning("BlockRegistry: skipping block definition without id (%s)" % [definition])
		return

	var key = definition.id
	if _definitions.has(key):
		push_error("BlockRegistry: duplicate block id '%s'" % key)
		return

	_definitions[key] = definition

## Returns true if `filename` resembles a resource file we should attempt to load.
func _is_resource_path(filename: String) -> bool:
	return filename.ends_with(".tres") or filename.ends_with(".res")
