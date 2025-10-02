extends GutTest

const BlockDefinition = preload("res://blocks/BlockDefinition.gd")
const BlockInputDefinition = preload("res://blocks/BlockInputDefinition.gd")
const BlockInstance = preload("res://blocks/BlockInstance.gd")

func _make_definition() -> BlockDefinition:
    var input_a = BlockInputDefinition.new()
    input_a.name = &"value_a"
    input_a.default_value = 42
    input_a.allows_expression = false

    var input_b = BlockInputDefinition.new()
    input_b.name = &"expr_b"
    input_b.allows_expression = true

    var definition = BlockDefinition.new()
    definition.id = &"test_block"
    definition.inputs.clear()
    definition.inputs.append_array([input_a, input_b])
    return definition

func test_create_assigns_defaults_when_not_provided():
    var definition = _make_definition()
    var instance = BlockInstance.create(definition)
    assert_not_null(instance)
    assert_eq(instance.definition_id, definition.id)
    assert_eq(instance.inputs[&"value_a"], 42)
    assert_true(instance.inputs.has(&"expr_b"))
    assert_eq(instance.inputs[&"expr_b"], null)

func test_create_accepts_provided_inputs_and_children():
    var definition = _make_definition()

    var instance = BlockInstance.create(definition, {
        "inputs": {
            &"value_a": 7,
            &"expr_b": 3.14
        },
        "children": {
            &"do": ["child-1", "child-2"]
        }
    })

    assert_eq(instance.inputs[&"value_a"], 7)
    assert_eq(instance.inputs[&"expr_b"], 3.14)
    assert_true(instance.children.has(&"do"))
    assert_eq(instance.children[&"do"], ["child-1", "child-2"])

func test_generate_id_produces_unique_values():
    var ids = {}
    for i in range(10):
        var new_id = BlockInstance.generate_id()
        assert_false(ids.has(new_id))
        ids[new_id] = true
