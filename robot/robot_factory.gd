extends RefCounted
class_name RobotFactory

const MechanismFrame := preload("res://robot/entities/frame.gd")
const MovementModule := preload("res://robot/entities/modules/movement_module.gd")
const CFrameSlots := preload("res://robot/components/c_frame_slots.gd")
const CModuleAttachment := preload("res://robot/components/c_module_attachment.gd")
const CAttachedToFrame := preload("res://robot/components/c_attached_to_frame.gd")
const CMoveCapability := preload("res://robot/components/c_move_capability.gd")

func build_basic_robot(world: World, movement_speed: float = 4.0) -> MechanismFrame:
	assert(world != null, "World is required to build a robot")
	var frame := MechanismFrame.new()
	frame.name = "MechanismFrame_%d" % world.entities.size()
	world.add_entity(frame)

	var module := MovementModule.new()
	module.speed = movement_speed
	module.name = "MovementModule_%s" % frame.name
	world.add_entity(module)

	_attach_module_to_frame(frame, module, "movement")
	return frame

func _attach_module_to_frame(frame: MechanismFrame, module: MovementModule, slot_name: String) -> void:
	var slots: C_FrameSlots = frame.get_component(CFrameSlots)
	assert(slots != null, "Frame missing slots component")
	var slot_config = slots.slots.get(slot_name, null)
	assert(slot_config != null, "Unknown slot '%s' on frame" % slot_name)

	var allowed_caps: Array = slot_config.get("allowed_capabilities", [])
	var module_capability: C_MoveCapability = module.get_component(CMoveCapability)
	var capability_script: Script = module_capability.get_script()
	assert(
		allowed_caps.has(capability_script),
		"Module capability is not allowed in '%s'" % slot_name
	)

	var attachments := frame.get_relationships(Relationship.new(CModuleAttachment.new(slot_name), null))
	attachments = [] if attachments == null else attachments
	var occupied: int = attachments.size()
	var capacity: int = int(slot_config.get("count", 0))
	assert(occupied < capacity, "Slot '%s' is already full" % slot_name)

	frame.add_relationship(Relationship.new(CModuleAttachment.new(slot_name), module))
	module.add_relationship(Relationship.new(CAttachedToFrame.new(slot_name), frame))
