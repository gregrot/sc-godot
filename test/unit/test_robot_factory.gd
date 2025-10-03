extends GutTest

const WorldScene := preload("res://addons/gecs/world.gd")
const MovementSystem := preload("res://robot/systems/movement_system.gd")
const RobotFactory := preload("res://robot/robot_factory.gd")
const CFrameSlots := preload("res://robot/components/c_frame_slots.gd")
const CModuleAttachment := preload("res://robot/components/c_module_attachment.gd")
const CFrameStatus := preload("res://robot/components/c_frame_status.gd")

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
