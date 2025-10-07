@tool
extends BTLeaf
class_name RobotScriptLeaf

const KEY_RUNTIME := StringName("robot_script/runtime")
const KEY_ENV := StringName("robot_script/env")
const KEY_LAST_RESULT := StringName("robot_script/last_result")
const KEY_ERRORS := StringName("robot_script/errors")

var _runtime_id: int = 0
var last_status: int = BTStatus.SUCCESS

func tick(delta: float, actor: Node, blackboard: Blackboard) -> BTStatus:
	var runtime: RobotScriptRuntime = _get_runtime(blackboard)
	if runtime == null:
		last_status = BTStatus.FAILURE
		return last_status as BTStatus
	if runtime.get_instance_id() != _runtime_id:
		_runtime_id = runtime.get_instance_id()
		_on_runtime_changed(runtime, blackboard)
	var status: int = _run(delta, actor, blackboard, runtime)
	if runtime.has_errors():
		blackboard.set_value(KEY_ERRORS, runtime.get_errors())
		last_status = BTStatus.FAILURE
		return last_status as BTStatus
	if status == BTStatus.RUNNING:
		last_status = BTStatus.RUNNING
		return last_status as BTStatus
	_sync_environment(runtime, blackboard)
	if status == BTStatus.SUCCESS:
		_on_success(runtime, blackboard)
	last_status = status
	return last_status as BTStatus

func _run(_delta: float, _actor: Node, _blackboard: Blackboard, _runtime: RobotScriptRuntime) -> int:
	return BTStatus.SUCCESS

func _on_runtime_changed(_runtime: RobotScriptRuntime, _blackboard: Blackboard) -> void:
	pass

func _on_success(_runtime: RobotScriptRuntime, _blackboard: Blackboard) -> void:
	pass

func _sync_environment(runtime: RobotScriptRuntime, blackboard: Blackboard) -> void:
	blackboard.set_value(KEY_ENV, runtime.get_environment())

func _get_runtime(blackboard: Blackboard) -> RobotScriptRuntime:
	var value: Variant = blackboard.get_value(KEY_RUNTIME)
	return value if value is RobotScriptRuntime else null

func _set_last_result(blackboard: Blackboard, value: Variant) -> void:
	blackboard.set_value(KEY_LAST_RESULT, value)

func get_last_status() -> int:
	return last_status

func reset() -> void:
	pass
