extends RobotScriptLeaf
class_name RobotScriptExpressionLeaf

var expression: Dictionary = Dictionary()

func _init(expr: Dictionary = {}) -> void:
	expression = expr

func configure(expr: Dictionary) -> void:
	expression = expr

func _run(_delta: float, _actor: Node, blackboard: Blackboard, runtime: RobotScriptRuntime) -> int:
	if expression.is_empty():
		return BTStatus.SUCCESS
	var value = runtime.evaluate_expression(expression, runtime.get_environment())
	if runtime.has_errors():
		return BTStatus.FAILURE
	_set_last_result(blackboard, value)
	return BTStatus.SUCCESS
