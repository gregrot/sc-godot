extends GutTest

var engine: RobotScriptEngine

func before_each():
	engine = RobotScriptEngine.new()

func test_run_assigns_variables_and_returns_last_value():
	var result := engine.run("answer = 1 + 2\nanswer")
	assert_true(result.get("ok", false), "run() should succeed")
	assert_eq(3, result.get("result"))
	var vars: Dictionary = result.get("vars", {})
	assert_true(vars.has("answer"), "expected variable 'answer'")
	assert_eq(3, vars.get("answer"))

func test_compile_and_execute_reuse_compiled_ast():
	var compiled := engine.compile("total = total + delta")
	assert_true(compiled.get("ok", false), "compile() should succeed")

	var first := engine.execute(compiled, {"total": 2, "delta": 10})
	assert_true(first.get("ok", false), "execute() should succeed")
	assert_eq(12, first.get("vars", {}).get("total"))

	var second := engine.execute(compiled, {"total": -5, "delta": 3})
	assert_true(second.get("ok", false), "execute() should succeed on reuse")
	assert_eq(-2, second.get("vars", {}).get("total"))

func test_run_reports_undefined_variable_errors():
	var result := engine.run("value = missing + 1")
	assert_false(result.get("ok", true), "run() should fail when variable missing")
	var errors: PackedStringArray = result.get("errors", PackedStringArray())
	assert_true(errors.size() > 0, "errors should be reported")
	assert_true(errors[0].find("Undefined variable") >= 0, "error message should mention undefined variable")

func test_run_invokes_bound_callable():
	engine.bind("double", Callable(self, "_double"))
	var result := engine.run("value = double(4)")
	assert_true(result.get("ok", false), "run() should succeed with bound callable")
	assert_eq(8, result.get("vars", {}).get("value"))

func _double(value):
	return value * 2
