# Modular Frames with GECS

> **Design attachable gameplay modules with clean ECS separation**

This guide shows how to build a "frame + modules" mechanic—such as a robot or vehicle chassis that gains movement, inventory, or utility features from attachable modules—using [GECS](addons/gecs/README.md). The pattern keeps modules decoupled, lets systems reason about capabilities, and allows designers to swap modules without rewriting logic.

## 🧩 High-level structure

| Concept | GECS building block | Notes |
| --- | --- | --- |
| **Frame** | `Entity` scene that represents the base object | Holds slot definitions and exposes shared state (e.g., power, hit points). |
| **Module** | Reusable `Entity` scene | Provides one or more capability components (movement, inventory, weapons, etc.). |
| **Attachment** | `Relationship` between a frame entity and a module entity | Tracks which modules are mounted, which slot they occupy, and optional metadata. |
| **Capability logic** | `System` classes | Query for modules by their capability components and update state each frame. |

Frames never call module logic directly. Systems discover the module components they care about, pull any data they need from the frame through relationships, and then apply behavior. This keeps runtime wiring declarative instead of relying on hand-written script references.

## 🏗️ Defining the frame

Create a dedicated frame entity with slot data extracted into components. The component acts as the single source of truth for which slots exist and their constraints.

```gdscript
# components/c_frame_slots.gd
class_name C_FrameSlots
extends Component

@export var slots := {
    "engine": {
        "count": 1,
        "allowed_capabilities": [C_MoveCapability]
    },
    "hardpoint": {
        "count": 2,
        "allowed_capabilities": [C_WeaponCapability, C_UtilityCapability]
    }
}
```

```gdscript
# entities/e_frame.gd
class_name Frame
extends Entity

func define_components() -> Array:
    return [
        C_FrameSlots.new(),
        C_FrameStatus.new(), # power, health, etc.
    ]
```

The frame does **not** keep references to attached module nodes. Instead, modules will attach themselves through relationships (next section).

## 🧱 Building module entities

Each module is an entity scene that emits capability components describing what it offers. A single module can provide multiple capabilities by returning multiple components from `define_components()`.

```gdscript
# entities/modules/e_thruster_module.gd
class_name ThrusterModule
extends Entity

func define_components() -> Array:
    return [
        C_ModuleMount.new("engine"),
        C_MoveCapability.new({
            "thrust": 20.0,
            "turn_speed": 4.5,
        }),
        C_PowerConsumer.new(2.0),
    ]
```

Designers can author additional module scenes (weapons, cargo pods, life-support) that follow the same pattern.

## 🔗 Attaching modules with relationships

Use GECS relationships to connect module entities to their owning frame:

```gdscript
# During gameplay (e.g., a builder system)
var frame: Frame = spawn_frame()
var thruster: ThrusterModule = spawn_thruster()

frame.add_relationship(Relationship.new(C_ModuleAttachment.new(), thruster))
thruster.add_relationship(Relationship.new(C_AttachedToFrame.new(), frame))
```

Recommended relationship data components:

- `C_ModuleAttachment` – stored on the frame; includes slot name, install time, durability modifiers, etc.
- `C_AttachedToFrame` – stored on the module; caches the slot it occupies for quick lookup and links back to the frame.

When a module is removed, remove both relationships. Systems can watch for these changes by observing relationship signals or by responding to entity lifecycle callbacks.

## ⚙️ Driving behavior through systems

Each gameplay concern runs in its own system. Systems query the world for the module capabilities they understand and optionally the frame state via reverse relationship queries.

```gdscript
# systems/s_movement.gd
class_name S_Movement
extends System

func _process(_delta: float) -> void:
    ECS.world.query
        .with_component(C_MoveCapability)
        .for_each(func(module: Entity):
            var move_capability := module.get_component(C_MoveCapability)
            var frame_rel := module.get_relationship(Relationship.new(C_AttachedToFrame.new()))
            if frame_rel == null:
                return

            var frame := frame_rel.target as Frame
            var frame_status := frame.get_component(C_FrameStatus)
            if frame_status.power <= 0.0:
                return

            apply_thrust(frame, move_capability)
        )
```

Advantages of this approach:

- **Systems stay focused** – movement logic only depends on `C_MoveCapability` and optional shared frame data, not on specific module classes.
- **Hot-swapping works** – adding/removing modules automatically adjusts which entities show up in queries.
- **Capabilities can stack** – a frame with multiple thrusters will be processed multiple times, letting you aggregate thrust or handle fallback logic.

## 🧪 Handling composite behaviors

Some features need to look at the frame and all modules simultaneously (e.g., computing total cargo space). Use GECS's powerful query builder to group data:

```gdscript
var frame_modules := ECS.world.query
    .with_component(C_FrameSlots)
    .with_relationship([Relationship.new(C_ModuleAttachment.new(), ECS.wildcard)])
    .group_by(func(frame: Frame):
        return frame
    )

for frame in frame_modules.keys():
    var modules := frame_modules[frame]
    var total_capacity := modules
        .filter(func(module): return module.has_component(C_InventoryCapability))
        .map(func(module): return module.get_component(C_InventoryCapability).capacity)
        .reduce(0, func(total, cap): return total + cap)
    update_frame_inventory(frame, total_capacity)
```

Grouping keeps aggregation logic localized and avoids state duplication on the frame.

## 🧰 Additional tips

- **Author module prefabs** – Save modules as scenes with visual meshes and `Entity` roots so designers can drag them into the editor while keeping ECS data clean.
- **Validate slots in a builder system** – When a module is attached, ensure the target frame has room and the capability is allowed for the slot. Emit errors or automatically detach invalid modules.
- **Leverage observers** – Observers can listen for modules being attached/detached and trigger audio/FX or UI updates without bloating gameplay systems.
- **Persist module loadouts** – Serialize the frame entity, the relationship data, and the module entity resources. Restoring from save becomes re-instantiating entities and re-creating relationships.

This architecture keeps modules reusable, separates concerns, and fully leverages GECS's relationship-driven design for modular gameplay mechanics.
