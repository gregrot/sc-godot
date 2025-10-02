# Repository Guidelines

## Project Structure & Module Organization
- **blocks/**: Resource scripts defining block metadata (`BlockDefinition.gd`), runtime instances, and workspace documents.
- **ui/**: Editor UI scripts and scenes; `ui/blocks/BaseBlock.*` renders block visuals, while palette/workspace controllers live alongside.
- **addons/gut/**: Godot Unit Test (GUT) plugin bundled in-tree.
- **test/unit/**: GUT test suites covering core logic (`test_block_instance.gd`, `test_workspace_document.gd`).
- **assets/**: Imported block textures organised per category (e.g., `assets/blocks/blue_slot.png`).
- **gut_cmd.sh**: Helper script to run automated tests headlessly.

## Build, Test, and Development Commands
- `./.bin/Godot_v4.5-stable_linux.x86_64 --path .`: Launches the editor/player with the current project.
- `./.bin/Godot_v4.5-stable_linux.x86_64 --headless --path . --quit`: Smoke-checks project scripts for parse errors.
- `./gut_cmd.sh`: Executes the GUT suite under `test/unit/` and exits with test status.

## Coding Style & Naming Conventions
- Use tabs for indentation in GDScript (matches existing files).
- Prefer lowercase snake_case for variables/functions, PascalCase for classes/resources (`BlockDefinition`), kebab-case for filenames when not dictated by Godot (`BaseBlock.tscn`).
- Keep exported arrays initialised with `.clear()`/`.append_array()` when working with typed Godot arrays inside tests to avoid type mismatches.
- Document public APIs with `##` comments as seen in `blocks/*.gd`.

## Testing Guidelines
- Framework: GUT (addons/gut). Tests extend `GutTest` and live under `res://test/unit/`.
- Name tests `test_<behavior>()` and mirror source structure (`test_workspace_document.gd`).
- Run locally via `./gut_cmd.sh`; CI should invoke the same entry point.
- If registry state is required, use `BlockRegistry.clear_definitions()` and `BlockRegistry.register_definition()` to isolate fixtures.

## Commit & Pull Request Guidelines
- Follow conventional, action-oriented commit subjects (e.g., `Add BaseBlock visuals`, `Fix workspace serialization tests`).
- Provide concise body lines detailing motivation when changes affect multiple subsystems.
- Pull requests should include: summary of changes, testing evidence (`./gut_cmd.sh` output), and screenshots/GIFs when UI is affected.
- Link tracking issues using `Fixes #ID` or `References #ID` in the PR description when applicable.
