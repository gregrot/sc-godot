@tool
extends RobotScriptLeaf
class_name RobotScriptFunctionDefLeaf

var statement: Dictionary = {}
var _registered_runtime_id: int = 0

func _init(stmt: Dictionary = {}) -> void:
	statement = stmt

func configure(stmt: Dictionary) -> void:
	statement = stmt
	_registered_runtime_id = 0

func _on_runtime_changed(_runtime: RobotScriptRuntime, _blackboard: Blackboard) -> void:
	_registered_runtime_id = 0

func _run(_delta: float, _actor: Node, _blackboard: Blackboard, runtime: RobotScriptRuntime) -> int:
	if statement.is_empty():
		return BTStatus.SUCCESS
	if _registered_runtime_id == runtime.get_instance_id():
		return BTStatus.SUCCESS
	runtime.execute_statement(statement, runtime.get_environment())
	if runtime.has_errors():
		return BTStatus.FAILURE
	_registered_runtime_id = runtime.get_instance_id()
	return BTStatus.SUCCESS

