package game
import b3 "vendor:box3d"

Physics_Layer :: enum u64 {
	Static_World,
	Player_Physics,
	Enemy_Physics,
	Player_Hitbox,
	Enemy_Hitbox,
}

Physics_Mask :: bit_set[Physics_Layer;u64]

ALL_PHYSICS_LAYERS :: ~Physics_Mask{}

physics_query_filter_make :: proc(
	collision_layer: Physics_Mask = ALL_PHYSICS_LAYERS,
	collision_mask: Physics_Mask = ALL_PHYSICS_LAYERS,
) -> b3.QueryFilter {
	return {
		categoryBits = transmute(u64)collision_layer,
		maskBits = transmute(u64)collision_mask,
	}
}

physics_filter_make :: proc(
	collision_layer: Physics_Mask = ALL_PHYSICS_LAYERS,
	collision_mask: Physics_Mask = ALL_PHYSICS_LAYERS,
	group_index: i32 = 0,
) -> b3.Filter {
	return {
		categoryBits = transmute(u64)collision_layer,
		maskBits = transmute(u64)collision_mask,
		groupIndex = group_index,
	}
}
