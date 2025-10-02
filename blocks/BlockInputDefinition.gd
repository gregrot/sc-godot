## Metadata for a single input socket declared on a block definition.
extends Resource
class_name BlockInputDefinition

## Canonical identifier for saving/loading instance values.
@export var name: StringName = &""
## Logical type expected from literals or expression trees.
@export var value_type: StringName = &"variant"
## Fallback literal used when the workspace has no supplied value.
@export var default_value: Variant
## True when the input can be satisfied by nesting another expression block.
@export var allows_expression: bool = true
## Optional allowed categories for nested expression blocks.
@export var allowed_expression_categories: PackedStringArray = PackedStringArray()
## `single` for a lone value, `multi` for list-style inputs.
@export var cardinality: StringName = &"single"
## Editor hint for Godot controls (slider, dropdown, colour_picker, etc.).
@export var editor: StringName = &""
## Declarative validator names processed by the editor/runtime.
@export var validators: PackedStringArray = PackedStringArray()
