## Visual wrapper for a block instance, swapping textures based on definition metadata.
extends Control
class_name BaseBlock

const BlockDefinition = preload("res://blocks/BlockDefinition.gd")
const BlockInstance = preload("res://blocks/BlockInstance.gd")

const TEXTURE_PATHS = {
	"default": {
		"leaf": "res://assets/blocks/blue_leaf.png",
		"slot": "res://assets/blocks/blue_slot.png",
	},
	"action": {
		"leaf": "res://assets/blocks/blue_leaf.png",
		"slot": "res://assets/blocks/blue_slot.png",
	},
	"control": {
		"leaf": "res://assets/blocks/purple_leaf.png",
		"slot": "res://assets/blocks/purple_slot.png",
	},
	"value": {
		"leaf": "res://assets/blocks/green_leaf.png",
		"slot": "res://assets/blocks/green_slot.png",
	},
}

const CATEGORY_MODULATE = {
	"event": Color(1, 0.95, 0.75),
	"action": Color(1, 1, 1),
	"control": Color(1, 1, 1),
	"value": Color(1, 1, 1),
	"operator": Color(0.9, 0.95, 1.0),
}

var _definition
var _instance
var _texture_cache = {}
var _pending_instance_resolve = false

var _background: NinePatchRect
var _title_label: Label
var _summary_label: Label
var _slot_container: VBoxContainer

## Optional definition resource to bind the block to.
@export var block_definition: Resource:
	get:
		return _definition
	set(value):
		_set_definition(value)

## Block instance displayed by the control.
@export var block_instance: Variant:
	get:
		return _instance
	set(value):
		_set_instance(value)

## Initialises cached node references and resolves any pending data binding.
func _ready() -> void:
	_cache_node_references()

	if _definition != null:
		_apply_definition_visuals(_definition)
	elif _instance != null and is_inside_tree():
		_resolve_definition_from_instance()
	else:
		_apply_texture("default", _determine_layout(null))

	if _pending_instance_resolve and _instance != null and _definition == null:
		_pending_instance_resolve = false
		_resolve_definition_from_instance()

## Lazy fetcher for child nodes so the control works both in scenes and at runtime.
func _cache_node_references() -> void:
	if _background == null:
		_background = get_node_or_null("Background")
	if _title_label == null:
		_title_label = get_node_or_null("Background/MarginContainer/VBoxContainer/TitleLabel")
	if _summary_label == null:
		_summary_label = get_node_or_null("Background/MarginContainer/VBoxContainer/SummaryLabel")
	if _slot_container == null:
		_slot_container = get_node_or_null("Background/MarginContainer/VBoxContainer/SlotContainer")

## Applies a definition supplied directly from the editor or caller.
func _set_definition(value) -> void:
	if value != null and not (value is BlockDefinition):
		push_warning("BaseBlock: block_definition must be a BlockDefinition resource")
		return
	_definition = value
	if not is_inside_tree():
		return
	_cache_node_references()
	_apply_definition_visuals(_definition)

## Accepts a runtime block instance and updates visuals accordingly.
func _set_instance(value) -> void:
	if value != null and not (value is BlockInstance):
		push_warning("BaseBlock: block_instance must be a BlockInstance object")
		return
	_instance = value
	if _definition == null and _instance != null:
		if is_inside_tree():
			_resolve_definition_from_instance()
		else:
			_pending_instance_resolve = true
	if is_inside_tree():
		_refresh_instance_content()

## Looks up the definition referenced by the instance using the BlockRegistry autoload.
func _resolve_definition_from_instance() -> void:
	if _instance == null:
		return
	if not is_inside_tree():
		_pending_instance_resolve = true
		return

	var registry = null
	if Engine.has_singleton("BlockRegistry"):
		registry = Engine.get_singleton("BlockRegistry")
	else:
		var tree = get_tree()
		if tree:
			var root = tree.get_root()
			if root:
				registry = root.get_node_or_null("BlockRegistry")

	if registry == null:
		push_warning("BaseBlock: BlockRegistry autoload not found")
		return

	var definition = registry.get_definition(_instance.definition_id)
	_definition = definition
	_cache_node_references()
	_apply_definition_visuals(_definition)

## Pushes definition metadata into UI nodes and swaps the background texture.
func _apply_definition_visuals(definition) -> void:
	_cache_node_references()
	if _title_label == null or _background == null:
		return

	if definition == null:
		_title_label.text = "Block"
		if _summary_label:
			_summary_label.visible = false
		_apply_texture("default", _determine_layout(null))
		return

	var label_text = definition.label if definition.label != "" else str(definition.id)
	_title_label.text = label_text

	var show_summary = definition.summary.strip_edges() != ""
	if _summary_label:
		_summary_label.visible = show_summary
		if show_summary:
			_summary_label.text = definition.summary

	var category = str(definition.category)
	var layout = _determine_layout(definition)
	_apply_texture(category, layout)

## Applies the appropriate texture/modulate combination for the block.
func _apply_texture(category: String, layout: String) -> void:
	if _background == null:
		return
	var texture = _get_texture_for(category, layout)
	if texture != null:
		_background.texture = texture

	var modulate_color = CATEGORY_MODULATE.get(category, Color(1, 1, 1))
	_background.modulate = modulate_color

## Infers whether the block is a leaf or container based on child slot count.
func _determine_layout(definition) -> String:
	if definition == null:
		return "leaf"
	if definition.child_slots.size() > 0:
		return "slot"
	return "leaf"

## Populates the slot container with input and child-slot placeholders.
func _refresh_instance_content() -> void:
	_cache_node_references()
	if _slot_container == null:
		return
	for child in _slot_container.get_children():
		_slot_container.remove_child(child)
		child.queue_free()
	if _definition == null:
		return
	if _definition.inputs.size() > 0:
		_slot_container.add_child(_build_inputs_section())
	if _definition.child_slots.size() > 0:
		for slot_def in _definition.child_slots:
			_slot_container.add_child(_build_child_slot_section(slot_def))

func _build_inputs_section() -> PanelContainer:
	var panel = _create_panel(Color(1, 1, 1, 0.12))
	var content = VBoxContainer.new()
	content.name = "Inputs"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(content)

	var title = _create_section_title("Inputs")
	content.add_child(title)

	for input_def in _definition.inputs:
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 8)

		var name_label = Label.new()
		name_label.text = str(input_def.name)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND
		row.add_child(name_label)

		var value_label = Label.new()
		value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var value = null
		if _instance != null and _instance.inputs.has(input_def.name):
			value = _instance.inputs[input_def.name]
		else:
			value = input_def.default_value

		if input_def.allows_expression and (value == null or value == ""):
			value_label.text = "(expression)"
			value_label.modulate = Color(0.5, 0.5, 0.5)
		else:
			value_label.text = _stringify_value(value)
		row.add_child(value_label)

		content.add_child(row)

	return panel

func _build_child_slot_section(slot_def) -> PanelContainer:
	var panel = _create_panel(Color(1, 1, 1, 0.08))
	var content = VBoxContainer.new()
	content.name = str(slot_def.name)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(content)

	var header = _create_section_title("Slot: %s" % str(slot_def.name))
	content.add_child(header)

	var child_list = []
	if _instance != null and _instance.children.has(slot_def.name):
		var raw_children = _instance.children[slot_def.name]
		if typeof(raw_children) == TYPE_ARRAY:
			child_list = raw_children
		else:
			child_list = [raw_children]

	if child_list.size() == 0:
		var placeholder = Label.new()
		placeholder.text = "(empty)"
		placeholder.modulate = Color(0.6, 0.6, 0.6)
		content.add_child(placeholder)
	else:
		for child_id in child_list:
			var child_row = HBoxContainer.new()
			child_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var bullet = Label.new()
			bullet.text = "•"
			child_row.add_child(bullet)

			var child_label = Label.new()
			child_label.text = str(child_id)
			child_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			child_row.add_child(child_label)

			content.add_child(child_row)

	return panel

func _create_panel(color: Color) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.add_theme_constant_override("margin_left", 8)
	panel.add_theme_constant_override("margin_right", 8)
	panel.add_theme_constant_override("margin_top", 4)
	panel.add_theme_constant_override("margin_bottom", 4)
	return panel

func _create_section_title(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	label.add_theme_font_size_override("font_size", 12)
	return label

func _stringify_value(value) -> String:
	if value == null:
		return "(empty)"
	var t = typeof(value)
	match t:
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_ARRAY, TYPE_DICTIONARY:
			return JSON.stringify(value)
		TYPE_OBJECT:
			if value is BlockInstance and value.instance_id != "":
				return "Block %s" % value.instance_id
			return str(value)
		TYPE_STRING_NAME, TYPE_STRING:
			return String(value)
		TYPE_FLOAT, TYPE_INT:
			return String(value)
		_:
			return str(value)

## Loads and caches textures for the supplied category/layout combination.
func _get_texture_for(category: String, layout: String):
	var dictionary: Dictionary = TEXTURE_PATHS.get(category, TEXTURE_PATHS["default"])
	var path = dictionary.get(layout, dictionary.get("leaf", ""))
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	var texture = load(path)
	if texture != null:
		_texture_cache[path] = texture
	return texture
