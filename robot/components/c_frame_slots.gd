extends Component
class_name C_FrameSlots

const MoveCapability := preload("res://robot/components/c_move_capability.gd")
const CpuCapability := preload("res://robot/components/c_cpu_capability.gd")

@export var slots := {
	"movement": {
		"count": 1,
		"allowed_capabilities": [MoveCapability]
	},
	"cpu": {
		"count": 1,
		"allowed_capabilities": [CpuCapability]
	}
}
