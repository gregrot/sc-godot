extends System
class_name MovementSystem

const MoveCapability := preload("res://robot/components/c_move_capability.gd")
const AttachedToFrame := preload("res://robot/components/c_attached_to_frame.gd")
const FrameStatus := preload("res://robot/components/c_frame_status.gd")

func setup():
	set_q()

func query() -> QueryBuilder:
	set_q()
	return q.with_all([MoveCapability])

func process(module: Entity, delta: float) -> void:
	if module == null:
		return
	var move_capability: C_MoveCapability = module.get_component(MoveCapability)
	if move_capability == null:
		return
	var relation: Relationship = module.get_relationship(Relationship.new(AttachedToFrame.new(), null), true, true)
	if relation == null:
		return
	var frame: Entity = relation.target
	if frame == null or not is_instance_valid(frame):
		return
	var status: C_FrameStatus = frame.get_component(FrameStatus)
	if status == null:
		return
	status.position += Vector2.RIGHT * move_capability.speed * delta
	if frame.has_method("update_visual"):
		frame.update_visual(status.position)
	frame.set_meta("position", status.position)
