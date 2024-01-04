@tool
extends Skeleton3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer;
@export var mesh_instance: MeshInstance3D = MeshInstance3D.new();
@export var animation_library:= AnimationLibrary.new();
@export var parts: Array[AvatarPart] = []:
	set(value):
		var update_arrays = update_slots_editor(value);
		parts = value;
		
		var rmv = update_arrays["to_rmv"];
		var add = update_arrays["to_add"];
		
		if rmv.size() > 0:
			print("slot removed")
			remove_slots(rmv);
		if add.size() > 0:
			print("slot added")
			add_slots(add);
		
	
@export var slots: Array[AvatarSlot] = [];
@export var surface_arrays: Dictionary = {};

@export var bones_data:= BonesData.new();
#each bone has an array referencing all slots that uses this bone
#ex: [bone_idx : [slots]]
#ex: [0: 0,3,4],[1: 1,3,4],[2: 1,2,3,4]
#add_slot and remove_slot read and write this array
@export var bones_slots_reference = [];

func create_surface_arrays() -> Array:
	var a = []
	a.resize(Mesh.ARRAY_MAX);
	return a;

#return one array with indexes of slots to create
#and one with indexes of parts to create new slots from
#this function should be called when parts arrays is updated
func update_slots_editor(value: Array[AvatarPart]):
	var add_slots: Array[int] = []
	var rmv_slots: Array[int] = []
	add_slots.resize(value.size());
	
	#iterate over slots and edior parts array
	#remove slot with part that is not in the array
	#create slot with new parts
	var s_idx:= 0;
	for p in slots:
		var found:= false;
		var p_idx = 0;
		for s in value:
			if s.part == p:
				#part is in slots
				found = true;
				#the indexes with value 0 will have a slot created
				add_slots[p_idx]+= 1;
				break;
			p_idx+= 1;
		#remove slot, editor array does not contain part
		if not found:
			rmv_slots.append(s_idx);
			#todo update info of everthing removes inde the surface arrays of the mesh after remove this part
			
		s_idx+=1;
	var _add_slots: Array[int] = [];
	for s in range(add_slots.size()):
		if add_slots[s] == 0:
			_add_slots.append(s);
		
	
	return {
		"to_add":_add_slots,
		"to_rmv":rmv_slots
		};
		
	pass

func add_slot(part: AvatarPart):
	if part == null:
		return;
	var new_slot = AvatarSlot.new();
	new_slot.slot_name = part.part_name;
	new_slot.part = part;
	var slots_size = slots.size();
	var m = part.mesh;
	var s_count = m.get_surface_count();
	new_slot.surfaces_materials.resize(s_count);
	
	#duplicate because we dont want to modify the resource, join_bones() is destructive
	var b = part.bones_data.duplicate();
	if bones_data==null: 
		bones_data = BonesData.new();
		bones_data.load_from_skeleton(self);
	var new_bones_data = bones_data.join_bones(b);
	var new_bones_count = new_bones_data["count"];
	var duplicate_bones = new_bones_data["overlaped"]
	var new_bones_remap = new_bones_data["remap"];
	
	#separate part mesh by surface
	var new_surfaces:= [];
	#store materials so can append part surfaces in the right avatar surface
	var new_materials:Array[Material]= [];
	for surface_idx in s_count:
		var new_surface = m.surface_get_arrays(surface_idx);
		#reorganize bones indexes if necessary
		if new_bones_count>0:
			for bone_idx in new_surface[Mesh.ARRAY_BONES]:
				bone_idx = new_bones_remap[bone_idx];
			
		#save new surfaces and corresponding material
		var mat:= m.surface_get_material(surface_idx);
		new_surfaces.append(new_surface);
		#this will create new surface_keys
		new_materials.append(mat);
		
		var mat_key := mat_ident(mat);
		
		if surface_arrays.has(mat_key):
			new_slot.vertex_offset[mat_key] = surface_arrays[mat_key][Mesh.ARRAY_VERTEX].size();
			new_slot.vertex_size[mat_key] = new_surface[Mesh.ARRAY_VERTEX].size();
			new_slot.indices_offset[mat_key] = surface_arrays[mat_key][Mesh.ARRAY_INDEX].size();
			new_slot.indices_size[mat_key] = new_surface[Mesh.ARRAY_INDEX].size();
		else:
			new_slot.vertex_offset[mat_key] = 0;
			new_slot.vertex_size[mat_key] = 0;
			new_slot.indices_offset[mat_key] = 0;
			new_slot.indices_size[mat_key] = 0;
			
		new_slot.bones_offset = bones_data.bones_name.size();
		new_slot.bones_size = new_bones_count;
		
	new_slot.surfaces_materials = new_materials;
	var part_surface_idx = 0;
	var idx = 0;
	for mat in new_materials:
		var mat_key := mat.resource_path.capitalize();
		if surface_arrays.has(mat_key):
			append_arrays(surface_arrays[mat_key],new_surfaces[idx]);
		else:
			print("mat_key:", mat_key)
			#print("new_surfaces[idx]:", new_surfaces[idx])
			surface_arrays[mat_key] = new_surfaces[idx];
		idx+=1;
	
	#adding this slot reference to bones
	for overlaped_idx in duplicate_bones:
		#append new slot idx to for each bone
		bones_slots_reference[overlaped_idx].append(slots_size);
		
	add_bones(b,slots.size() - 1);
	var array_mesh = ArrayMesh.new();
	
	
	var i:=0;
	for s in surface_arrays.values():
		array_mesh.add_surface_from_arrays(PrimitiveMesh.PRIMITIVE_TRIANGLES,s);
		array_mesh.surface_set_material(i,s);
		i+=1;
	mesh_instance.mesh = array_mesh;
	
	
func add_slots(new_parts_idx: Array[int]):
	
	print("new part idx: %s " % new_parts_idx);
	for a in new_parts_idx:
		var part = parts[a];
		add_slot(part);

func remove_slots(slots_idx: Array[int]):
	for r in slots_idx:
		var slot_materials = [];
		var slot_mesh: Mesh = slots[r].part.mesh;
		for s in range(slot_mesh.get_surface_count()):
			slot_materials.append(slot_mesh.surface_get_material(s));
	
		for material in slot_materials:
			var _surface = surface_arrays[material];
			remove_from_surface(_surface,r,material);

func remove_slot(slot_idx):
	var new_mesh:= ArrayMesh.new();
	if slot_idx > slots.size():
		return;
	var slot = slots[slot_idx];
	for s in slot.surfaces_materials:
		remove_from_surface(surface_arrays,slot_idx,s)
	
	var rmv_bones = [];
	var bone_idx:= 0;
	for b in get_bone_count():
		
		if bones_slots_reference[bone_idx].contains(slot_idx):
			bones_slots_reference[bone_idx].remove(slot_idx);
		if bones_slots_reference[bone_idx].size() < 2:
			rmv_bones.append(bone_idx);
			
		bone_idx += 1;
	
	#remap lose parents before remove
	for bone in range(get_bone_count()):
		if rmv_bones.has(bone):
			continue;
		var bone_parent = get_bone_parent(bone);
		if rmv_bones.has(bone_parent):
			var new_parent = get_bone_parent(bone_parent)
			while new_parent != -1:
				if rmv_bones.has(bone_parent):
					new_parent = get_bone_parent(bone_parent);
				else:
					break;
					
			set_bone_parent(bone,new_parent)
			pass
			
	bones_data.load_from_skeleton(self);
	clear_bones();
	var to_create = range(get_bone_count());
	to_create.remove_at(rmv_bones);
	var idx:= 0;
	for b in to_create:
		add_bone(bones_data.bones_name[b]);
		set_bone_parent(idx,bones_data.bones_parent[b]);
		set_bone_rest(idx,bones_data.bones_rest_pose[b]);
		idx+= 1;
	
func remove_from_surface(surface,slot_idx: int,material):
	var slot = slots[slot_idx];
	var i_offset = slot.indices_offset[material];
	var i_size = slot.indices_size[material];
	var v_offset = slot.vertex_offset[material];
	var v_size = slot.vertex_size[material];
	
	var idx = 0;
	for mesh_array in surface[material]:
		mesh_array = mesh_array as Array;
		if idx == Mesh.ARRAY_INDEX:
			var remove_at = [];
			for i in range(i_size):
				remove_at.append(i + i_offset);
			mesh_array.remove_at(remove_at);
		elif idx == Mesh.ARRAY_BONES:
			idx+=1;
			continue;
		else:
			var remove_at = [];
			for v in range(v_size):
				remove_at.append(v + v_offset);
			mesh_array.remove_at(remove_at);
		idx+=1;
	
func append_arrays(surface, new_arrays):
	var array_idx:= 0;
	for array in surface:
		array.append(new_arrays[array_idx])
		array_idx+=1

func add_bones(bones: BonesData,slot_idx):
	var idx = get_bone_count();
	var _idx = 0;
	for b in bones.bones_name:
		add_bone(b);
		set_bone_parent(idx,bones.bones_parent[_idx]);
		set_bone_rest(idx,bones.bones_rest_pose[_idx]);
		var new_references_array: Array[int] = [slot_idx]
		bones_slots_reference.append(new_references_array);
		idx+=1;
		_idx+=1;
		
func apply_rest_pose(idx: int):
	set_bone_pose_position(idx, get_bone_rest(idx).origin);
	set_bone_pose_rotation(idx, get_bone_rest(idx).basis.get_rotation_quaternion());
	set_bone_pose_scale(idx, get_bone_rest(idx).basis.get_scale());
		
func mat_ident(mat: Material) -> String:
	var ident = mat.resource_name;
	return ident;

# Função para combinar duas AnimationLibraries
#chatGPT 3.5 with corrections
func add_animations(library1: AnimationLibrary, library2: AnimationLibrary) -> AnimationLibrary:
	var nova_library = AnimationLibrary.new()
	
	# Percorra as animações da primeira biblioteca e copie-as para a nova biblioteca
	for anim_name in library1.get_animation_list():
		var anim = library1.get_animation(anim_name)
		nova_library.add_animation(anim_name, anim)
	mat_ident
	# Percorra as animações da segunda biblioteca e copie-as para a nova biblioteca
	for anim_name in library2.get_animation_list():
		var anim = library2.get_animation(anim_name)
		# Verifique se a animação já existe na nova biblioteca e, se sim, combine as chaves
		if nova_library.has_animation(anim_name):
			var existing_anim = nova_library.get_animation(anim_name)
			for track_name in anim.track_get_names():
				var track_idx = existing_anim.get_track_count();
				existing_anim.track_set_path(track_idx, track_name)
				for key in anim.track_get_key_frames(track_name):
					existing_anim.track_insert_key(track_idx, key.time, key.value, key.interpolation)
		else:
			nova_library.add_animation(anim_name, anim)
			
	return nova_library
	
