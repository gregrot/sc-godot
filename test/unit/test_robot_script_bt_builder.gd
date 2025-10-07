extends GutTest

const RobotScriptEngine := preload("res://robot_script/robot_script_engine.gd")
const RobotScriptBtBuilder := preload("res://robot_script/robot_script_bt_builder.gd")
const RobotScriptProgram := preload("res://robot_script/behaviour_nodes/robot_script_program.gd")
const RobotScriptAssignLeaf := preload("res://robot_script/behaviour_nodes/robot_script_assign_leaf.gd")
const RobotScriptExpressionLeaf := preload("res://robot_script/behaviour_nodes/robot_script_expression_leaf.gd")
const RobotScriptFunctionDefLeaf := preload("res://robot_script/behaviour_nodes/robot_script_function_def_leaf.gd")
const RobotScriptForLoop := preload("res://robot_script/behaviour_nodes/robot_script_for_loop.gd")

var engine: RobotScriptEngine
var captured_speed: Array
var recorded_calls: int

func before_each():
	engine = RobotScriptEngine.new()
	captured_speed = []
	recorded_calls = 0

func test_build_creates_expected_nodes():
	var result := engine.compile("speed = 0\nset_speed(5)")
	assert_true(result.get("ok", false))
	engine.bind("set_speed", Callable(self, "_capture_speed"))
	var build := RobotScriptBtBuilder.build(engine, result.get("ast"))
	var root: BTRoot = build.get("root")
	assert_not_null(root, "Builder should return a BTRoot")
	assert_eq(1, root.get_child_count())
	var program := root.get_child(0)
	assert_true(program is RobotScriptProgram, "First child should be RobotScriptProgram")
	assert_eq(2, program.get_child_count())
	assert_true(program.get_child(0) is RobotScriptAssignLeaf, "First statement should compile to assign leaf")
	assert_true(program.get_child(1) is RobotScriptExpressionLeaf, "Second statement should compile to expression leaf")

func test_tick_updates_environment_and_calls_builtin():
	engine.bind("set_speed", Callable(self, "_capture_speed"))
	var result := engine.compile("speed = speed + 1\nset_speed(speed)")
	assert_true(result.get("ok", false))
	var build := RobotScriptBtBuilder.build(engine, result.get("ast"), {"initial_env": {"speed": 2}})
	var program: RobotScriptProgram = build.get("root").get_child(0)
	var blackboard: Blackboard = build.get("blackboard")
	var runtime: RobotScriptRuntime = build.get("runtime")
	runtime.get_environment()["delta"] = 0.1
	blackboard.set_value(StringName("robot_script/env"), runtime.get_environment())
	var status := program.tick(1.0, null, blackboard)
	assert_eq(BTBehaviour.BTStatus.SUCCESS, status)
	assert_eq(1, captured_speed.size())
	assert_eq(3, captured_speed[0])
	assert_eq(3, runtime.get_environment().get("speed"))

func test_function_definition_executes_when_called():
	var script := "func set_speed(value)\n\tspeed = value\nend\nset_speed(7)"
	var result := engine.compile(script)
	assert_true(result.get("ok", false))
	var build := RobotScriptBtBuilder.build(engine, result.get("ast"), {"initial_env": {"speed": 0}})
	var program: RobotScriptProgram = build.get("root").get_child(0)
	var blackboard: Blackboard = build.get("blackboard")
	var runtime: RobotScriptRuntime = build.get("runtime")
        var status := program.tick(0.5, null, blackboard)
        assert_eq(BTBehaviour.BTStatus.SUCCESS, status)
	assert_eq(7, runtime.get_environment().get("speed"))
	assert_true(program.get_child(0) is RobotScriptFunctionDefLeaf)
	assert_true(program.get_child(1) is RobotScriptExpressionLeaf)

func test_runtime_errors_surface_on_blackboard():
	var result := engine.compile("value = missing + 1")
	assert_true(result.get("ok", false))
	var build := RobotScriptBtBuilder.build(engine, result.get("ast"))
	var program: RobotScriptProgram = build.get("root").get_child(0)
	var blackboard: Blackboard = build.get("blackboard")
        var status := program.tick(0.5, null, blackboard)
        assert_eq(BTBehaviour.BTStatus.FAILURE, status)
	var errors: PackedStringArray = blackboard.get_value(StringName("robot_script/errors"))
	assert_true(errors.size() > 0)
	assert_true(errors[0].find("Undefined variable") >= 0)

func test_for_loop_compiles_to_loop_node():
	var result := engine.compile("for i in 1..3\n\tvalue = i\nend")
	assert_true(result.get("ok", false))
	var build := RobotScriptBtBuilder.build(engine, result.get("ast"))
	var program: RobotScriptProgram = build.get("root").get_child(0)
	assert_true(program.get_child(0) is RobotScriptForLoop)
	var loop: RobotScriptForLoop = program.get_child(0)
	assert_eq(1, loop.get_child_count())

func test_assign_executes_immediately():
        var result := engine.compile("value = 5")
        assert_true(result.get("ok", false))
        var build := RobotScriptBtBuilder.build(engine, result.get("ast"))
        var program: RobotScriptProgram = build.get("root").get_child(0)
        var blackboard: Blackboard = build.get("blackboard")
        var runtime: RobotScriptRuntime = build.get("runtime")
        var status := program.tick(0.2, null, blackboard)
        assert_eq(BTBehaviour.BTStatus.SUCCESS, status)
        assert_eq(5, runtime.get_environment().get("value"))

func test_for_loop_executes_bound_builtin():
	recorded_calls = 0
	engine.bind("record", Callable(self, "_record"))
	var result := engine.compile("for i in 1..3\n\trecord()\nend")
	assert_true(result.get("ok", false))
	var build := RobotScriptBtBuilder.build(engine, result.get("ast"))
	var program: RobotScriptProgram = build.get("root").get_child(0)
	var blackboard: Blackboard = build.get("blackboard")
	for _i in range(6):
		program.tick(0.5, null, blackboard)
	assert_eq(3, recorded_calls)

func _capture_speed(value):
	captured_speed.append(value)

func _record():
	recorded_calls += 1
