extends System
class_name RobotCpuSystem

const CpuCapability := preload("res://robot/components/c_cpu_capability.gd")
const CpuProgram := preload("res://robot/components/c_cpu_program.gd")
const ModuleAttachment := preload("res://robot/components/c_module_attachment.gd")
const AttachedToFrame := preload("res://robot/components/c_attached_to_frame.gd")
const ScriptFunctionExport := preload("res://robot/components/c_script_function_export.gd")
const ScriptPropertyExport := preload("res://robot/components/c_script_property_export.gd")
const RobotScriptEngine := preload("res://robot_script/robot_script_engine.gd")

func setup():
	set_q()

func query() -> QueryBuilder:
	set_q()
	return q.with_all([CpuCapability, CpuProgram])

func process(cpu_module: Entity, delta: float) -> void:
	if cpu_module == null:
		return
	var program = cpu_module.get_component(CpuProgram)
	if program == null:
		return
	var script: String = str(program.script_text).strip_edges()
	if script.is_empty():
		return
	var frame_rel: Relationship = cpu_module.get_relationship(Relationship.new(AttachedToFrame.new(), null), true, true)
	if frame_rel == null:
		return
	var frame: Entity = frame_rel.target
	if frame == null or not is_instance_valid(frame):
		return
	var engine: RobotScriptEngine = RobotScriptEngine.new()
	engine.bind("print", Callable(self, "_script_log").bind(cpu_module))
	_bind_exports_from_entity(engine, frame)
	for rel in _get_module_relationships(frame):
		var module: Entity = rel.target
		if module != null:
			_bind_exports_from_entity(engine, module)
	var env := {"delta": delta}
	cpu_module.set_meta("last_program_result", engine.run(script, env))


func _get_module_relationships(frame: Entity) -> Array:
	var relationships: Array = frame.get_relationships(Relationship.new(ModuleAttachment.new(), null), true)
	return [] if relationships == null else relationships

func _bind_exports_from_entity(engine: RobotScriptEngine, entity: Entity) -> void:
	if not entity.has_method("get_component"):
		return
	for component in entity.components.values():
		var script: Script = component.get_script()
		if script == ScriptFunctionExport:
			var callable := Callable(entity, component.method_name)
			if callable.is_null():
				continue
			engine.bind(component.function_name, callable)
		elif script == ScriptPropertyExport:
			var getter := Callable(entity, component.getter_method)
			if getter.is_null():
				continue
			engine.bind(component.property_name, Callable(self, "_invoke_getter").bind(getter))

func _invoke_getter(getter: Callable):
	return getter.call()

func _script_log(cpu_module: Entity, value) -> void:
	var label: Label = cpu_module.get_meta("log_label") as Label
	if label and is_instance_valid(label):
		label.text = str(value)
	else:
		print(value)
