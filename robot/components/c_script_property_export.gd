extends Component
class_name C_ScriptPropertyExport

@export var property_name: String = ""
@export var getter_method: String = ""

func _init(_property_name: String = "", _getter_method: String = "") -> void:
	property_name = _property_name
	getter_method = _getter_method
