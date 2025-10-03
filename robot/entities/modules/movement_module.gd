extends Entity
class_name MovementModule

const CModuleMount := preload("res://robot/components/c_module_mount.gd")
const CMoveCapability := preload("res://robot/components/c_move_capability.gd")

@export var speed: float = 4.0

func define_components() -> Array:
	var mount := CModuleMount.new("movement")
	var capability := CMoveCapability.new()
	capability.speed = speed
	return [mount, capability]

func on_ready() -> void:
	if name == "":
		name = "MovementModule"
