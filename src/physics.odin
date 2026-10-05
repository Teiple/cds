package game

import "core:math/linalg"
import b3 "vendor:box3d"

Physics_Layer :: enum u64 {
	Static_World,
	Player_Physics,
	Enemy_Physics,
	Player_Hitbox,
	Enemy_Hitbox,
}

Physics_Mask :: bit_set[Physics_Layer; u64]

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

//region: b3 debug draw
Debug_Shape_Data :: struct {
	type       : b3.ShapeType,
	using _    : struct #raw_union {
		sphere  : b3.Sphere,
		capsule : b3.Capsule,
		hull    : ^b3.HullData,
	},
}

debug_draw_b3_create_shape :: proc "c" (
	debug_shape: ^b3.DebugShape,
	ctx: rawptr,
) -> rawptr {
	context = g_odin_ctx
	data := new(Debug_Shape_Data)
	data.type = debug_shape.type
	#partial switch debug_shape.type {
	case .sphereShape:
		data.sphere = debug_shape.sphere^
	case .capsuleShape:
		data.capsule = debug_shape.capsule^
	case .hullShape:
		data.hull = debug_shape.hull
	}
	return data
}

debug_draw_b3_destroy_shape :: proc "c" (user_shape: rawptr, ctx: rawptr) {
	context = g_odin_ctx
	if user_shape != nil {
		free(user_shape)
	}
}

@(private = "file")
b3_hex_to_color :: proc "c" (hex: b3.HexColor, alpha: f32 = 1.0) -> [4]u8 {
	r := u8((u32(hex) >> 16) & 0xFF)
	g := u8((u32(hex) >> 8) & 0xFF)
	b := u8(u32(hex) & 0xFF)
	return {r, g, b, u8(alpha * 255)}
}

@(private = "file")
b3_transform_point :: proc "c" (p: [3]f32, pos: [3]f32, rot: quaternion128) -> [3]f32 {
	return linalg.quaternion_mul_vector3(rot, p) + pos
}

debug_draw_b3_shape :: proc "c" (
	user_shape: rawptr,
	transform: b3.WorldTransform,
	color: b3.HexColor,
	ctx: rawptr,
) -> bool {
	context = g_odin_ctx
	if user_shape == nil do return false

	data := cast(^Debug_Shape_Data)user_shape
	c := b3_hex_to_color(color)

	#partial switch data.type {
	case .sphereShape:
		p := b3_transform_point(data.sphere.center, transform.p, transform.q)
		debug_draw_sphere(p, data.sphere.radius, 12, 16, c)
	case .capsuleShape:
		p1 := b3_transform_point(data.capsule.center1, transform.p, transform.q)
		p2 := b3_transform_point(data.capsule.center2, transform.p, transform.q)
		debug_draw_line(p1, p2, c)
	case .hullShape:
		if data.hull != nil {
			hull := data.hull
			points := cast([^]b3.Vec3)(uintptr(hull) + uintptr(hull.pointOffset))
			edges := cast([^]b3.HullHalfEdge)(uintptr(hull) + uintptr(hull.edgeOffset))
			for i in 0 ..< int(hull.edgeCount) {
				edge := edges[i]
				if u8(i) < edge.twin {
					twin := edges[edge.twin]
					p1 := b3_transform_point(points[edge.origin], transform.p, transform.q)
					p2 := b3_transform_point(points[twin.origin], transform.p, transform.q)
					debug_draw_line(p1, p2, c)
				}
			}
		}
	}
	return true
}

debug_draw_b3_segment :: proc "c" (p1, p2: b3.Pos, color: b3.HexColor, ctx: rawptr) {
	context = g_odin_ctx
	c := b3_hex_to_color(color)
	debug_draw_line(p1, p2, c)
}

debug_draw_b3_box :: proc "c" (extents: b3.Vec3, transform: b3.WorldTransform, color: b3.HexColor, ctx: rawptr) {
	context = g_odin_ctx
	c := b3_hex_to_color(color)
	debug_draw_box(transform.p, extents * 2, transform.q, c)
}

debug_draw_b3_sphere :: proc "c" (p: b3.Pos, radius: f32, color: b3.HexColor, alpha: f32, ctx: rawptr) {
	context = g_odin_ctx
	c := b3_hex_to_color(color, alpha)
	debug_draw_sphere(p, radius, 12, 16, c)
}

debug_draw_b3_point :: proc "c" (p: b3.Pos, size: f32, color: b3.HexColor, ctx: rawptr) {
	context = g_odin_ctx
	c := b3_hex_to_color(color)
	debug_draw_sphere(p, size * 0.1, 8, 8, c)
}

Physics :: struct {
	world:       b3.WorldId,
	debug_draw:  b3.DebugDraw,
	accumulator: f32,
}

PHYSICS_TICK_RATE :: 120.0
PHYSICS_DT        :: 1.0 / PHYSICS_TICK_RATE

physics_init :: proc(physics: ^Physics) {
	world_def := b3.DefaultWorldDef()
	world_def.gravity = {0, -10, 0}
	world_def.createDebugShape = debug_draw_b3_create_shape
	world_def.destroyDebugShape = debug_draw_b3_destroy_shape

	physics.world = b3.CreateWorld(world_def)
	physics.accumulator = 0

	physics.debug_draw = b3.DefaultDebugDraw()
	physics.debug_draw.DrawShapeFcn = debug_draw_b3_shape
	physics.debug_draw.DrawSegmentFcn = debug_draw_b3_segment
	physics.debug_draw.DrawBoxFcn = debug_draw_b3_box
	physics.debug_draw.DrawSphereFcn = debug_draw_b3_sphere
	physics.debug_draw.DrawPointFcn = debug_draw_b3_point
	physics.debug_draw.drawShapes = true
}

physics_destroy :: proc(physics: ^Physics) {
	b3.DestroyWorld(physics.world)
}

physics_update :: proc(physics: ^Physics, dt: f32) {
	physics.accumulator += dt
	physics.accumulator = min(physics.accumulator, 0.2)

	for physics.accumulator >= PHYSICS_DT {
		b3.World_Step(physics.world, PHYSICS_DT, 4)
		physics.accumulator -= PHYSICS_DT
	}
}

physics_debug_render :: proc(physics: ^Physics) {
	b3.World_Draw(
		physics.world,
		&physics.debug_draw,
		transmute(u64)ALL_PHYSICS_LAYERS,
	)
}

