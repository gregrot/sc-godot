extends Node2D

const WorldScene := preload("res://addons/gecs/world.gd")
const MovementSystem := preload("res://robot/systems/movement_system.gd")
const RobotCpuSystem := preload("res://robot/systems/cpu_system.gd")
const RobotFactory := preload("res://robot/robot_factory.gd")
const FrameStatusComponent := preload("res://robot/components/c_frame_status.gd")

var world: World
var factory := RobotFactory.new()
var robot_frames: Array = []
var status_label: Label
var frame_visuals: Dictionary = {}

func _ready() -> void:
	await _ensure_ecs_singleton()
	await _setup_world()
	status_label = _ensure_status_label()
	_spawn_robot()
	set_process(true)

func _ensure_status_label() -> Label:
	var label := Label.new()
	label.name = "RobotStatus"
	label.position = Vector2(10, 10)
	label.text = "Robots: 0"
	add_child(label)
	return label

func _ensure_ecs_singleton() -> void:
	var viewport := get_tree().root
	if not viewport.has_node("Root"):
		var holder := Node.new()
		holder.name = "Root"
		viewport.call_deferred("add_child", holder)
		await get_tree().process_frame
	if not Engine.has_singleton("ECS"):
		var ecs_singleton := preload("res://addons/gecs/ecs.gd").new()
		ecs_singleton.name = "ECS"
		viewport.call_deferred("add_child", ecs_singleton)
		await ecs_singleton.ready

func _setup_world() -> void:
	world = $World
	if not world.is_node_ready():
		await world.ready
	ECS.world = world
	ECS.debug = false
	world.add_system(RobotCpuSystem.new())
	world.add_system(MovementSystem.new())

func _spawn_robot(speed: float = 4.0) -> void:
	var frame := factory.build_basic_robot(world, speed)
	_ensure_frame_visual(frame)
	robot_frames.append(frame)
	_update_status_text()

func _ensure_frame_visual(frame) -> void:
	if frame_visuals.has(frame):
		return
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array([
		Vector2(-16, -12),
		Vector2(16, 0),
		Vector2(-16, 12)
	])
	shape.color = Color.hex(0x4fd5ffff)
	add_child(shape)
	frame_visuals[frame] = shape

func _update_frame_visual(frame, position: Vector2) -> void:
	_ensure_frame_visual(frame)
	var shape: Polygon2D = frame_visuals[frame]
	shape.position = position

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
		var pos: Vector2 = Vector2.ZERO
		var status = frame.get_component(FrameStatusComponent)
		if status != null:
			pos = status.position
		if frame.has_meta("position"):
			var meta_pos = frame.get_meta("position")
			if meta_pos is Vector2:
				pos = meta_pos
		_update_frame_visual(frame, pos)
		lines.append("%s pos=(%.2f, %.2f)" % [frame.name, pos.x, pos.y])
	status_label.text = "Robots: %d\n%s" % [robot_frames.size(), "\n".join(lines)]
