@tool
extends Resource
class_name AvatarPart

@export var part_name: String;
@export var bones_data: BonesData;
@export var mesh: Mesh;
@export var surface_materials: Array[Material] = [];
@export var surface_paths: Array[String] = [];

func _create_from_mesh_instace(_mesh: MeshInstance3D, skeleton: Skeleton3D, animations: AnimationPlayer = null):
	bones_data = BonesData.new() as BonesData;
	bones_data.load_from_skeleton(skeleton);
	
	part_name = _mesh.name;
	
	mesh = _mesh.mesh;
	
	for s in mesh.get_surface_count():
		surface_paths.append(mesh.surface_get_material(s).resource_path);
		surface_materials.append(mesh.surface_get_material(s));
	
	if animations == null:
		return;
	bones_data.animation_library = animations.get_animation_library("");
	
