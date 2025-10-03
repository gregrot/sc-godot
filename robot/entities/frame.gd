extends Entity
class_name MechanismFrame

const CFrameSlots := preload("res://robot/components/c_frame_slots.gd")
const CFrameStatus := preload("res://robot/components/c_frame_status.gd")

var _visual_root: Node2D

func define_components() -> Array:
	return [
		CFrameSlots.new(),
		CFrameStatus.new(),
	]

func on_ready() -> void:
	if name == "":
		name = "MechanismFrame"
	_ensure_visual_root()
	var status: C_FrameStatus = get_component(CFrameStatus)
	if status:
		update_visual(status.position)

func _ensure_visual_root() -> void:
	if _visual_root and is_instance_valid(_visual_root):
		return
	_visual_root = get_node_or_null("Visual")
	if _visual_root == null:
		_visual_root = Node2D.new()
		_visual_root.name = "Visual"
		add_child(_visual_root)
		var body := Polygon2D.new()
		body.name = "Body"
		body.polygon = PackedVector2Array([
			Vector2(-16, -12),
			Vector2(16, 0),
			Vector2(-16, 12)
		])
		body.color = Color.hex(0x4fd5ffff)
		_visual_root.add_child(body)

func update_visual(position: Vector2) -> void:
	_ensure_visual_root()
	_visual_root.position = position
