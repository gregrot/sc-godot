extends Entity
class_name MechanismFrame

const CFrameSlots := preload("res://robot/components/c_frame_slots.gd")
const CFrameStatus := preload("res://robot/components/c_frame_status.gd")

func define_components() -> Array:
	return [
		CFrameSlots.new(),
		CFrameStatus.new(),
	]

func on_ready() -> void:
	if name == "":
		name = "MechanismFrame"
