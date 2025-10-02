## Simple vertical palette that lists all registered block definitions.
extends VBoxContainer
class_name BlockPalette

## Emitted when a definition button is clicked.
signal block_definition_selected(definition_id: StringName)

## Placeholder for future search UI toggle.
@export var show_search: bool = false

var _button_group: ButtonGroup

## Builds the palette when the node enters the scene tree.
func _ready() -> void:
	_button_group = ButtonGroup.new()
	BlockRegistry.connect("definitions_refreshed", Callable(self, "_on_definitions_refreshed"))
	_refresh_buttons()

## Ensure connections are released when the palette is freed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if BlockRegistry.definitions_refreshed.is_connected(Callable(self, "_on_definitions_refreshed")):
			BlockRegistry.definitions_refreshed.disconnect(Callable(self, "_on_definitions_refreshed"))

## Rebuilds the palette buttons from the current registry contents.
func _refresh_buttons() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var definitions = BlockRegistry.get_definitions()
	var sorted = definitions.values()
	sorted.sort_custom(Callable(self, "_compare_definitions"))

	for definition in sorted:
		var button = Button.new()
		button.text = definition.label
		button.tooltip_text = definition.summary
		button.button_group = _button_group
		button.pressed.connect(Callable(self, "_on_definition_pressed").bind(definition.id))
		add_child(button)

## Sort callback that orders definitions alphabetically by label.
func _compare_definitions(a, b) -> bool:
	return a.label.nocasecmp_to(b.label) < 0

## Emits the selection signal when a button is pressed.
func _on_definition_pressed(definition_id: StringName) -> void:
	emit_signal("block_definition_selected", definition_id)

## Responds to registry reloads by rebuilding the palette.
func _on_definitions_refreshed() -> void:
	_refresh_buttons()
