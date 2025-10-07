@tool
extends RobotScriptLeaf
class_name RobotScriptAssignLeaf

var statement: Dictionary = Dictionary()

func _init(stmt: Dictionary = {}) -> void:
	statement = stmt

func configure(stmt: Dictionary) -> void:
	statement = stmt

func _run(_delta: float, _actor: Node, blackboard: Blackboard, runtime: RobotScriptRuntime) -> int:
	if statement.is_empty():
		return BTStatus.SUCCESS
	var value = runtime.execute_statement(statement, runtime.get_environment())
	if runtime.has_errors():
		return BTStatus.FAILURE
	_set_last_result(blackboard, value)
	return BTStatus.SUCCESS
