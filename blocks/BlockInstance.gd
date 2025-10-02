## Runtime data for a block placed in the workspace.
extends RefCounted
class_name BlockInstance

const BlockInstanceScript = preload("res://blocks/BlockInstance.gd")

## Globally unique identifier for referencing the instance inside a document.
var instance_id: String
## Definition key resolved through `BlockRegistry`.
var definition_id: StringName
## Map of input name -> literal value or nested expression tree.
var inputs: Dictionary
## Map of child slot -> ordered array of child instance IDs.
var children: Dictionary
## Mutable state persisted between ticks (schema defined on the definition).
var state: Dictionary

static var _rng := RandomNumberGenerator.new()
static var _rng_ready := false

## Convenience helper for generating a new instance id.
static func generate_id() -> String:
	return _generate_id()

## Creates a new instance using a definition and optional overrides.
static func create(definition, config: Dictionary = {}) -> BlockInstance:
	var instance = BlockInstanceScript.new()
	instance.instance_id = config.get("instance_id", _generate_id())
	instance.definition_id = definition.id
	instance.inputs = _init_inputs(definition, config.get("inputs", {}))
	instance.children = _init_children(definition, config.get("children", {}))
	instance.state = _init_state(definition, config.get("state", {}))
	return instance

## Internal id generator that combines timestamp and random seeds.
static func _generate_id() -> String:
	if not _rng_ready:
		_rng.randomize()
		_rng_ready = true
	var time_part = String.num_int64(Time.get_ticks_usec(), 16)
	var rand_part = String.num_uint64(_rng.randi(), 16)
	return "%s-%s" % [time_part, rand_part]

## Builds the inputs dictionary, merging provided values with defaults.
static func _init_inputs(definition, provided: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for input_def in definition.inputs:
		var key = input_def.name
		if provided.has(key):
			result[key] = provided[key]
		elif input_def.allows_expression and input_def.cardinality == &"multi":
			result[key] = []
		elif input_def.allows_expression:
			result[key] = null
		else:
			result[key] = input_def.default_value
	for extra_key in provided.keys():
		if not definition.has_input(extra_key):
			result[extra_key] = provided[extra_key]
	return result

## Builds the children dictionary keyed by slot name.
static func _init_children(definition, provided: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for slot_def in definition.child_slots:
		var key = slot_def.name
		if provided.has(key):
			result[key] = provided[key]
		else:
			result[key] = []
	for extra_key in provided.keys():
		if not definition.has_child_slot(extra_key):
			result[extra_key] = provided[extra_key]
	return result

## Builds the mutable runtime state seeded from the definition schema.
static func _init_state(definition, provided: Dictionary) -> Dictionary:
	var state = {}
	for key in definition.state_schema.keys():
		if provided.has(key):
			state[key] = provided[key]
		else:
			state[key] = definition.state_schema[key]
	for key in provided.keys():
		if not state.has(key):
			state[key] = provided[key]
	return state
