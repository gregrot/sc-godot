extends Node2D

func do_click():
	var engine := RobotScriptEngine.new()
	var script_text := "func add(a, b)\n"
	script_text += "\ta + b\n"
	script_text += "end\n"
	script_text += "add(10, 4)\n"

	var result := engine.run(script_text)
	if result.ok:
		print("Final value:", result.result)
		print("Final variables:", result.vars)
	else:
		print("Errors:", "\n".join(result.errors))

func _ready() -> void:
	$Button.connect("button_up", do_click)
