# Agent Notes for Godot 4.5

When editing GDScript in this project keep the following rules in mind. The project treats warnings as hard errors, so violating any of these will make the editor refuse to load scripts.

## Variable declarations
- Prefer `var name = expression` or an explicit type (`var name: Variant = expression`). Avoid `:=` when the expression evaluates to a Variant because Godot 4.5 warns that it "will be typed as Variant"; that warning is promoted to an error here.
- When you need type inference (`:=`), only use it when the expression has a concrete type (numbers, strings, arrays with literals, etc.). If the expression already returns Variant (for example, most BehaviourToolkit API calls), use `=` or declare the type explicitly.

## Loops and blocks
- Godot requires a properly indented block after flow statements. Ensure each `for`/`if` branch has the corresponding indented body; accidental dedent (even a single tab) will surface as “Expected indented block” parse errors.

## Debug panel scripts
- Trees returned by Behaviour Toolkit often expose dynamic children; when iterating them, declare helper temporaries with `var x = ...` instead of `:=` for the same reasons above.
- Blackboard dictionaries may be `null`; guard and normalise them (`var data = ...` then `if data == null: data = {}`) before iterating.

## Runtime scripts
- Expressions such as `runtime.execute_statement(...)` and `runtime.evaluate_expression(...)` both return Variant. Assign their result with `var result = ...` or `var result: Variant = ...` to avoid inference warnings.

Keeping to these patterns avoids the parse errors we recently hit while integrating the RobotScript behaviour tree pipeline.
