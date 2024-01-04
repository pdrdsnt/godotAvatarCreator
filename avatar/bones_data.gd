@tool
extends Resource
class_name BonesData
@export var load_skeleton: Skeleton3D:
	set(value):
		load_skeleton = null;
		load_from_skeleton(value);
@export var load_animations: AnimationPlayer:
	set(value):
		load_animations = null;
		if load_animations as AnimationPlayer != null:
			animation_library = value.get_animation_library(value.get_animation_library_list()[0]);
@export_category("bones data")
@export var bones_rest_pose: Array[Transform3D] = [];
@export var bones_name: Array[String] = [];
@export var bones_parent: Array[int] = [];
@export var animation_library: AnimationLibrary;

func load_from_skeleton(s: Skeleton3D):
	
	bones_rest_pose.clear();
	bones_name.clear();
	bones_parent.clear();
	
	if s == null: return;
	for b in s.get_bone_count():
		bones_rest_pose.append(s.get_bone_global_rest(b));
		bones_name.append(s.get_bone_name(b));
		bones_parent.append(s.get_bone_parent(b));
	
func generate_skeleton_from_arrays() -> Skeleton3D:
	var skeleton = Skeleton3D.new();
	
	for b in bones_rest_pose.size():
		skeleton.add_bone(bones_name[b]);
		skeleton.set_bone_parent(b,bones_parent[b]);
		skeleton.set_bone_rest(b,bones_rest_pose[b]);
	
	return skeleton;

func remove_bones(bones_array: Array[BonesData], indices_to_remove: Array[int], parent_map: Dictionary):
	indices_to_remove.reverse();
	for idx in indices_to_remove:
		bones_array.remove_at(idx)
	
	#the reparent map need to be done when selecting the bones to remove
	for idx in range(bones_array.size()):
		if parent_map.has(bones_array[idx]):
			bones_array[idx].bones_parent = parent_map[idx];
		
func join_bones(bones0: BonesData) -> Dictionary:
	
	if bones_name.size() == 0 or bones0.bones_name.size() == 0:
		return {
		"count" : 0,
		#BONES_INDEX need to be remaped in MESH_ARRAYS
		"remap" : {},
		"overlaped" : [],
		};
	
	var to_remove = [];
	var reparent_map = {};
	#check equal bones to remove
	for new_bone_index in range(bones0.bones_name.size()):
		for current_bone_index in range(bones_name.size()):
			if bones0.bones_name[new_bone_index] == bones_name[current_bone_index]:
				to_remove.append(new_bone_index);
				#all bones that have this one as a parent will need to be reindexed
				reparent_map[new_bone_index] = current_bone_index;
				break  # Add break to exit the loop after removing the bone
		
	var new_bones_name : Array[String] = []
	var new_bones_rest_pose : Array[Transform3D] = []
	var new_bones_parent : Array[int] = []

	for idx in range(bones0.bones_name.size()):
		if !to_remove.has(idx):
			new_bones_name.append(bones0.bones_name[idx])
			new_bones_rest_pose.append(bones0.bones_rest_pose[idx])
			new_bones_parent.append(bones0.bones_parent[idx])

	bones0.bones_name = new_bones_name
	bones0.bones_rest_pose = new_bones_rest_pose
	bones0.bones_parent = new_bones_parent
	
	#now we scan all bones and update bone indexes
	for idx in range(bones0.bones_name.size()):
		if reparent_map.has(bones0.bones_parent[idx]):
			#no + bones_name.size() - 1; because it points to a bone in the old rig that will not be changed
			bones0.bones_parent[idx] = reparent_map[idx];
		else:
			bones0.bones_parent[idx] += bones_name.size() - 1;
		
	# Add remaining bones from bones0 to the calling BonesData
	bones_name.append_array(bones0.bones_name)
	bones_parent.append_array(bones0.bones_parent)
	bones_rest_pose.append_array(bones0.bones_rest_pose)

	#return new bones so Avatar can adjust indices
	#mesh BONES_ARRAY will need to be updated, vertices comming from this rig will need to be added to the old bones size
	return {
		"count" : bones0.bones_name.size(),
		#BONES_INDEX need to be remaped in MESH_ARRAYS
		"remap" : reparent_map,
		"overlaped" : to_remove,
		};
