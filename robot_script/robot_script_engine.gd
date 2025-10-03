extends RefCounted
class_name RobotScriptEngine

const Lexer = preload("res://robot_script/robot_script_lexer.gd")
const Parser = preload("res://robot_script/robot_script_parser.gd")
const Runtime = preload("res://robot_script/robot_script_runtime.gd")

var _builtins: Dictionary = {}
var _errors: PackedStringArray = PackedStringArray()

func bind(name: String, fn: Callable) -> void:
	_builtins[name] = fn

func unbind(name: String) -> void:
	_builtins.erase(name)

func clear_builtins() -> void:
	_builtins.clear()

func run(script_text: String, variables: Dictionary = {}) -> Dictionary:
	print("Running script")
	_errors.clear()
	var tokens: Array = _tokenize(script_text)
	if _has_errors():
		return _fail()
	var ast: Dictionary = _parse(tokens)
	if _has_errors():
		return _fail()
	return _execute_runtime(ast, variables)

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
	return _execute_runtime(compiled["ast"], variables)

func create_runtime(initial_env: Dictionary = {}) -> RobotScriptRuntime:
	var runtime: RobotScriptRuntime = Runtime.new(_builtins, initial_env)
	return runtime

func _tokenize(src: String) -> Array:
	return Lexer.tokenize(src, func(msg): _report_error(msg))

func _parse(tokens: Array) -> Dictionary:
	return Parser.parse(tokens, func(msg): _report_error(msg))

func _execute_runtime(ast: Dictionary, variables: Dictionary) -> Dictionary:
	var runtime: RobotScriptRuntime = create_runtime(variables)
	var result: Variant = runtime.execute_program(ast)
	var snapshot := runtime.snapshot_environment()
	if runtime.has_errors():
		return {
			"ok": false,
			"errors": runtime.get_errors(),
			"result": result,
			"vars": snapshot
		}
	return {"ok": true, "result": result, "vars": snapshot}

func _report_error(msg: String) -> void:
	_errors.append(msg)

func _has_errors() -> bool:
	return _errors.size() > 0

func _fail(vars: Dictionary = {}) -> Dictionary:
	return {"ok": false, "errors": _errors.duplicate(), "vars": vars.duplicate()}
