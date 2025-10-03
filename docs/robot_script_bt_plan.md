# RobotScript AST → Behaviour Toolkit Mapping

## Overview
RobotScript programs now compile into Behaviour Toolkit (BT) trees. Compilation happens once per CPU module:
1. Parse the script into the existing AST.
2. `RobotScriptBtBuilder` turns the AST into a populated `BTRoot` scene graph.
3. The CPU system stores the `BTRoot` on the module, updates its blackboard each frame, and ticks the tree.

BT nodes must be deterministic and side-effect free beyond interacting with the agreed blackboard namespace. Every RobotScript behaviour node inherits from `RobotScriptLeaf` or `RobotScriptComposite` in `res://robot_script/behaviour_nodes/`.

## AST → BT node catalogue
- **NODE_PROGRAM** → `BTRoot` with a single `RobotScriptProgram` (composite). Children mirror the statement list order.
- **NODE_ASSIGN** → `RobotScriptAssignLeaf`. Evaluates the RHS expression and writes the result into the environment stored on the blackboard.
- **NODE_EXPR_STMT** → `RobotScriptExpressionLeaf`. Evaluates the expression for side effects and writes the value into `robot_script/last_result`.
- **NODE_FUNCTION** → `RobotScriptFunctionDefLeaf`. On first tick it registers the function definition (closure + body) in the runtime environment; subsequent ticks skip work. Function bodies run through `RobotScriptRuntime` when call expressions execute.
- **NODE_BINARY / NODE_UNARY / NODE_LITERAL / NODE_VAR / NODE_CALL** – Expressions do not become separate BT nodes. Expression AST is evaluated by the owning leaf via `RobotScriptRuntime.eval_expr()` so evaluation errors surface on the leaf that triggered them.

Future control flow nodes reserve the following shapes:
- **NODE_IF** (when added) → `RobotScriptIfComposite` with `condition`, `then_branch`, and optional `else_branch` child slots.
- **NODE_WHILE / NODE_LOOP** → `RobotScriptLoopComposite` maintaining loop state inside `robot_script/loop_state`.

## Blackboard contract
All RobotScript behaviours read/write under the `robot_script` namespace using `StringName` keys:
- `robot_script/runtime` → `RobotScriptRuntime` instance shared by the tree.
- `robot_script/env` → Current environment dictionary (always kept in sync with the runtime).
- `robot_script/frame` → Owning frame entity (set by the CPU system at compile time).
- `robot_script/modules` → Dictionary of attached module entities keyed by slot name.
- `robot_script/delta` → Seconds since the previous tick (updated before each tree tick).
- `robot_script/last_result` → Result of the most recent expression statement or assignment.
- `robot_script/errors` → PackedStringArray of runtime errors gathered during the last tick (cleared before execution).

Leaves fetch the runtime from `robot_script/runtime` and MUST early-return `BTStatus.FAILURE` if it is missing. Successful leaves synchronise their local environment mutations back to `robot_script/env` and update `robot_script/last_result` when they produce a value.

## Execution lifecycle
- `RobotScriptBtBuilder.compile(ast, options)` returns `{ root: BTRoot, runtime: RobotScriptRuntime }`.
- The CPU system installs the returned `BTRoot` under an internal parent node, assigns the module entity as `actor`, and injects/updates the blackboard each frame.
- Before ticking, the CPU system clears `robot_script/errors`, sets `robot_script/delta`, and copies frame/module references into the blackboard.
- After ticking, any errors collected on the runtime propagate through `robot_script/errors`. The CPU module can surface them through its existing logging UI.

## Consistency rules
- Behaviour nodes never mutate the Godot scene tree; all module interactions go through callables bound in the runtime environment.
- New AST features must register their BT counterpart in this catalogue and provide a dedicated behaviour node under `robot_script/behaviour_nodes/`.
- Blackboard keys are authoritative; do not stash per-node state elsewhere unless it is transient and purely internal.
- Tests must cover both structural conversion (builder outputs expected node types) and runtime effects (tick manipulates the blackboard as expected).
