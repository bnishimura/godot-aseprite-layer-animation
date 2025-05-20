@tool
extends Node


@export_file("*.aseprite;*.ase") var sprite_path: String
@export var aseprite_executable: String = 'aseprite'
@export var frame_size: Vector2i = Vector2i(128, 128)

@export var run: bool = false : set = process_aseprite_file

func process_aseprite_file(_flag):
	
	if !sprite_path:
		push_error("ERROR: NO ASEPRITE FILE SELECTED")
		return

	var fpath = ProjectSettings.globalize_path(sprite_path)
	var out_splits = Array(fpath.split('/'))
	# chop .aseprite
	var MAIN_NAME : String = out_splits.pop_back().split('.')[0]

# aseprite -b test.aseprite --layer "test_layer" --sheet test_layer.png --data test_layer.json
	var sprite_fetch_args = PackedStringArray([
		"-b",
		"--layer",
		null, # name of the layer
		fpath,
		"--sheet",
		null, # path of output file
	])
	var LAYER_NAME_IDX := 2
	var OUTFILE_IDX := 5

	var MAIN_JSON_FNAME = 'anim.json'
	out_splits.append(MAIN_JSON_FNAME)
	var anim_json_path = '/'.join(out_splits)

	var layers : PackedStringArray = get_layer_names()
	dump_animation_data(anim_json_path)
	var anim_data : Dictionary = load_animation_json(anim_json_path)

	var cli_output := []
	var outpath : String

	var editor_fs = EditorInterface.get_resource_filesystem()

# collisions will be missing here.
	for layer_name in layers:
		out_splits[-1] = layer_name
		outpath = '/'.join(out_splits)

		sprite_fetch_args[LAYER_NAME_IDX] = layer_name
		sprite_fetch_args[OUTFILE_IDX] = outpath + "/%s.png" % layer_name

		print(' '.join(sprite_fetch_args))

		cli_output = []
		var _fail = OS.execute(
			aseprite_executable,
			sprite_fetch_args,
			cli_output
		)

		if _fail:
			push_error("OS CALL FAILED FOR " + layer_name)
			continue

		editor_fs.scan()
		editor_fs.reimport_files(PackedStringArray([sprite_fetch_args[OUTFILE_IDX]]))

		var sheet : Texture2D = load(sprite_fetch_args[OUTFILE_IDX])
		var sprite_frames := build_spriteframes(sheet, anim_data)
		var animated_sprite := AnimatedSprite2D.new()
		animated_sprite.sprite_frames = sprite_frames
		animated_sprite.name = MAIN_NAME + '_' + layer_name

		var scn := PackedScene.new()
		var ok = scn.pack(animated_sprite)
		if ok == OK:
			ok = ResourceSaver.save(scn, outpath + '/%s_%s.tscn' % [MAIN_NAME, layer_name])
			if ok != OK:
				push_error("ERROR SAVING SCENE TO DISK")

	return

func get_layer_names() -> PackedStringArray:
	var fpath = ProjectSettings.globalize_path(sprite_path)
	var layer_fetch_args = PackedStringArray([
		"-b",
		"-list-layers",
		fpath
	])

	var cli_output := []
	var _fail : int = OS.execute(
		aseprite_executable,
		layer_fetch_args,
		cli_output,
	)

	var cli_dump = cli_output[0]
	cli_dump = cli_dump.replace('\r', "")
	# false to not allow empty elements
	return cli_dump.split('\n', false)

func dump_animation_data(outpath: String):

	var fpath = ProjectSettings.globalize_path(sprite_path)
# aseprite -b test.aseprite --list-tags --frame-tag --all-layers --data "./outputs/test.json" --format json-hash
	var animation_data_args = PackedStringArray([
		"-b",
		fpath,
		'--list-tags',
		'--frame-tag',
		'--all-layers',
		'--data',
		outpath,
		'--format',
		'json-hash'
	])

	var cli_output := []
	var _fail = OS.execute(
		aseprite_executable,
		animation_data_args,
		cli_output
	)

	if _fail:
		push_error("ERROR DUMPING ANIMATION DATA")
		return

func make_output_dir(path: String):
	if not DirAccess.dir_exists_absolute(path):
		var err = DirAccess.make_dir_recursive_absolute(path)
		if err != OK:
			push_error("ERROR: FAILED TO CREATE DIR")

func load_animation_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("json file non existent " + path)
		return {}

	var raw = file.get_as_text()
	file.close()

	var result = JSON.parse_string(raw)
	if result == null:
		push_error("BAD JSON. PARSE FAILED.")
		return {}
	return result

func build_spriteframes(sheet: Texture2D, anim_data: Dictionary) -> SpriteFrames:
	var sprite_frames = SpriteFrames.new()
	var sheet_width = sheet.get_width()

	var hframes = anim_data.frames.size()

	var step_x = sheet_width / hframes

	var offset_x := 0

	var frame_duration = 1

	# WE ASSUME CONTIGUITY ON THE ANIMATION TRACK
	# a walk animation with 4 frames must have its frames in sequence
	# { "name": "walk", "from": 0, "to": 12, "direction": "forward", "color": "#000000ff" },
	for adata in anim_data.meta.frameTags:
		sprite_frames.add_animation(adata.name)
		# frame_idx is number of the frame within the frameTag.
		for frame_num in range(adata.from, adata.to+1):
		# frame_num is frame number on the sheet, starting at 0
			offset_x = frame_num * step_x
			var atlas_tex = AtlasTexture.new()
			atlas_tex.atlas = sheet
			# we dont offset y because a layer is supposedly flat
			atlas_tex.region = Rect2(offset_x, 0, frame_size.x, frame_size.y)
			sprite_frames.add_frame(adata.name, atlas_tex, frame_duration)
	
	return sprite_frames


# NOTE: if you move the sheets to a diferent directory, things will likely break
