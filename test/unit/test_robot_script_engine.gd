extends GutTest

var engine: RobotScriptEngine
var printed: Array

func before_each():
	engine = RobotScriptEngine.new()
	printed = []

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

func test_functions_can_call_each_other_and_builtins():
	engine.bind("print", Callable(self, "_capture_print"))
	var script := "func callOtherFunc(value)\n\tvalue\nend\n\nfunc someFunc(a, b)\n\tcallOtherFunc(a + b)\nend\n\nprint(someFunc(3, 7))"
	var result := engine.run(script)
	assert_true(result.get("ok", false), "run() should succeed with functions")
	assert_eq(1, printed.size(), "expected one print call")
	assert_eq(10, printed[0])

func test_function_argument_mismatch_reports_error():
        var script := "func onlyOne(x)\n\tx\nend\n\nonlyOne(1, 2)"
        var result := engine.run(script)
        assert_false(result.get("ok", true), "run() should fail on arity mismatch")
        var errors: PackedStringArray = result.get("errors", PackedStringArray())
        assert_true(errors.size() > 0, "errors should be reported")
        assert_true(errors[0].find("expected 1") >= 0, "message should mention expected count")

func test_array_literal_and_index_access():
        var script := "items = [1, 2, 3]\nsecond = items[1]\nitems[0]"
        var result := engine.run(script)
        assert_true(result.get("ok", false), "run() should succeed with array literals")
        var vars: Dictionary = result.get("vars", {})
        assert_true(vars.has("items"), "expected 'items' variable")
        assert_eq([1, 2, 3], vars.get("items"))
        assert_eq(2, vars.get("second"))
        assert_eq(1, result.get("result"))

func test_object_literal_supports_dot_and_index_access():
        var script := "data = {name: \"Robo\", stats: {level: 5}}\nname = data.name\nlevel = data.stats[\"level\"]\ndata.stats.level"
        var result := engine.run(script)
        assert_true(result.get("ok", false), "run() should support object access")
        var vars: Dictionary = result.get("vars", {})
        assert_eq({"name": "Robo", "stats": {"level": 5}}, vars.get("data"))
        assert_eq("Robo", vars.get("name"))
        assert_eq(5, vars.get("level"))
        assert_eq(5, result.get("result"))

func test_indexing_invalid_type_reports_error():
        var script := "value = 10[0]"
        var result := engine.run(script)
        assert_false(result.get("ok", true), "run() should fail when indexing non-indexable")
        var errors: PackedStringArray = result.get("errors", PackedStringArray())
        assert_true(errors.size() > 0, "expected at least one error")
        assert_true(errors[0].find("Cannot index value") >= 0)

func _double(value):
        return value * 2

func _capture_print(...args) -> void:
	if args.size() == 0:
		printed.append(null)
	else:
		printed.append(args[0])
