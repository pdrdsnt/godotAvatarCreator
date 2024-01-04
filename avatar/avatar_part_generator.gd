@tool

extends Skeleton3D
@export var path := ""
@export var animations: AnimationPlayer;
@export var generate:= false:
	set(_value):
		save_meshes_as_avatar_parts();

func save_meshes_as_avatar_parts():
	var p = path;
	
	var new_bones_data = BonesData.new();
	new_bones_data.load_from_skeleton(self);
	
	for m in get_children():
		var _m = m as MeshInstance3D;
		if _m == null:
			continue;
		
		var new_part = AvatarPart.new();
	
		new_part._create_from_mesh_instace(_m,self,animations);
		
		print(ResourceSaver.save(new_part,p + "/" + _m.name + ".tres"));
		
	pass
