extends Resource

class_name AvatarSlot

var slot_name: String;
var part: AvatarPart;
#ctx data to work with multiple parts in avatar class
var bones_offset:= 0;
var bones_size:= 0;
var bones_mask: Array[int] = [];
var indices_offset:= {};
var indices_size:= {};
var vertex_offset= {};
var vertex_size:= {};
var surfaces_materials: Array[Material] = [];

func set_surface(surface_material: Material,_vertex_offset: int, _vertex_size: int,_indices_offset: int, _indices_size: int):
	indices_offset[surface_material] = _indices_offset;
	indices_size[surface_material] = _indices_size;
	vertex_offset[surface_material] = _vertex_offset;
	vertex_size[surface_material] = _vertex_size;
	
	
