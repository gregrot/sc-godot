extends Node2D

const WorldScene := preload("res://addons/gecs/world.gd")
const MovementSystem := preload("res://robot/systems/movement_system.gd")
const RobotCpuSystem := preload("res://robot/systems/cpu_system.gd")
const RobotFactory := preload("res://robot/robot_factory.gd")
const FrameStatusComponent := preload("res://robot/components/c_frame_status.gd")
const CpuCapabilityComponent := preload("res://robot/components/c_cpu_capability.gd")
const RobotBtDebugPanel := preload("res://robot/ui/robot_bt_debug_panel.tscn")

var world: World
var ecs: _ECS
var factory := RobotFactory.new()
var robot_frames: Array = []
var status_label: Label
var frame_visuals: Dictionary = {}
var bt_debug_panel: Control
var cached_cpu_modules: Array = []


func _ready() -> void:
	ecs = await _ensure_ecs_singleton()
	await _setup_world()
	status_label = _ensure_status_label()
	_spawn_robot()
	_ensure_toggle_action()
	bt_debug_panel = RobotBtDebugPanel.instantiate()
	bt_debug_panel.visible = false
	bt_debug_panel.position = Vector2(20, 80)
	bt_debug_panel.size = Vector2(360, 320)
	add_child(bt_debug_panel)
	bt_debug_panel.call_deferred("set_cpu_modules", [])
	set_process(true)

func _ensure_status_label() -> Label:
	var label := Label.new()
	label.name = "RobotStatus"
	label.position = Vector2(10, 10)
	label.text = "Robots: 0"
	add_child(label)
	return label

func _ensure_ecs_singleton() -> _ECS:
	var viewport := get_tree().root
	if not viewport.has_node("Root"):
		var holder := Node.new()
		holder.name = "Root"
		viewport.call_deferred("add_child", holder)
		await get_tree().process_frame

	var existing: _ECS = null
	if Engine.has_singleton("ECS"):
		existing = Engine.get_singleton("ECS")
	elif viewport.has_node("ECS"):
		existing = viewport.get_node("ECS")

	if existing == null:
		var ecs_singleton := preload("res://addons/gecs/ecs.gd").new()
		ecs_singleton.name = "ECS"
		viewport.call_deferred("add_child", ecs_singleton)
		await ecs_singleton.ready
		existing = ecs_singleton
	elif not existing.is_inside_tree():
		viewport.call_deferred("add_child", existing)
		await existing.ready

	return existing

func _setup_world() -> void:
	world = $World
	if not world.is_node_ready():
		await world.ready
	if ecs == null:
		push_error("ECS singleton not available")
		return
	ecs.world = world
	ecs.debug = false
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
	if is_instance_valid(ecs) and ecs.world != null:
		ecs.process(delta)
	_handle_debug_panel_input()
	_update_debug_panel_modules()
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

func _ensure_toggle_action() -> void:
	if InputMap.has_action("toggle_bt_debug"):
		return
	InputMap.add_action("toggle_bt_debug")
	var event := InputEventKey.new()
	event.keycode = KEY_F6
	InputMap.action_add_event("toggle_bt_debug", event)

func _handle_debug_panel_input() -> void:
	if bt_debug_panel == null:
		return
	if Input.is_action_just_pressed("toggle_bt_debug"):
		bt_debug_panel.visible = not bt_debug_panel.visible

func _update_debug_panel_modules() -> void:
	if bt_debug_panel == null or world == null:
		return
	var modules := _collect_cpu_modules()
	if modules != cached_cpu_modules:
		cached_cpu_modules = modules.duplicate()
		bt_debug_panel.set_cpu_modules(cached_cpu_modules)

func _collect_cpu_modules() -> Array:
	var modules: Array = []
	for entity in world.entities:
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.get_component(CpuCapabilityComponent) != null:
			modules.append(entity)
	return modules
