extends RefCounted
class_name RobotScriptEngine

const Lexer = preload("res://robot_script/robot_script_lexer.gd")
const Parser = preload("res://robot_script/robot_script_parser.gd")

const NODE_PROGRAM := Parser.NODE_PROGRAM
const NODE_ASSIGN := Parser.NODE_ASSIGN
const NODE_EXPR_STMT := Parser.NODE_EXPR_STMT
const NODE_BINARY := Parser.NODE_BINARY
const NODE_UNARY := Parser.NODE_UNARY
const NODE_LITERAL := Parser.NODE_LITERAL
const NODE_VAR := Parser.NODE_VAR
const NODE_CALL := Parser.NODE_CALL

var _builtins: Dictionary = {}
var _errors: PackedStringArray = PackedStringArray()

func bind(name: String, fn: Callable) -> void:
	_builtins[name] = fn

func unbind(name: String) -> void:
	_builtins.erase(name)

func clear_builtins() -> void:
	_builtins.clear()

func run(script_text: String, variables: Dictionary = {}) -> Dictionary:
	_errors.clear()
	var tokens: Array = _tokenize(script_text)
	if _has_errors():
		return _fail()
	var ast: Dictionary = _parse(tokens)
	if _has_errors():
		return _fail()
	return _execute(ast, variables)

func compile(script_text: String) -> Dictionary:
	_errors.clear()
	var tokens: Array = _tokenize(script_text)
	if _has_errors():
		return _fail()
	var ast: Dictionary = _parse(tokens)
	if _has_errors():
		return _fail()
	return {"ok": true, "ast": ast}

func execute(compiled: Dictionary, variables: Dictionary = {}) -> Dictionary:
	if not compiled.has("ast"):
		return {"ok": false, "errors": PackedStringArray(["Missing 'ast' in compiled dictionary"])}
	_errors.clear()
	return _execute(compiled["ast"], variables)

func _tokenize(src: String) -> Array:
	return Lexer.tokenize(src, func(msg): _report_error(msg))

func _parse(tokens: Array) -> Dictionary:
	return Parser.parse(tokens, func(msg): _report_error(msg))

func _execute(ast: Dictionary, variables: Dictionary) -> Dictionary:
	var env: Dictionary = variables.duplicate()
	var last: Variant = null
	for stmt in ast["body"]:
		last = _exec_stmt(stmt, env)
		if _has_errors():
			return _fail(env)
	return {"ok": true, "result": last, "vars": env}

func _exec_stmt(stmt: Dictionary, env: Dictionary) -> Variant:
	match stmt["type"]:
		NODE_ASSIGN:
			var v: Variant = _eval_expr(stmt["expr"], env)
			if _has_errors():
				return null
			env[stmt["name"]] = v
			return v
		NODE_EXPR_STMT:
			return _eval_expr(stmt["expr"], env)
		_:
			_report_error("Runtime: Unknown statement type '%s'." % str(stmt["type"]))
			return null

func _eval_expr(node: Dictionary, env: Dictionary) -> Variant:
	match node["type"]:
		NODE_LITERAL:
			return node["value"]
		NODE_VAR:
			if not env.has(node["name"]):
				_report_error("Runtime %d:%d: Undefined variable '%s'." % [node.get("line", 0), node.get("col", 0), node["name"]])
				return null
			return env[node["name"]]
		NODE_UNARY:
			var v: Variant = _eval_expr(node["expr"], env)
			if _has_errors():
				return null
			if node["op"] == "-":
				if not (v is float or v is int):
					_report_error("Runtime: Unary '-' requires a number, got %s." % typeof(v))
					return null
				return -v
			_report_error("Runtime: Unknown unary operator '%s'." % node["op"])
			return null
		NODE_BINARY:
			var a: Variant = _eval_expr(node["left"], env)
			var b: Variant = _eval_expr(node["right"], env)
			if _has_errors():
				return null
			match node["op"]:
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
					_report_error("Runtime: Unknown binary operator '%s'." % node["op"])
					return null
		NODE_CALL:
			var fn_name: String = node["name"]
			var args: Array = []
			for a_node in node["args"]:
				var av: Variant = _eval_expr(a_node, env)
				args.append(av)
				if _has_errors():
					return null
			if env.has(fn_name) and env[fn_name] is Callable:
				var c: Callable = env[fn_name]
				return c.callv(args)
			if _builtins.has(fn_name):
				var cb: Callable = _builtins[fn_name]
				return cb.callv(args)
			_report_error("Runtime %d:%d: Unknown function '%s'." % [node.get("line", 0), node.get("col", 0), fn_name])
			return null
		_:
			_report_error("Runtime: Unknown expression type '%s'." % str(node["type"]))
			return null

func _report_error(msg: String) -> void:
	_errors.append(msg)

func _has_errors() -> bool:
	return _errors.size() > 0

func _fail(vars: Dictionary = {}) -> Dictionary:
	return {"ok": false, "errors": _errors.duplicate(), "vars": vars}
