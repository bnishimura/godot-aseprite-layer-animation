# godot-aseprite-layer-animation


## What this does

This script takes an aseprite file and dumps each layer as a its own atlas. Then it creates an AnimatedTexture2D where each animation is a frame tag you define on aseprite.

It was written quickly to get the job done. Ignore reimport_files errors, those don't seem to matter.

## How to use

You only need to download the main.gd.
1. Create a new scene
2. Add a Node
3. Attach main.gd to the Node
4. Fill the "Sprite Path" field by clicking the icon next to it and finding an .aseprite or an .ase file
5. Fill the "Aseprite Executable" field by locating the executable in your PC
6. Fill the frame size
7. Check run


