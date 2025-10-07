@tool
extends Entity
class_name CpuModule

const CModuleMount := preload("res://robot/components/c_module_mount.gd")
const CCpuCapability := preload("res://robot/components/c_cpu_capability.gd")
const CCpuProgram := preload("res://robot/components/c_cpu_program.gd")

func define_components() -> Array:
	var mount := CModuleMount.new("cpu")
	var capability := CCpuCapability.new()
	var program := CCpuProgram.new()
	return [mount, capability, program]

func on_ready() -> void:
	if name == "":
		name = "CpuModule"
