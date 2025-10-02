## Minimal list-based view that mirrors the contents of a WorkspaceDocument.
extends VBoxContainer
class_name WorkspaceView

const WorkspaceDocument = preload("res://blocks/WorkspaceDocument.gd")
const BaseBlockScene = preload("res://ui/blocks/BaseBlock.tscn")

var _document
## Document resource that backs the view; swapping will rebind signals.
@export var document: Resource:
	get:
		return _document
	set(value):
		_set_document(value)

var _list_container: VBoxContainer

## Lazily constructs the list container and binds to the current document.
func _ready() -> void:
	if _list_container == null:
		_list_container = VBoxContainer.new()
		_list_container.name = "BlockList"
		add_child(_list_container)
	if _document == null:
		_set_document(document if document != null else WorkspaceDocument.new())
	else:
		_bind_document()

## Handles swapping the bound document and refreshing signal connections.
func _set_document(value) -> void:
	if _document == value:
		return
	if _document != null:
		if _document.is_connected("block_added", Callable(self, "_on_block_added")):
			_document.disconnect("block_added", Callable(self, "_on_block_added"))
		if _document.is_connected("block_removed", Callable(self, "_on_block_removed")):
			_document.disconnect("block_removed", Callable(self, "_on_block_removed"))
		if _document.is_connected("blocks_refreshed", Callable(self, "_rebuild")):
			_document.disconnect("blocks_refreshed", Callable(self, "_rebuild"))
	_document = value
	if is_node_ready():
		_bind_document()

## Ensures the document emits change signals and triggers an initial rebuild.
func _bind_document() -> void:
	if _document == null:
		_document = WorkspaceDocument.new()
	if not _document.is_connected("block_added", Callable(self, "_on_block_added")):
		_document.connect("block_added", Callable(self, "_on_block_added"))
	if not _document.is_connected("block_removed", Callable(self, "_on_block_removed")):
		_document.connect("block_removed", Callable(self, "_on_block_removed"))
	if not _document.is_connected("blocks_refreshed", Callable(self, "_rebuild")):
		_document.connect("blocks_refreshed", Callable(self, "_rebuild"))
	_rebuild()

## Convenience helper used by the controller to drop new blocks into the document.
func add_block_from_definition(definition_id: StringName):
	if _document == null:
		_set_document(WorkspaceDocument.new())
	return _document.create_block(definition_id)

## Recreates the visible list from the document's root blocks.
func _rebuild() -> void:
	if _list_container == null or _document == null:
		return
	for child in _list_container.get_children():
		_list_container.remove_child(child)
		child.queue_free()
	for block_id in _document.root_blocks:
		var instance = _document.get_block(block_id)
		if instance:
			_add_instance_row(instance)

## Adds a single row containing the rendered block and a remove button.
func _add_instance_row(instance) -> void:
	var hbox = HBoxContainer.new()
	hbox.set_meta("instance_id", instance.instance_id)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var block_visual = BaseBlockScene.instantiate()
	block_visual.block_instance = instance
	block_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(block_visual)

	var remove_button = Button.new()
	remove_button.text = "Remove"
	remove_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	remove_button.pressed.connect(Callable(self, "_on_remove_pressed").bind(instance.instance_id))
	hbox.add_child(remove_button)

	_list_container.add_child(hbox)

## Removes the block matching `instance_id` from the underlying document.
func _on_remove_pressed(instance_id: String) -> void:
	if _document:
		_document.remove_block(instance_id)

## Responds to `block_added` by appending a row when the block is a root.
func _on_block_added(instance) -> void:
	if not _document.root_blocks.has(instance.instance_id):
		return
	_add_instance_row(instance)

## Removes the row that corresponds to the given instance id.
func _on_block_removed(instance_id: String) -> void:
	for child in _list_container.get_children():
		if child.get_meta("instance_id", "") == instance_id:
			_list_container.remove_child(child)
			child.queue_free()
			break
