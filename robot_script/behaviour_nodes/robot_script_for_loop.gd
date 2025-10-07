@tool
extends BTComposite
class_name RobotScriptForLoop

const KEY_RUNTIME := StringName("robot_script/runtime")
const KEY_ERRORS := StringName("robot_script/errors")

var iterator_name: String = ""
var start_expr: Dictionary = {}
var end_expr: Dictionary = {}

var _runtime_id: int = 0
var _initialized: bool = false
var _current_value: int = 0
var _target_value: int = 0
var _step: int = 1

var last_status: int = BTStatus.SUCCESS

func configure(stmt: Dictionary) -> void:
	iterator_name = stmt.get("iter", "i")
	start_expr = stmt.get("start", {})
	end_expr = stmt.get("end", {})
	_initialized = false

func reset() -> void:
	_initialized = false
	_runtime_id = 0
	if get_child_count() > 0 and get_child(0).has_method("reset"):
		get_child(0).reset()

func tick(delta: float, actor: Node, blackboard: Blackboard) -> int:
	var runtime: RobotScriptRuntime = _get_runtime(blackboard)
	if runtime == null:
		last_status = BTStatus.FAILURE
		return last_status
	if runtime.get_instance_id() != _runtime_id:
		_runtime_id = runtime.get_instance_id()
		_initialized = false
		if get_child_count() > 0 and get_child(0).has_method("reset"):
			get_child(0).reset()
	if not _initialized:
		if not _initialize_loop(runtime, blackboard):
			last_status = BTStatus.FAILURE
			return last_status
	if _step == 0:
		last_status = BTStatus.SUCCESS
		return last_status
	if get_child_count() == 0:
		if not _advance_iteration(runtime, true):
			last_status = BTStatus.SUCCESS
			_initialized = false
		return last_status
	var body := get_child(0)
	var response: int = body.tick(delta, actor, blackboard)
	if response == BTStatus.RUNNING:
		last_status = BTStatus.RUNNING
		return last_status
	if response == BTStatus.FAILURE:
		last_status = BTStatus.FAILURE
		return last_status
	if not _advance_iteration(runtime, false):
		last_status = BTStatus.SUCCESS
		_initialized = false
		if body.has_method("reset"):
			body.reset()
		return last_status
	if body.has_method("reset"):
		body.reset()
	last_status = BTStatus.RUNNING
	return last_status

func _initialize_loop(runtime: RobotScriptRuntime, blackboard: Blackboard) -> bool:
	var start_value: Variant = runtime.evaluate_expression(start_expr, runtime.get_environment())
	if runtime.has_errors():
		blackboard.set_value(KEY_ERRORS, runtime.get_errors())
		return false
	var end_value: Variant = runtime.evaluate_expression(end_expr, runtime.get_environment())
	if runtime.has_errors():
		blackboard.set_value(KEY_ERRORS, runtime.get_errors())
		return false
	if not (start_value is int or start_value is float):
		blackboard.set_value(KEY_ERRORS, PackedStringArray(["Runtime: For-loop start must be a number."]))
		return false
	if not (end_value is int or end_value is float):
		blackboard.set_value(KEY_ERRORS, PackedStringArray(["Runtime: For-loop end must be a number."]))
		return false
	_current_value = int(start_value)
	_target_value = int(end_value)
	_step = 1 if _current_value <= _target_value else -1
	runtime.assign(iterator_name, _current_value, runtime.get_environment())
	if get_child_count() > 0 and get_child(0).has_method("reset"):
		get_child(0).reset()
	_initialized = true
	return true

func _advance_iteration(runtime: RobotScriptRuntime, initializing: bool) -> bool:
	if initializing:
		if _step == 0:
			return false
		return true
	if _current_value == _target_value:
		return false
	_current_value += _step
	runtime.assign(iterator_name, _current_value, runtime.get_environment())
	return true

func _get_runtime(blackboard: Blackboard) -> RobotScriptRuntime:
	var value: Variant = blackboard.get_value(KEY_RUNTIME)
	return value if value is RobotScriptRuntime else null
