extends Node2D

func doClick():
	var _engine = RobotScriptEngine.new()
	var script_text = "a=1+1"
	var result := _engine.run(script_text)
	if result.ok:
		print("Final value:", result.result)
		print("Final variables:", result.vars)
	else:
		print("Errors:", "\n".join(result.errors))

func _ready() -> void:
	$Button.connect("button_up", doClick)
