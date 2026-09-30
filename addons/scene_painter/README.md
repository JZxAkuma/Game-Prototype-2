# Scene Painter

Scene Painter is a Godot 4 editor plugin for painting collections of
`PackedScene` assets directly into the 3D viewport.

## Features

- Paint randomly from any combination of enabled scenes.
- Organise scene collections into persistent libraries.
- Drag `.tscn` files directly into a library.
- Preview scenes as thumbnail tiles.
- Enable or disable individual scenes with a tick box.
- Remove a scene from a library by right-clicking its tile.
- Control brush radius, density and minimum spacing.
- Randomise Y rotation and scale.
- Align instances to the painted surface.
- Restrict painting by maximum surface slope.
- Apply height offsets along World Y or the surface normal.
- Paint beneath a selected `Node3D` or use the default container.
- Erase painted instances in the 3D viewport.
- Undo and redo painting and erasing.
- Detach Scene Painter into a resizable floating window.

## Installation

1. Copy the `addons/scene_painter` folder into your Godot project.
2. Open **Project > Project Settings > Plugins**.
3. Enable `Scene Painter`.

Scene Painter appears in the editor's bottom dock.

## Basic use

1. Create a library with the `+` button or use the default library.
2. Drag one or more `.tscn` scenes from the FileSystem dock into the asset area.
3. Tick every scene that may be selected during random painting.
4. Configure the brush options.
5. Enable the brush and paint in the 3D viewport.

Use the library tabs to switch collections. Library files are stored in
`user://.scene_painter_libraries` and are not added to the Godot project.

## Compatibility

- Godot 4
- 3D projects only
- Tested during development with Godot 4.8 dev2

## License

Scene Painter is released under the MIT License. See [LICENSE](LICENSE).
