extends RefCounted
class_name RobotScriptBtBuilder

const Parser := preload("res://robot_script/robot_script_parser.gd")
const Blackboard := preload("res://addons/behaviour_toolkit/blackboard.gd")
const BTRoot := preload("res://addons/behaviour_toolkit/behaviour_tree/bt_root.gd")
const RobotScriptProgram := preload("res://robot_script/behaviour_nodes/robot_script_program.gd")
const RobotScriptAssignLeaf := preload("res://robot_script/behaviour_nodes/robot_script_assign_leaf.gd")
const RobotScriptExpressionLeaf := preload("res://robot_script/behaviour_nodes/robot_script_expression_leaf.gd")
const RobotScriptFunctionDefLeaf := preload("res://robot_script/behaviour_nodes/robot_script_function_def_leaf.gd")

const KEY_RUNTIME := StringName("robot_script/runtime")
const KEY_ENV := StringName("robot_script/env")
const KEY_LAST_RESULT := StringName("robot_script/last_result")
const KEY_ERRORS := StringName("robot_script/errors")

static func build(engine: RobotScriptEngine, ast: Dictionary, config: Dictionary = {}) -> Dictionary:
	var runtime: RobotScriptRuntime = engine.create_runtime(config.get("initial_env", {}))
	var blackboard: Blackboard = Blackboard.new()
	blackboard.content = {}
	blackboard.set_value(KEY_RUNTIME, runtime)
	blackboard.set_value(KEY_ENV, runtime.get_environment())
	blackboard.set_value(KEY_LAST_RESULT, null)
	blackboard.set_value(KEY_ERRORS, PackedStringArray())

	var root: BTRoot = BTRoot.new()
	root.autostart = false
	root.blackboard = blackboard
	root.name = config.get("root_name", "RobotScriptTree")

	var program: RobotScriptProgram = RobotScriptProgram.new()
	program.name = "Program"
	root.add_child(program)

	for stmt in ast.get("body", []):
		var node: Node = _build_statement(stmt)
		if node == null:
			continue
		program.add_child(node)

	return {
		"root": root,
		"runtime": runtime,
		"blackboard": blackboard
	}

static func _build_statement(stmt: Dictionary) -> Node:
	match stmt.get("type"):
		Parser.NODE_ASSIGN:
			var assign := RobotScriptAssignLeaf.new(stmt)
			assign.name = "Assign_" + stmt.get("name", "")
			return assign
		Parser.NODE_EXPR_STMT:
			var expr_node := RobotScriptExpressionLeaf.new(stmt.get("expr", {}))
			expr_node.name = "Expr"
			return expr_node
		Parser.NODE_FUNCTION:
			var fn_node := RobotScriptFunctionDefLeaf.new(stmt)
			fn_node.name = "Func_" + stmt.get("name", "")
			return fn_node
		_:
			return null
