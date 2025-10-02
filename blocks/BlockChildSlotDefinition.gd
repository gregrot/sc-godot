## Describes a container slot that can accept child blocks within a block definition.
extends Resource
class_name BlockChildSlotDefinition

## Unique key used to address this slot from instances (e.g. "do", "else").
@export var name: StringName = &""
## Visual guidance for how nested blocks are arranged inside the slot (stack, row, grid).
@export var layout: StringName = &"stack"
## Expected number/ordering of children; used to validate drops in the workspace.
@export var cardinality: StringName = &"sequence"
## Direction of the connection arrow when rendered, helps readability of flow.
@export var entry_direction: StringName = &"south"
## Optional whitelist of categories that may inhabit this slot.
@export var allowed_categories: PackedStringArray = PackedStringArray()
## Hint for the scheduler describing how children should execute (sequential, parallel, etc.).
@export var invocation_mode: StringName = &"sequential"
