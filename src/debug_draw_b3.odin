package game

import "base:runtime"
import b3 "vendor:box3d"
import rl "vendor:raylib"

Debug_Shape_Data :: struct {
	type:    b3.ShapeType,
	using _: struct #raw_union {
		sphere:  b3.Sphere,
		capsule: b3.Capsule,
		hull:    ^b3.HullData,
	},
}

debug_draw_b3_create_shape :: proc "c" (
	debug_shape: ^b3.DebugShape,
	ctx: rawptr,
) -> rawptr {
	context = runtime.default_context()
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
	context = runtime.default_context()
	if user_shape != nil {
		free(user_shape)
	}
}

@(private = "file")
b3_hex_to_rl_color :: proc "c" (
	hex: b3.HexColor,
	alpha: f32 = 1.0,
) -> rl.Color {
	r := u8((u32(hex) >> 16) & 0xFF)
	g := u8((u32(hex) >> 8) & 0xFF)
	b := u8(u32(hex) & 0xFF)
	return {r, g, b, u8(alpha * 255)}
}

debug_draw_b3_shape :: proc "c" (
	user_shape: rawptr,
	transform: b3.WorldTransform,
	color: b3.HexColor,
	ctx: rawptr,
) -> bool {
	if user_shape == nil {
		return false
	}
	data := cast(^Debug_Shape_Data)user_shape
	c := b3_hex_to_rl_color(color)

	if gl_transform_scope(transform.p, transform.q) {
		#partial switch data.type {
		case .sphereShape:
			rl.DrawSphereWires(data.sphere.center, data.sphere.radius, 8, 8, c)
		case .capsuleShape:
			rl.DrawCapsuleWires(
				data.capsule.center1,
				data.capsule.center2,
				data.capsule.radius,
				8,
				8,
				c,
			)
		case .hullShape:
			if data.hull != nil {
				hull := data.hull
				points := cast([^]b3.Vec3)(uintptr(hull) +
					uintptr(hull.pointOffset))
				edges := cast([^]b3.HullHalfEdge)(uintptr(hull) +
					uintptr(hull.edgeOffset))
				for i in 0 ..< int(hull.edgeCount) {
					edge := edges[i]
					if u8(i) < edge.twin {
						twin := edges[edge.twin]
						p1 := points[edge.origin]
						p2 := points[twin.origin]
						rl.DrawLine3D(p1, p2, c)
					}
				}
			}
		}
	}
	return true
}

debug_draw_b3_segment :: proc "c" (
	p1, p2: b3.Pos,
	color: b3.HexColor,
	ctx: rawptr,
) {
	c := b3_hex_to_rl_color(color)
	rl.DrawLine3D(p1, p2, c)
}

debug_draw_b3_box :: proc "c" (
	extents: b3.Vec3,
	transform: b3.WorldTransform,
	color: b3.HexColor,
	ctx: rawptr,
) {
	c := b3_hex_to_rl_color(color)

	if gl_transform_scope(transform.p, transform.q) {
		rl.DrawCubeWires(
			{0, 0, 0},
			extents.x * 2,
			extents.y * 2,
			extents.z * 2,
			c,
		)
	}
}

debug_draw_b3_sphere :: proc "c" (
	p: b3.Pos,
	radius: f32,
	color: b3.HexColor,
	alpha: f32,
	ctx: rawptr,
) {
	c := b3_hex_to_rl_color(color, alpha)
	rl.DrawSphereWires(p, radius, 8, 8, c)
}

debug_draw_b3_bounds :: proc "c" (
	aabb: b3.AABB,
	color: b3.HexColor,
	ctx: rawptr,
) {
	c := b3_hex_to_rl_color(color)
	center := (aabb.lowerBound + aabb.upperBound) * 0.5
	size := aabb.upperBound - aabb.lowerBound
	rl.DrawCubeWires(center, size.x, size.y, size.z, c)
}

debug_draw_b3_point :: proc "c" (
	p: b3.Pos,
	size: f32,
	color: b3.HexColor,
	ctx: rawptr,
) {
	c := b3_hex_to_rl_color(color)
	rl.DrawPoint3D(p, c)
}

debug_draw_b3_capsule :: proc "c" (
	p1, p2: b3.Pos,
	radius: f32,
	color: b3.HexColor,
	alpha: f32,
	ctx: rawptr,
) {
	c := b3_hex_to_rl_color(color, alpha)
	rl.DrawCapsuleWires(p1, p2, radius, 8, 8, c)
}

debug_draw_b3_transform :: proc "c" (
	transform: b3.WorldTransform,
	ctx: rawptr,
) {
	axis_len: f32 = 0.5
	if gl_transform_scope(transform.p, transform.q) {
		rl.DrawLine3D({0, 0, 0}, {axis_len, 0, 0}, rl.RED)
		rl.DrawLine3D({0, 0, 0}, {0, axis_len, 0}, rl.GREEN)
		rl.DrawLine3D({0, 0, 0}, {0, 0, axis_len}, rl.BLUE)
	}
}

debug_draw_b3_string :: proc "c" (
	p: b3.Pos,
	s: cstring,
	color: b3.HexColor,
	ctx: rawptr,
) {
}

debug_draw_3d_make :: proc() -> b3.DebugDraw {
	return b3.DebugDraw {
		DrawShapeFcn = debug_draw_b3_shape,
		DrawSegmentFcn = debug_draw_b3_segment,
		DrawBoxFcn = debug_draw_b3_box,
		DrawSphereFcn = debug_draw_b3_sphere,
		DrawBoundsFcn = debug_draw_b3_bounds,
		DrawPointFcn = debug_draw_b3_point,
		DrawCapsuleFcn = debug_draw_b3_capsule,
		DrawTransformFcn = debug_draw_b3_transform,
		DrawStringFcn = debug_draw_b3_string,
		drawShapes = true,
		drawBounds = false,
		drawContacts = true,
		drawingBounds = {
			lowerBound = {-1000, -1000, -1000},
			upperBound = {1000, 1000, 1000},
		},
	}
}
