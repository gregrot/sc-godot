## Serialisable representation of a workspace, including block instances and hierarchy.
extends Resource
class_name WorkspaceDocument

const BlockInstance = preload("res://blocks/BlockInstance.gd")

## Friendly title, useful when presenting multiple workspaces.
@export var name: String = "Untitled Workspace"
## Ordered list of root-level block instance IDs.
@export var root_blocks: Array[String] = []

var _instances: Dictionary = {}

## Emitted when a block is inserted into the document.
signal block_added(instance)
## Emitted after a block is removed from the document.
signal block_removed(instance_id: String)
## Emitted when an existing block is mutated.
signal block_updated(instance)
## Emitted when the document contents are wholesale rebuilt (e.g. clear/deserialize).
signal blocks_refreshed

## Resets the document to an empty state.
func clear() -> void:
    _instances.clear()
    root_blocks.clear()
    blocks_refreshed.emit()

## Creates a block from a definition id and inserts it into the document.
func create_block(definition_id: StringName, config: Dictionary = {}):
    var definition = BlockRegistry.get_definition(definition_id)
    if definition == null:
        push_error("WorkspaceDocument: Unknown block definition '%s'" % definition_id)
        return null

    var instance = BlockInstance.create(definition, config)
    add_block(instance)
    return instance

## Inserts an existing instance, optionally marking it as a root block.
func add_block(instance, add_to_root: bool = true) -> void:
    if instance == null:
        return
    if instance.instance_id == "":
        instance.instance_id = BlockInstance.generate_id()
    _instances[instance.instance_id] = instance
    if add_to_root and not root_blocks.has(instance.instance_id):
        root_blocks.append(instance.instance_id)
    block_added.emit(instance)

## Removes the instance and emits the relevant signal.
func remove_block(instance_id: String, remove_from_root: bool = true) -> void:
    if not _instances.has(instance_id):
        return
    _instances.erase(instance_id)
    if remove_from_root:
        root_blocks.erase(instance_id)
    block_removed.emit(instance_id)

## Replaces the stored instance with the provided version.
func update_block(instance) -> void:
    if instance == null or not _instances.has(instance.instance_id):
        return
    _instances[instance.instance_id] = instance
    block_updated.emit(instance)

## Returns the instance matching `instance_id`, or null when unknown.
func get_block(instance_id: String):
    return _instances.get(instance_id, null)

## Returns the dictionary storing all block instances.
func get_blocks() -> Dictionary:
    return _instances

## Ensures a block id is present in the `root_blocks` list.
func ensure_root(instance_id: String) -> void:
    if _instances.has(instance_id) and not root_blocks.has(instance_id):
        root_blocks.append(instance_id)

## Serialises document state to a dictionary that can be stored or exported.
func serialize() -> Dictionary:
    var serialized_blocks = {}
    for key in _instances.keys():
        var inst = _instances[key]
        serialized_blocks[key] = {
            "definition_id": inst.definition_id,
            "inputs": inst.inputs,
            "children": inst.children,
            "state": inst.state
        }
    return {
        "name": name,
        "root_blocks": root_blocks.duplicate(),
        "blocks": serialized_blocks,
    }

## Populates the document from a dictionary produced by `serialize()`.
func deserialize(data: Dictionary) -> void:
    _instances.clear()
    name = data.get("name", name)
    root_blocks = []
    var block_data: Dictionary = data.get("blocks", {})
    for block_id in block_data.keys():
        var entry: Dictionary = block_data[block_id]
        var definition_id: StringName = entry.get("definition_id", StringName())
        var definition = BlockRegistry.get_definition(definition_id)
        if definition == null:
            push_warning("WorkspaceDocument: Skipping block '%s' with unknown definition '%s'" % [block_id, definition_id])
            continue
        var instance = BlockInstance.create(definition, {
            "instance_id": block_id,
            "inputs": entry.get("inputs", {}),
            "children": entry.get("children", {}),
            "state": entry.get("state", {}),
        })
        _instances[instance.instance_id] = instance
    for block_id in data.get("root_blocks", []):
        if _instances.has(block_id):
            root_blocks.append(block_id)
    blocks_refreshed.emit()
