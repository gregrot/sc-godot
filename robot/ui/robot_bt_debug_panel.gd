extends Control

@export var auto_refresh: bool = true

const SCRIPT_CACHE_KEY := "_robot_script_bt_cache"
const STATUS_LABELS := ["SUCCESS", "FAILURE", "RUNNING"]
const COLOR_SUCCESS := Color(0.4, 0.85, 0.4)
const COLOR_FAILURE := Color(0.9, 0.35, 0.35)
const COLOR_RUNNING := Color(0.95, 0.75, 0.3)
const COLOR_UNKNOWN := Color(0.7, 0.7, 0.7)

var cpu_modules: Array = []
var _selected_index: int = -1

@onready var module_select: OptionButton = %ModuleSelect
@onready var tree: Tree = %Tree
@onready var refresh_button: Button = %Refresh

func _ready() -> void:
	module_select.item_selected.connect(_on_module_selected)
	refresh_button.pressed.connect(_update_tree)
	tree.set_column_titles_visible(true)
	tree.set_column_title(0, "Node")
	tree.set_column_title(1, "Status")
	_update_tree()

func _process(_delta: float) -> void:
	if auto_refresh and is_visible_in_tree():
		_update_tree()

func set_cpu_modules(modules: Array) -> void:
	cpu_modules = modules
	module_select.clear()
	for idx in modules.size():
		var module = modules[idx]
		var label = _module_label(module, idx)
		module_select.add_item(label, idx)
	if modules.size() > 0:
		_selected_index = 0
		module_select.select(_selected_index)
	else:
		_selected_index = -1
	_update_tree()

func _module_label(module, idx: int) -> String:
	if module == null:
		return "<null %d>" % idx
	if module.has_method("get_name"):
		return str(module.get_name())
	return "Module %d" % idx

func _on_module_selected(index: int) -> void:
	_selected_index = module_select.get_item_id(index)
	_update_tree()

func _update_tree() -> void:
	tree.clear()
	var item_root = tree.create_item()
	if _selected_index < 0 or _selected_index >= cpu_modules.size():
		item_root.set_text(0, "No CPU modules")
		return
	var module = cpu_modules[_selected_index]
	if module == null:
		item_root.set_text(0, "Invalid module")
		return
	item_root.set_text(0, _module_label(module, _selected_index))
	var cache: Dictionary = module.get_meta(SCRIPT_CACHE_KEY, {}) if module.has_method("get_meta") else {}
	if cache.is_empty():
		var empty_item = tree.create_item(item_root)
		empty_item.set_text(0, "No compiled script")
		return
	var root_node: Node = cache.get("root")
	if root_node != null:
		var bt_root = tree.create_item(item_root)
		bt_root.set_text(0, "Behaviour Tree")
		_append_behaviour_tree(root_node, bt_root)
	var blackboard: Blackboard = cache.get("blackboard")
	if blackboard != null:
		var bb_item = tree.create_item(item_root)
		bb_item.set_text(0, "Blackboard")
		_append_blackboard(blackboard, bb_item)

func _append_behaviour_tree(node: Node, tree_item: TreeItem) -> void:
	var item = tree.create_item(tree_item)
	item.set_text(0, node.name)
	var status = _status_for_node(node)
	item.set_text(1, _status_to_text(status))
	item.set_custom_color(1, _status_to_color(status))
	for child in node.get_children():
		if child is Node:
			_append_behaviour_tree(child, item)

func _status_for_node(node: Node) -> int:
	if node.has_method("get_last_status"):
		return node.get_last_status()
	if node.has_method("get_status"):
		return node.get_status()
	if node.has_method("get_current_status"):
		return node.get_current_status()
	return -1

func _status_to_text(status: int) -> String:
	match status:
		BTBehaviour.BTStatus.SUCCESS:
			return STATUS_LABELS[0]
		BTBehaviour.BTStatus.FAILURE:
			return STATUS_LABELS[1]
		BTBehaviour.BTStatus.RUNNING:
			return STATUS_LABELS[2]
		_:
			return "—"

func _status_to_color(status: int) -> Color:
	match status:
		BTBehaviour.BTStatus.SUCCESS:
			return COLOR_SUCCESS
		BTBehaviour.BTStatus.FAILURE:
			return COLOR_FAILURE
		BTBehaviour.BTStatus.RUNNING:
			return COLOR_RUNNING
		_:
			return COLOR_UNKNOWN

func _append_blackboard(blackboard: Blackboard, tree_item: TreeItem) -> void:
	var data = blackboard.content if blackboard != null else {}
	if data == null:
		data = {}
	for key in data.keys():
		var entry = tree.create_item(tree_item)
		entry.set_text(0, str(key))
		entry.set_text(1, str(data[key]))
