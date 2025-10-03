extends BTComposite
class_name RobotScriptProgram

const KEY_ERRORS := StringName("robot_script/errors")
const KEY_RUNTIME := StringName("robot_script/runtime")

var last_status: int = BTStatus.SUCCESS
var _current_index: int = 0

func tick(delta: float, actor: Node, blackboard: Blackboard) -> BTStatus:
	var runtime := _get_runtime(blackboard)
	if runtime != null:
		runtime.clear_errors()
		blackboard.set_value(KEY_ERRORS, PackedStringArray())
	if get_child_count() == 0:
		last_status = BTStatus.SUCCESS
		return last_status
	while _current_index < get_child_count():
		var child := get_child(_current_index)
		var response: int = child.tick(delta, actor, blackboard)
		if response == BTStatus.FAILURE:
			_reset_children()
			last_status = BTStatus.FAILURE
			return last_status
		if response == BTStatus.RUNNING:
			last_status = BTStatus.RUNNING
			return last_status
		_current_index += 1
	_reset_children()
	last_status = BTStatus.SUCCESS
	return last_status

func _get_runtime(blackboard: Blackboard) -> RobotScriptRuntime:
	var value: Variant = blackboard.get_value(KEY_RUNTIME)
	return value if value is RobotScriptRuntime else null

func get_last_status() -> int:
	return last_status

func reset() -> void:
	_reset_children()

func _reset_children() -> void:
	_current_index = 0
	for child in get_children():
		if child.has_method("reset"):
			child.reset()
