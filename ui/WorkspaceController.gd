## Glue node that connects the palette to the workspace view using a shared document.
extends Control
class_name WorkspaceController

const WorkspaceDocument = preload("res://blocks/WorkspaceDocument.gd")

## Optional document resource injected from the editor.
@export var document: Resource

@onready var palette = $BlockPalette
@onready var workspace_view = $WorkspaceView

## Initialises the document binding and subscribes to palette selections.
func _ready() -> void:
	if document == null:
		document = WorkspaceDocument.new()
	workspace_view.document = document
	palette.block_definition_selected.connect(Callable(self, "_on_block_definition_selected"))

## Handles palette clicks by spawning the chosen block into the workspace.
func _on_block_definition_selected(definition_id: StringName) -> void:
	var instance = workspace_view.add_block_from_definition(definition_id)
	if instance:
		print("Added block instance", instance.instance_id)
