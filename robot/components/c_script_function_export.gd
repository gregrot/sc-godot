extends Component
class_name C_ScriptFunctionExport

@export var function_name: String = ""
@export var method_name: String = ""

func _init(_function_name: String = "", _method_name: String = "") -> void:
	function_name = _function_name
	method_name = _method_name
