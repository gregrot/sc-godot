extends GutTest

const WorldScene := preload("res://addons/gecs/world.gd")
const MovementSystem := preload("res://robot/systems/movement_system.gd")
const RobotCpuSystem := preload("res://robot/systems/cpu_system.gd")
const RobotFactory := preload("res://robot/robot_factory.gd")
const RobotScriptProgram := preload("res://robot_script/behaviour_nodes/robot_script_program.gd")
const RobotScriptForLoop := preload("res://robot_script/behaviour_nodes/robot_script_for_loop.gd")
const RobotScriptExpressionLeaf := preload("res://robot_script/behaviour_nodes/robot_script_expression_leaf.gd")
const BTBehaviour := preload("res://addons/behaviour_toolkit/behaviour_tree/bt_behaviour.gd")
const CFrameSlots := preload("res://robot/components/c_frame_slots.gd")
const CModuleAttachment := preload("res://robot/components/c_module_attachment.gd")
const CFrameStatus := preload("res://robot/components/c_frame_status.gd")
const CMoveCapability := preload("res://robot/components/c_move_capability.gd")
const CCpuProgram := preload("res://robot/components/c_cpu_program.gd")
const RobotScriptRuntime := preload("res://robot_script/robot_script_runtime.gd")

var world: World
var factory: RobotFactory
var ecs_singleton: Node

func before_each() -> void:
	_ensure_root_holder()
	ecs_singleton = _ensure_ecs_singleton()
	ecs_singleton.debug = false
	world = WorldScene.new()
	add_child_autofree(world)
	ecs_singleton.world = world
	assert_not_null(ecs_singleton.world, "ECS world should be assigned")
	world.initialize()
	factory = RobotFactory.new()

func after_each() -> void:
	if ecs_singleton:
		ecs_singleton.world = null
		ecs_singleton = null
	world = null
	factory = null

func test_build_basic_robot_creates_frame_and_module() -> void:
	var frame = factory.build_basic_robot(world, 6.0)
	var slots = frame.get_component(CFrameSlots)
	assert_not_null(slots, "Frame should have slots component")
	var attachments = frame.get_relationships(Relationship.new(CModuleAttachment.new("movement"), null))
	assert_not_null(attachments, "Expected a movement module attachment")
	assert_eq(1, attachments.size())

func test_movement_system_updates_frame_position() -> void:
	var frame = factory.build_basic_robot(world, 3.0)
	var status = frame.get_component(CFrameStatus)
	assert_eq(Vector2.ZERO, status.position)
	var relation = frame.get_relationships(Relationship.new(CModuleAttachment.new("movement"), null))
	var module = relation[0].target
	var system := MovementSystem.new()
	system.process(module, 1.0)
	system.free()
	assert_gt(status.position.x, 0.0)

func test_cpu_module_binds_exports_into_robot_script() -> void:
	var frame = factory.build_basic_robot(world, 1.0)
	var cpu_module = _get_module(frame, "cpu")
	var program_component: Resource = cpu_module.get_component(CCpuProgram)
	assert_true(str(program_component.script_text).find("move") >= 0)
	var status: C_FrameStatus = frame.get_component(CFrameStatus)
	assert_eq(0.0, status.rotation_degrees)
	assert_eq(Vector2.ZERO, status.position)
	var cpu_system = RobotCpuSystem.new()
	var steps := 0
	while frame.get_meta("move_call_count", 0) < 10 and steps < 100:
		cpu_system.process(cpu_module, 1.0)
		steps += 1
	cpu_system.free()
	var cache: Dictionary = cpu_module.get_meta("_robot_script_bt_cache", {})
	var program: RobotScriptProgram = cache.get("program")
	assert_true(program is RobotScriptProgram)
	assert_true(program.get_child_count() > 0)
	assert_true(program.get_child(0) is RobotScriptForLoop)
	var body_program: RobotScriptProgram = program.get_child(0).get_child(0)
	assert_eq(2, body_program.get_child_count())
	assert_true(body_program.get_child(0) is RobotScriptExpressionLeaf)
	assert_true(body_program.get_child(1) is RobotScriptExpressionLeaf)
	var result = cpu_module.get_meta("last_program_result", {})
	assert_true(result.get("ok", false))
	var result_vars: Dictionary = result.get("vars", {})
	assert_eq(10, result_vars.get("i"))
	var runtime: RobotScriptRuntime = cache.get("runtime")
	var env: Dictionary = runtime.snapshot_environment()
	assert_true(env.has("i"))
	assert_almost_eq(100.0, frame.get_meta("last_move_distance", 0.0), 0.001)
	assert_almost_eq(90.0, frame.get_meta("last_turn_angle", 0.0), 0.001)
	assert_eq(10, frame.get_meta("move_call_count", 0))
	assert_eq(10, frame.get_meta("turn_call_count", 0))
	assert_almost_eq(180.0, status.rotation_degrees, 0.001)
	assert_almost_eq(100.0, status.position.x, 0.001)
	assert_almost_eq(100.0, status.position.y, 0.001)


func _ensure_root_holder() -> void:
	var viewport := get_tree().root
	if not viewport.has_node("Root"):
		var holder := Node.new()
		holder.name = "Root"
		viewport.add_child(holder)

func _ensure_ecs_singleton() -> Node:
	if Engine.has_singleton("ECS"):
		return Engine.get_singleton("ECS")
	var ecs := preload("res://addons/gecs/ecs.gd").new()
	ecs.name = "ECS"
	get_tree().root.add_child(ecs)
	return ecs

func _get_module(frame: Entity, slot_name: String) -> Entity:
	var attachments = frame.get_relationships(Relationship.new(CModuleAttachment.new(slot_name), null))
	assert_not_null(attachments, "expected attachment for %s" % slot_name)
	assert_gt(attachments.size(), 0, "no modules attached to slot %s" % slot_name)
	return attachments[0].target
