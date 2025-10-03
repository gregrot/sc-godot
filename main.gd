extends Node2D

const WorldScene := preload("res://addons/gecs/world.gd")
const MovementSystem := preload("res://robot/systems/movement_system.gd")
const RobotFactory := preload("res://robot/robot_factory.gd")
const FrameStatusComponent := preload("res://robot/components/c_frame_status.gd")

var world: World
var factory := RobotFactory.new()
var robot_frames: Array = []
var status_label: Label

func _ready() -> void:
	await _ensure_ecs_singleton()
	await _setup_world()
	status_label = _ensure_status_label()
	var button: Button = $Button
	button.text = "Assemble Robot"
	button.pressed.connect(_on_button_pressed)

func _ensure_status_label() -> Label:
	var label := Label.new()
	label.name = "RobotStatus"
	label.position = Vector2(10, 50)
	label.text = "No robots assembled yet."
	add_child(label)
	return label

func _ensure_ecs_singleton() -> void:
	var viewport := get_tree().root
	if not viewport.has_node("Root"):
		var holder := Node.new()
		holder.name = "Root"
		viewport.add_child(holder)
	if not Engine.has_singleton("ECS"):
		var ecs_singleton := preload("res://addons/gecs/ecs.gd").new()
		ecs_singleton.name = "ECS"
		viewport.add_child(ecs_singleton)
		await ecs_singleton.ready

func _setup_world() -> void:
	world = WorldScene.new()
	add_child(world)
	await world.ready
	ECS.world = world
	ECS.debug = false
	world.add_system(MovementSystem.new())

func _on_button_pressed() -> void:
	var frame := factory.build_basic_robot(world)
	robot_frames.append(frame)
	status_label.text = "Robots: %d" % robot_frames.size()
	print("Built robot with movement module:", frame.name)

func _process(delta: float) -> void:
	if Engine.has_singleton("ECS") and ECS.world != null:
		ECS.process(delta)
	_update_status_text()

func _update_status_text() -> void:
	if status_label == null:
		return
	if robot_frames.is_empty():
		status_label.text = "Robots: 0"
		return
	var lines: Array[String] = []
	for frame in robot_frames:
		if not is_instance_valid(frame):
			continue
		var status = frame.get_component(FrameStatusComponent)
		if status == null:
			continue
		lines.append("%s pos=(%.2f, %.2f)" % [frame.name, status.position.x, status.position.y])
	status_label.text = "\n".join(lines)
