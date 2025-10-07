@tool
extends Entity
class_name MovementModule

const CModuleMount := preload("res://robot/components/c_module_mount.gd")
const CMoveCapability := preload("res://robot/components/c_move_capability.gd")
const CScriptFunctionExport := preload("res://robot/components/c_script_function_export.gd")
const CScriptPropertyExport := preload("res://robot/components/c_script_property_export.gd")

@export var speed: float = 4.0

func define_components() -> Array:
	var mount := CModuleMount.new("movement")
	var capability := CMoveCapability.new()
	capability.speed = speed
	var function_export := CScriptFunctionExport.new("set_speed", "_script_set_speed")
	var property_export := CScriptPropertyExport.new("speed", "_script_get_speed")
	return [mount, capability, function_export, property_export]

func on_ready() -> void:
	if name == "":
		name = "MovementModule"

func _script_set_speed(value: float) -> void:
	speed = value
	var capability: C_MoveCapability = get_component(CMoveCapability)
	if capability:
		capability.speed = value

func _script_get_speed() -> float:
	var capability: C_MoveCapability = get_component(CMoveCapability)
	return capability.speed if capability else speed
