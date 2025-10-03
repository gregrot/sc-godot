extends System
class_name RobotCpuSystem

const CpuCapability := preload("res://robot/components/c_cpu_capability.gd")
const CpuProgram := preload("res://robot/components/c_cpu_program.gd")
const ModuleAttachment := preload("res://robot/components/c_module_attachment.gd")
const AttachedToFrame := preload("res://robot/components/c_attached_to_frame.gd")
const ScriptFunctionExport := preload("res://robot/components/c_script_function_export.gd")
const ScriptPropertyExport := preload("res://robot/components/c_script_property_export.gd")
const RobotScriptEngine := preload("res://robot_script/robot_script_engine.gd")
const RobotScriptBtBuilder = preload("res://robot_script/robot_script_bt_builder.gd")
const RobotScriptRuntime = preload("res://robot_script/robot_script_runtime.gd")

const SCRIPT_CACHE_KEY := "_robot_script_bt_cache"
const BB_KEY_DELTA := StringName("robot_script/delta")
const BB_KEY_FRAME := StringName("robot_script/frame")
const BB_KEY_MODULES := StringName("robot_script/modules")
const BB_KEY_LAST_RESULT := StringName("robot_script/last_result")
const BB_KEY_ENV := StringName("robot_script/env")

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
		cpu_module.set_meta(SCRIPT_CACHE_KEY, {})
		return
	var frame_rel: Relationship = cpu_module.get_relationship(Relationship.new(AttachedToFrame.new(), null), true, true)
	if frame_rel == null:
		return
	var frame: Entity = frame_rel.target
	if frame == null or not is_instance_valid(frame):
		return
	var exports := _collect_exports(frame)
	var signature := _build_export_signature(exports)
	var cache: Dictionary = cpu_module.get_meta(SCRIPT_CACHE_KEY, {})
	var needs_rebuild: bool = cache.is_empty() or cache.get("script", "") != script or cache.get("signature") != signature
	if needs_rebuild:
		cache = _rebuild_cache(cpu_module, script, exports, signature)
		if cache.is_empty():
			cpu_module.set_meta(SCRIPT_CACHE_KEY, {})
			return
		cpu_module.set_meta(SCRIPT_CACHE_KEY, cache)
	_update_blackboard(cache, delta, frame)
	var program_node: Node = cache.get("program")
	var blackboard = cache.get("blackboard")
	var runtime: RobotScriptRuntime = cache.get("runtime")
	if program_node == null or blackboard == null or runtime == null:
		return
	var status: int = program_node.tick(delta, null, blackboard)
	var result_value: Variant = blackboard.get_value(BB_KEY_LAST_RESULT)
	var response := {
		"ok": not runtime.has_errors(),
		"result": result_value,
		"vars": runtime.snapshot_environment(),
		"status": status
	}
	if runtime.has_errors():
		response["errors"] = runtime.get_errors()
	cpu_module.set_meta("last_program_result", response)


func _get_module_relationships(frame: Entity) -> Array:
	var relationships: Array = frame.get_relationships(Relationship.new(ModuleAttachment.new(), null), true)
	return [] if relationships == null else relationships


func _collect_exports(frame: Entity) -> Array:
	var exports: Array = []
	_collect_exports_from_entity(exports, frame)
	for rel in _get_module_relationships(frame):
		var module: Entity = rel.target
		if module != null:
			_collect_exports_from_entity(exports, module)
	return exports

func _collect_exports_from_entity(exports: Array, entity: Entity) -> void:
	if not entity.has_method("get_component"):
		return
	for component in entity.components.values():
		var script: Script = component.get_script()
		if script == ScriptFunctionExport:
			var callable := Callable(entity, component.method_name)
			if callable.is_null():
				continue
			exports.append({
				"kind": "function",
				"name": component.function_name,
				"callable": callable
			})
		elif script == ScriptPropertyExport:
			var getter := Callable(entity, component.getter_method)
			if getter.is_null():
				continue
			exports.append({
				"kind": "property",
				"name": component.property_name,
				"getter": getter
			})

func _build_export_signature(exports: Array) -> PackedStringArray:
	var entries: PackedStringArray = PackedStringArray()
	for entry in exports:
		var name: String = entry.get("name", "")
		if entry.get("kind") == "function":
			var callable: Callable = entry.get("callable")
			if callable == null:
				continue
			entries.append("%s#func@%d:%s" % [name, callable.get_object().get_instance_id(), callable.get_method()])
		else:
			var getter: Callable = entry.get("getter")
			if getter == null:
				continue
			entries.append("%s#prop@%d:%s" % [name, getter.get_object().get_instance_id(), getter.get_method()])
	entries.sort()
	return entries

func _rebuild_cache(cpu_module: Entity, script: String, exports: Array, signature: PackedStringArray) -> Dictionary:
	var engine: RobotScriptEngine = RobotScriptEngine.new()
	engine.bind("print", Callable(self, "_script_log").bind(cpu_module))
	for entry in exports:
		var name: String = entry.get("name")
		if entry.get("kind") == "function":
			engine.bind(name, entry.get("callable"))
		else:
			engine.bind(name, Callable(self, "_invoke_getter").bind(entry.get("getter")))
	var compile_result := engine.compile(script)
	if not compile_result.get("ok", false):
		cpu_module.set_meta("last_program_result", compile_result)
		return {}
	var build_result := RobotScriptBtBuilder.build(engine, compile_result.get("ast", {}))
	var root: BTRoot = build_result.get("root")
	var program_node: Node = null
	if root != null and root.get_child_count() > 0:
		program_node = root.get_child(0)
	return {
		"script": script,
		"signature": signature,
		"runtime": build_result.get("runtime"),
		"root": root,
		"program": program_node,
		"blackboard": build_result.get("blackboard")
	}

func _update_blackboard(cache: Dictionary, delta: float, frame: Entity) -> void:
	var blackboard: Blackboard = cache.get("blackboard")
	if blackboard == null:
		return
	var runtime: RobotScriptRuntime = cache.get("runtime")
	if runtime != null:
		var env: Dictionary = runtime.get_environment()
		env["delta"] = delta
		blackboard.set_value(BB_KEY_ENV, env)
	blackboard.set_value(BB_KEY_DELTA, delta)
	blackboard.set_value(BB_KEY_FRAME, frame)
	blackboard.set_value(BB_KEY_MODULES, _build_module_table(frame))

func _invoke_getter(getter: Callable):
	return getter.call()

func _build_module_table(frame: Entity) -> Dictionary:
	var modules: Dictionary = {}
	for rel in _get_module_relationships(frame):
		var module: Entity = rel.target
		if module == null:
			continue
		var slot: String = ""
		if rel.relation is ModuleAttachment:
			slot = rel.relation.slot_name
		var key := slot if not slot.is_empty() else str(module.get_instance_id())
		modules[key] = module
	return modules

func _script_log(cpu_module: Entity, value) -> void:
	var label: Label = cpu_module.get_meta("log_label") as Label
	if label and is_instance_valid(label):
		label.text = str(value)
	else:
		print(value)
