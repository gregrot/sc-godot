extends GutTest

const BlockDefinition = preload("res://blocks/BlockDefinition.gd")
const WorkspaceDocument = preload("res://blocks/WorkspaceDocument.gd")

var _original_definitions: Dictionary = {}

func _make_definition(id: StringName = &"def") -> BlockDefinition:
    var def = BlockDefinition.new()
    def.id = id
    return def

func before_all():
    _original_definitions = BlockRegistry.get_definitions()

func after_all():
    BlockRegistry.clear_definitions()
    for def in _original_definitions.values():
        BlockRegistry.register_definition(def)

func before_each():
    BlockRegistry.clear_definitions()
    BlockRegistry.register_definition(_make_definition(&"test_block"))

func after_each():
    BlockRegistry.clear_definitions()

func test_create_block_adds_instance_and_root():
    var document = WorkspaceDocument.new()
    var instance = document.create_block(&"test_block")
    assert_not_null(instance)
    assert_true(document.root_blocks.has(instance.instance_id))
    assert_true(document.get_blocks().has(instance.instance_id))

func test_remove_block_erases_instance():
    var document = WorkspaceDocument.new()
    var instance = document.create_block(&"test_block")
    document.remove_block(instance.instance_id)
    assert_false(document.get_blocks().has(instance.instance_id))
    assert_false(document.root_blocks.has(instance.instance_id))

func test_serialize_deserialize_roundtrip():
    var document = WorkspaceDocument.new()
    var instance = document.create_block(&"test_block", {"inputs": {&"foo": 1}})
    document.root_blocks.clear()
    document.root_blocks.append(instance.instance_id)

    var dump = document.serialize()

    BlockRegistry.clear_definitions()
    BlockRegistry.register_definition(_make_definition(&"test_block"))

    var restored = WorkspaceDocument.new()
    restored.deserialize(dump)

    assert_eq(restored.name, document.name)
    assert_eq(restored.root_blocks, document.root_blocks)
    assert_true(restored.get_blocks().has(instance.instance_id))
