## Authoritative description of a block available in the workspace palette.
extends Resource
class_name BlockDefinition

const BlockChildSlotDefinition = preload("res://blocks/BlockChildSlotDefinition.gd")
const BlockInputDefinition = preload("res://blocks/BlockInputDefinition.gd")

## Unique identifier, used as a lookup key in registries and serialized documents.
@export var id: StringName = &""
## Visible caption for palette buttons and workspace nodes.
@export var label: String = ""
## Category drives grouping, scheduling hints, and theming.
@export var category: StringName = &"action"
## Tooltip/inspector blurb presented to editors.
@export_multiline var summary: String = ""
## Optional grouping key for palette sections.
@export var palette_group: String = ""
## Additional search metadata for quick filtering.
@export var palette_tags: PackedStringArray = PackedStringArray()
## Child slot descriptors that declare flow containers for nested blocks.
@export var child_slots: Array[BlockChildSlotDefinition] = []
## Input descriptors that drive literals and expression nesting.
@export var inputs: Array[BlockInputDefinition] = []
## Runtime state seed copied into new block instances (e.g. counters, flags).
@export var state_schema: Dictionary = {}

## Returns true if a child slot named `slot_name` exists on this definition.
func has_child_slot(slot_name: StringName) -> bool:
	for slot in child_slots:
		if slot.name == slot_name:
			return true
	return false

## Fetches the child slot definition matching `slot_name`, or null when absent.
func get_child_slot(slot_name: StringName) -> BlockChildSlotDefinition:
	for slot in child_slots:
		if slot.name == slot_name:
			return slot
	return null

## Returns true if an input named `input_name` exists on this definition.
func has_input(input_name: StringName) -> bool:
	for input_def in inputs:
		if input_def.name == input_name:
			return true
	return false

## Fetches the input definition matching `input_name`, or null when absent.
func get_input(input_name: StringName) -> BlockInputDefinition:
	for input_def in inputs:
		if input_def.name == input_name:
			return input_def
	return null
