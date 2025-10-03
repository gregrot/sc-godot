extends RefCounted
class_name RobotScriptRuntime

const Parser := preload("res://robot_script/robot_script_parser.gd")
const NODE_PROGRAM := Parser.NODE_PROGRAM
const NODE_ASSIGN := Parser.NODE_ASSIGN
const NODE_EXPR_STMT := Parser.NODE_EXPR_STMT
const NODE_BINARY := Parser.NODE_BINARY
const NODE_UNARY := Parser.NODE_UNARY
const NODE_LITERAL := Parser.NODE_LITERAL
const NODE_VAR := Parser.NODE_VAR
const NODE_CALL := Parser.NODE_CALL
const NODE_FUNCTION := Parser.NODE_FUNCTION

const FUNCTION_KIND := "__function__"
const ENV_PARENT_KEY := "__parent__"

var builtins: Dictionary
var env: Dictionary
var errors: PackedStringArray = PackedStringArray()

func _init(builtins_map: Dictionary = {}, initial_env: Dictionary = {}) -> void:
	builtins = builtins_map.duplicate(true)
	env = initial_env.duplicate(true)
	env.erase(ENV_PARENT_KEY)

func set_environment(environment: Dictionary) -> void:
	env = environment
	env.erase(ENV_PARENT_KEY)

func get_environment() -> Dictionary:
	return env

func clear_errors() -> void:
	errors.clear()

func has_errors() -> bool:
	return errors.size() > 0

func get_errors() -> PackedStringArray:
	return errors.duplicate()

func execute_program(ast: Dictionary) -> Variant:
	clear_errors()
	var last: Variant = null
	for stmt in ast.get("body", []):
		last = execute_statement(stmt, env)
		if has_errors():
			return last
	return last

func execute_statement(stmt: Dictionary, scope: Dictionary = env) -> Variant:
	match stmt.get("type"):
		NODE_ASSIGN:
			var value: Variant = evaluate_expression(stmt.get("expr"), scope)
			if has_errors():
				return null
			_env_assign(scope, stmt.get("name"), value)
			return value
		NODE_EXPR_STMT:
			return evaluate_expression(stmt.get("expr"), scope)
		NODE_FUNCTION:
			var fn_def: Dictionary = {
				"name": stmt.get("name"),
				"params": stmt.get("params", []),
				"body": stmt.get("body", []),
				"closure": scope,
				FUNCTION_KIND: true
			}
			scope[stmt.get("name")] = fn_def
			return null
		_:
			_report_error("Runtime: Unknown statement type '%s'." % str(stmt.get("type")))
			return null

func evaluate_expression(node: Dictionary, scope: Dictionary = env) -> Variant:
	match node.get("type"):
		NODE_LITERAL:
			return node.get("value")
		NODE_VAR:
			var name: String = node.get("name", "")
			if not _env_has(scope, name):
				_report_error("Runtime %d:%d: Undefined variable '%s'." % [node.get("line", 0), node.get("col", 0), name])
				return null
			return _env_get(scope, name)
		NODE_UNARY:
			var v: Variant = evaluate_expression(node.get("expr"), scope)
			if has_errors():
				return null
			if node.get("op") == "-":
				if not (v is float or v is int):
					_report_error("Runtime: Unary '-' requires a number, got %s." % typeof(v))
					return null
				return -v
			_report_error("Runtime: Unknown unary operator '%s'." % node.get("op"))
			return null
		NODE_BINARY:
			var a: Variant = evaluate_expression(node.get("left"), scope)
			var b: Variant = evaluate_expression(node.get("right"), scope)
			if has_errors():
				return null
			match node.get("op"):
				"+":
					if (a is float or a is int) and (b is float or b is int):
						return a + b
					if (a is String) or (b is String):
						return str(a) + str(b)
					_report_error("Runtime: '+' requires numbers or strings.")
					return null
				"-":
					if (a is float or a is int) and (b is float or b is int):
						return a - b
					_report_error("Runtime: '-' requires numbers.")
					return null
				"*":
					if (a is float or a is int) and (b is float or b is int):
						return a * b
					_report_error("Runtime: '*' requires numbers.")
					return null
				"/":
					if (a is float or a is int) and (b is float or b is int):
						if float(b) == 0.0:
							_report_error("Runtime: Division by zero.")
							return null
						return float(a) / float(b)
					_report_error("Runtime: '/' requires numbers.")
					return null
				_:
					_report_error("Runtime: Unknown binary operator '%s'." % node.get("op"))
					return null
		NODE_CALL:
			var fn_name: String = node.get("name", "")
			var args: Array = []
			for a_node in node.get("args", []):
				var av: Variant = evaluate_expression(a_node, scope)
				args.append(av)
				if has_errors():
					return null
			if _env_has(scope, fn_name):
				var target: Variant = _env_get(scope, fn_name)
				if target is Callable:
					return target.callv(args)
				if target is Dictionary and target.get(FUNCTION_KIND, false):
					return _call_user_function(target, args)
			if builtins.has(fn_name):
				var cb: Callable = builtins[fn_name]
				return cb.callv(args)
			_report_error("Runtime %d:%d: Unknown function '%s'." % [node.get("line", 0), node.get("col", 0), fn_name])
			return null
		_:
			_report_error("Runtime: Unknown expression type '%s'." % str(node.get("type")))
			return null

func snapshot_environment(scope: Variant = env) -> Dictionary:
	if not (scope is Dictionary):
		return {}
	var copy: Dictionary = {}
	for key in scope.keys():
		if key == ENV_PARENT_KEY:
			continue
		var value: Variant = scope[key]
		if value is Dictionary and value.get(FUNCTION_KIND, false):
			continue
		copy[key] = value
	return copy

func _call_user_function(func_def: Dictionary, args: Array) -> Variant:
	var params: Array = func_def.get("params", [])
	var name: String = func_def.get("name", "<function>")
	if args.size() != params.size():
		_report_error("Runtime: Function '%s' expected %d arguments but got %d." % [name, params.size(), args.size()])
		return null
	var parent_env: Dictionary = func_def.get("closure", {})
	var local_env: Dictionary = {ENV_PARENT_KEY: parent_env}
	for idx in params.size():
		local_env[params[idx]] = args[idx]
	var last: Variant = null
	for stmt in func_def.get("body", []):
		last = execute_statement(stmt, local_env)
		if has_errors():
			return null
	return last

func _env_has(scope: Dictionary, name: String) -> bool:
	var current: Variant = scope
	while current is Dictionary:
		var dict: Dictionary = current
		if dict.has(name):
			return true
		current = dict.get(ENV_PARENT_KEY, null)
	return false

func _env_get(scope: Dictionary, name: String) -> Variant:
	var current: Variant = scope
	while current is Dictionary:
		var dict: Dictionary = current
		if dict.has(name):
			return dict[name]
		current = dict.get(ENV_PARENT_KEY, null)
	return null

func _env_assign(scope: Dictionary, name: String, value: Variant) -> void:
	var current: Variant = scope
	while current is Dictionary:
		var dict: Dictionary = current
		if dict.has(name):
			dict[name] = value
			return
		current = dict.get(ENV_PARENT_KEY, null)
	scope[name] = value

func _report_error(msg: String) -> void:
	errors.append(msg)
