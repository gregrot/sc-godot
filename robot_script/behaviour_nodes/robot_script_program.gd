extends BTComposite
class_name RobotScriptProgram

const KEY_ERRORS := StringName("robot_script/errors")
const KEY_RUNTIME := StringName("robot_script/runtime")

var last_status: int = BTStatus.SUCCESS

func tick(delta: float, actor: Node, blackboard: Blackboard) -> BTStatus:
	var runtime := _get_runtime(blackboard)
	if runtime != null:
		runtime.clear_errors()
		blackboard.set_value(KEY_ERRORS, PackedStringArray())
	var status := BTStatus.SUCCESS
	for child in get_children():
		var response: int = child.tick(delta, actor, blackboard)
		if response == BTStatus.FAILURE:
			last_status = BTStatus.FAILURE
			return last_status
		if response == BTStatus.RUNNING:
			status = BTStatus.RUNNING
	last_status = status
	return last_status

func _get_runtime(blackboard: Blackboard) -> RobotScriptRuntime:
	var value: Variant = blackboard.get_value(KEY_RUNTIME)
	return value if value is RobotScriptRuntime else null

func get_last_status() -> int:
	return last_status
